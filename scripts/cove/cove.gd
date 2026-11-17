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
##   Cove
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made by Exits: "from_town", "from_lane")
##   ├── Entities    (y-sorted: player, buildings, the tide board, trees, forage)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   └── Hud         (the same HUD scene as the farm)
##

const TILE_PX := 16
const COVE_ID := &"cove"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather

## Whether the tide was out when the shore was last drawn.
var _tide_out := false

## Today's rockpool forage now lying out, by cell: only while the tide's out.
var _pool_spots: Dictionary = {}  # Vector2i -> ForageSpot


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	var location := LocationManager.find(COVE_ID)
	SeasonLook.apply_ground(_ground)
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
	_place_strand_forage()
	if _tide_out:
		_place_pool_forage()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	EventBus.time_changed.connect(func(_minutes: int) -> void: _check_tide())
	_limit_camera()
	# Say what the tide's doing on the way in.
	EventBus.message_posted.emit.call_deferred(Tides.now_text())


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
	var result: Array[Vector2i] = []
	for rect in CoveLayout.WET_SAND:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				result.append(Vector2i(x, y))
	return result


## If any corner of the player's feet is on the shore the tide has just
## covered, move them to the strand line above it. True if they were moved.
func _wade_ashore() -> bool:
	for corner: Vector2 in [Vector2(-6, -8), Vector2(6, -8), Vector2(-6, -1), Vector2(6, -1)]:
		var cell := Vector2i((_player.position + corner) / TILE_PX)
		if CoveLayout.is_tidal(cell):
			_player.position = Exits.arrival_position(CoveLayout.shore_for(cell))
			return true
	return false


## The fishing rod asks this: nothing bites here until Tam's handline
## (CoveLayout.water_at).
func water_at(cell: Vector2i) -> StringName:
	return CoveLayout.water_at(cell)


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
