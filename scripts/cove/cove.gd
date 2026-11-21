extends Node2D
##
## Cove — the Cove scene (DECISIONS 064): the harbour, the beach and the
## shore the tide uncovers, down the coast road from the town or the cliff
## path from the Lane.
##
## Like the Lane it owns no game state. It draws a fixed map (CoveLayout),
## builds every building whose door is here (the old lighthouse, Tam's fish
## shed and Rosa's cottage: homes seen from outside, whose doors say who
## lives there), stands the tide board and the trees, lays out today's
## forage, and builds its two ways out from its LocationDef's exits.
##
## The tide (Tides) is the Cove's own: as the clock moves, the scene asks
## whether the tide is out, and when that changes it redraws the tidal shore
## (wet sand and rockpools, or sea), puts out or takes away the rockpools'
## forage, and, when the tide comes in, sends anyone still out on the shore
## back up to the strand line. The strand line's forage (shells, sea glass,
## weed, driftwood after a storm) is there whatever the tide.
##
## Tam (DECISIONS 065), from spring day 7, stands on the quay: a CharacterDef
## who lives here, with a counter of his own (CharacterDef.counter), so
## talking to him is a shop counter's conversation (ShopCounter): his
## requests first, then the menu where he buys fish and sea forage. He and
## anyone else whose day brings them to the Cove (Wren on the pier on
## Saturdays, Pip and Mabel on the beach) are PeopleHere's (DECISIONS 067). The sea
## beside the pier, the quay and the breakwater can be fished
## (CoveLayout.water_at: &"sea"), with his handline or the rod, and crab pots
## are lowered off the pier (pot_wanted_at, set_pot); each pot set is drawn
## as a CrabPot float from GameState, and redrawn when crab_pot_changed says.
## A tile outline shows where the held line or pot would go.
##
##   Cove
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made by Exits: "from_town", "from_lane")
##   ├── Entities    (y-sorted: player, buildings, the tide board, trees, forage,
##   │                Tam, the crab pots' floats)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   ├── Hud         (the same HUD scene as the farm)
##   ├── Dialogue    (the dialogue box: Tam)
##   ├── ShopMenu    (Tam's counter: what he buys)
##   └── People      (PeopleHere, made here: whoever's at the Cove; DECISIONS 067)
##

const TILE_PX := 16
const COVE_ID := &"cove"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

## Whoever's at the Cove now (DECISIONS 067).
var _people: PeopleHere

## The outline on the sea the held line or crab pot would go into.
var _cursor: Node2D


## The crab pots' floats, by cell (DECISIONS 065).
var _pots: Dictionary = {}  # Vector2i -> CrabPot

## Whether the tide was out when the shore was last drawn.
var _tide_out := false

## Today's rockpool forage now lying out, by cell: only while the tide's out.
var _pool_spots: Dictionary = {}  # Vector2i -> ForageSpot


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	var location := LocationManager.find(COVE_ID)
	SeasonLook.apply_ground(_ground)
	GroundEdges.attach(_ground)
	var buildings := LocationManager.buildings_on(COVE_ID)
	var door_cells: Array[Vector2i] = []
	for def in buildings:
		door_cells.append_array(Building.door_cells(def))
	_tide_out = Tides.is_out()
	var tiles := CoveLayout.build(Exits.gap_cells(location), door_cells, _tide_out)
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	Exits.add(self, location, _spawns)
	_add_buildings(buildings)
	_place_objects()
	PackLook.dress(_entities, COVE_ID)  # TEST (DECISIONS 081)
	Scenery.add_to(self, _entities, COVE_ID)  # Dave's scenery (DECISIONS 082)
	_place_strand_forage()
	if _tide_out:
		_place_pool_forage()
	_people = PeopleHere.create(COVE_ID, _entities, CoveLayout.SIZE, _dialogue, _menu)
	add_child(_people)
	_place_pots()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	EventBus.time_changed.connect(func(_minutes: int) -> void: _check_tide())
	_limit_camera()
	_cursor = preload("res://scripts/tile_cursor.gd").new()
	_cursor.name = "TileCursor"
	add_child(_cursor)
	move_child(_cursor, _entities.get_index())
	EventBus.crab_pot_changed.connect(_on_crab_pot_changed)
	# Say what the tide's doing on the way in, and if any pots want hauling.
	EventBus.message_posted.emit.call_deferred(_arrival_text())


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## Every building with its door in the Cove, as the Lane builds its homes.
## One that can be gone into gets a spawn point on its doorstep.
func _add_buildings(buildings: Array[LocationDef]) -> void:
	for def in buildings:
		_entities.add_child(Building.create(def))
		if def.has_inside():
			var marker := Marker2D.new()
			marker.name = "from_%s" % def.id
			marker.position = Building.doorstep(def)
			_spawns.add_child(marker)


## Stand everything from CoveLayout.objects(): the tide board and the trees.
func _place_objects() -> void:
	var objects := CoveLayout.objects()
	for cell: Vector2i in objects:
		var id: StringName = objects[cell]
		var def := ContentDB.object(id)
		if def == null or def.scene == null:
			push_warning("The Cove can't place '%s' at %s: no data/objects/ file with that id and a scene"
					% [id, cell])
			continue
		var node: Node2D = def.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, id)


## Today's strand-line forage, whatever the tide.
func _place_strand_forage() -> void:
	var spots := Forage.spots_today(LocationManager.find(COVE_ID), CoveLayout.strand_cells())
	for cell: Vector2i in spots:
		_entities.add_child(ForageSpot.create(COVE_ID, cell, spots[cell]))


## Today's rockpool forage not yet picked: put out as the tide goes out.
func _place_pool_forage() -> void:
	var spots := Forage.spots_today(LocationManager.find(COVE_ID), CoveLayout.pool_cells(), false, true)
	for cell: Vector2i in spots:
		if _pool_spots.has(cell) and is_instance_valid(_pool_spots[cell]):
			continue
		var spot := ForageSpot.create(COVE_ID, cell, spots[cell])
		_entities.add_child(spot)
		_pool_spots[cell] = spot


## The rockpools' forage goes back under the sea with the tide (what wasn't
## picked is still there next time it's out today).
func _clear_pool_forage() -> void:
	for cell: Vector2i in _pool_spots:
		# A picked spot has already gone (ForageSpot frees itself).
		var spot = _pool_spots[cell]
		if is_instance_valid(spot):
			spot.queue_free()
	_pool_spots.clear()


## As the clock moves: has the tide turned? If so, redraw the shore and its
## rockpools, and get anyone still out there back up the beach.
func _check_tide() -> void:
	var out := Tides.is_out()
	if out == _tide_out:
		return
	_tide_out = out
	for cell in CoveLayout.pool_cells() + _wet_sand_cells():
		GroundTiles.draw(_ground, cell, CoveLayout.tile_for(cell, _tide_out))
	if _tide_out:
		_place_pool_forage()
		EventBus.message_posted.emit("The tide's going out. The rockpools are showing. "
				+ Tides.now_text())
		return
	_clear_pool_forage()
	if _wade_ashore():
		EventBus.message_posted.emit("The tide's come in! You splash back up the beach.")
	else:
		EventBus.message_posted.emit("The tide's coming in over the rockpools.")


func _wet_sand_cells() -> Array[Vector2i]:
	return CoveLayout.wet_sand_cells()


## If any corner of the player's feet is on the shore the tide has just
## covered, move them to the strand line above it. True if they were moved.
func _wade_ashore() -> bool:
	for corner: Vector2 in [Vector2(-6, -8), Vector2(6, -8), Vector2(-6, -1), Vector2(6, -1)]:
		var cell := Vector2i((_player.position + corner) / TILE_PX)
		if CoveLayout.is_tidal(cell):
			_player.position = Exits.arrival_position(CoveLayout.shore_for(cell))
			return true
	return false


## The handline and the rod ask this (DECISIONS 065): &"sea" off the pier,
## the quay and the breakwater, as the tide stands now (CoveLayout.water_at).
func water_at(cell: Vector2i) -> StringName:
	return CoveLayout.water_at(cell, _tide_out)


# --- Crab pots (DECISIONS 065) ----------------------------------------------------
# The crab pot in the bag asks these (SetPotAction), as the hoe asks the
# Lane about the allotments.

func pot_wanted_at(cell: Vector2i) -> bool:
	return CoveLayout.is_pot_cell(cell) and not GameState.has_crab_pot(COVE_ID, cell)


func set_pot(cell: Vector2i) -> void:
	GameState.set_crab_pot(COVE_ID, cell)


## A float for every pot set here.
func _place_pots() -> void:
	for cell in GameState.crab_pots_in(COVE_ID):
		_add_pot(cell)


func _add_pot(cell: Vector2i) -> void:
	var pot := CrabPot.create(COVE_ID, cell)
	_entities.add_child(pot)
	_pots[cell] = pot


## A pot was set, baited, hauled or pulled up: show it as it is now.
func _on_crab_pot_changed(location_id: StringName, cell: Vector2i) -> void:
	if location_id != COVE_ID:
		return
	var there := GameState.has_crab_pot(COVE_ID, cell)
	if _pots.has(cell):
		if there:
			_pots[cell].refresh()
			return
		_pots[cell].queue_free()
		_pots.erase(cell)
	elif there:
		_add_pot(cell)


## What's said on the way in: the tide, and any pots waiting to be hauled.
func _arrival_text() -> String:
	var text := Tides.now_text()
	var ready := GameState.crab_pots_ready_in(COVE_ID)
	if ready == 1:
		text += " One of your crab pots is ready to haul."
	elif ready > 1:
		text += " %d of your crab pots are ready to haul." % ready
	return text


func _physics_process(_delta: float) -> void:
	# Outline the sea the held line or pot would go into, only where it would.
	var cells: Array[Vector2i] = []
	var tool := GameState.selected_tool()
	if tool != null and tool.action != null and tool.action.usable_in_season(GameState.season_id()) \
			and not Fishing.is_busy():
		for cell in _player.target_cells():
			if tool.action.can_use_away(self, cell):
				cells.append(cell)
	_cursor.set_cells(cells)


## Put the player where LocationManager asked: "from_town" or "from_lane",
## made by Exits. With no arrival point, the coast road's end.
func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_town") as Marker2D
	if spawn == null:
		push_warning("The Cove has no spawn point '%s'" % point)
		spawn = _spawns.get_node_or_null(^"from_town") as Marker2D
	if spawn != null:
		_player.position = spawn.position


## Keep the camera inside the Cove and its border.
func _limit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = -TILE_PX
	camera.limit_top = -TILE_PX
	camera.limit_right = (CoveLayout.SIZE.x + 1) * TILE_PX
	camera.limit_bottom = (CoveLayout.SIZE.y + 1) * TILE_PX
