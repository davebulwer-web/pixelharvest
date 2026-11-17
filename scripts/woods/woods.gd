extends Node2D
##
## Woods — the Woods scene (DECISIONS 052): the place over the new bridge,
## north of the town, with its glades, its stream and whatever's growing wild
## today.
##
## Like the town it owns no game state. It draws a fixed map (WoodsLayout),
## stands the trees on it, and lays out today's forage (Forage.spots_today),
## a ForageSpot on each, which the player picks up with E. The farm's tools
## are off here, as in town, except the axe (DECISIONS 053): the player asks
## this scene what's at a cell (choppable_at) and the axe chops it (chop):
## the undergrowth, which stays down until the season turns, and the day's
## fallen logs (FallenLogs), which are new each morning. And the fishing rod
## (DECISIONS 054), which asks water_at: the stream.
##
##   Woods
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── Footbridge  (the planks over the stream, drawn over the ground)
##   ├── SpawnPoints (Marker2Ds, made by Exits: one for the way in from town)
##   ├── TileCursor  (made here: the tile the axe would chop, when it would)
##   ├── Entities    (y-sorted: player, trees, forage, fallen logs)
##   ├── Effects     (made here: FarmEffects, the axe's wood chips)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   └── Hud         (the same HUD scene as the farm)
##

const TILE_PX := 16
const WOODS_ID := &"woods"

@onready var _ground: TileMapLayer = $Ground
@onready var _footbridge: Sprite2D = $Footbridge
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather

## Today's fallen logs: each of a log's two cells -> its FallenLog node.
var _logs: Dictionary = {}

## The outline on the tile the held tool would act on (as on the farm), shown
## only when there's something here it can act on: the axe at undergrowth or
## a log.
var _cursor: Node2D


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	SeasonLook.apply_ground(_ground)
	var woods := LocationManager.find(WOODS_ID)
	var tiles := WoodsLayout.build(Exits.gap_cells(woods))
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	# Undergrowth chopped down this season is grass until the season turns.
	for cell: Vector2i in GameState.cleared.get(WOODS_ID, []):
		GroundTiles.draw(_ground, cell, GroundTiles.grass_for(cell))
	_cursor = preload("res://scripts/tile_cursor.gd").new()
	_cursor.name = "TileCursor"
	add_child(_cursor)
	move_child(_cursor, _entities.get_index())
	# Chips of wood when the axe bites, as on the farm.
	var effects := FarmEffects.new()
	effects.name = "Effects"
	add_child(effects)
	# The footbridge's picture covers its cells, which are path underneath.
	_footbridge.position = Vector2(WoodsLayout.FOOTBRIDGE.position * TILE_PX)

	# The way back over the bridge to town: woods.tres's exits (DECISIONS 060).
	Exits.add(self, woods, _spawns)
	_place_objects()
	_place_forage()
	_place_logs()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	_limit_camera()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## Stand every tree from WoodsLayout.objects(). Each is an ObjectDef, so it
## wears its season's picture (snow in winter) like the farm's and town's.
func _place_objects() -> void:
	var objects := WoodsLayout.objects()
	for cell: Vector2i in objects:
		var id: StringName = objects[cell]
		var def := ContentDB.object(id)
		if def == null or def.scene == null:
			push_warning("The Woods can't place '%s' at %s: no data/objects/ file with that id and a scene"
					% [id, cell])
			continue
		var node: Node2D = def.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, id)


## Today's forage, a ForageSpot on each spot that still has something.
func _place_forage() -> void:
	var location := LocationManager.current()
	var spots := Forage.spots_today(location, WoodsLayout.forage_cells())
	for cell: Vector2i in spots:
		_entities.add_child(ForageSpot.create(WOODS_ID, cell, spots[cell]))


## Today's fallen logs (FallenLogs), keeping off every spot today's forage
## is on, picked or not.
func _place_logs() -> void:
	var location := LocationManager.current()
	var forage := Forage.spots_today(location, WoodsLayout.forage_cells(), true)
	for cell in FallenLogs.today(location, WoodsLayout.log_cells(), forage):
		var log_node := FallenLog.create(cell)
		_entities.add_child(log_node)
		_logs[cell] = log_node
		_logs[cell + Vector2i.RIGHT] = log_node


func _physics_process(_delta: float) -> void:
	# Outline the axe's tile only when it would do something there, so the
	# Woods don't show a cursor wherever you walk.
	var cells: Array[Vector2i] = []
	var tool := GameState.selected_tool()
	if tool != null and tool.action != null and tool.action.usable_in_season(GameState.season_id()) \
			and not Fishing.is_busy():
		for cell in _player.target_cells():
			if tool.action.can_use_away(self, cell):
				cells.append(cell)
	_cursor.set_cells(cells)


# --- The fishing rod (DECISIONS 054) ----------------------------------------------

## The kind of water at `cell` for the fishing rod: &"stream", or &"" for
## dry land (the footbridge is dry land, over the stream).
func water_at(cell: Vector2i) -> StringName:
	return &"stream" if WoodsLayout.is_stream(cell) else &""


# --- The axe (DECISIONS 053) ---------------------------------------------------

## What the axe would chop at `cell`: &"thicket" for undergrowth not yet
## cleared this season, &"log" for a fallen log not yet chopped today, &""
## for nothing.
func choppable_at(cell: Vector2i) -> StringName:
	if _logs.has(cell):
		return &"log"
	if WoodsLayout.is_undergrowth(cell) and not GameState.is_cleared(WOODS_ID, cell):
		return &"thicket"
	return &""


## Chop whatever is at `cell`, for `amount` of `item_id` (the axe says how
## much each gives). The undergrowth becomes grass for the rest of the
## season; a log is gone for today. wood_chopped puts the timber in the bag.
func chop(cell: Vector2i, item_id: StringName, amount: int) -> void:
	var what := choppable_at(cell)
	if what == &"log":
		var log_node: FallenLog = _logs[cell]
		GameState.chop_log(WOODS_ID, log_node.cell)
		_logs.erase(log_node.cell)
		_logs.erase(log_node.cell + Vector2i.RIGHT)
		log_node.queue_free()
	elif what == &"thicket":
		GameState.clear_undergrowth(WOODS_ID, cell)
		GroundTiles.draw(_ground, cell, GroundTiles.grass_for(cell))
	else:
		return
	EventBus.wood_chopped.emit(WOODS_ID, cell, what, item_id, amount)


func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_town") as Marker2D
	if spawn == null:
		push_warning("The Woods have no spawn point '%s'" % point)
		spawn = _spawns.get_node(^"from_town")
	_player.position = spawn.position


## Keep the camera inside the Woods and their border.
func _limit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = -TILE_PX
	camera.limit_top = -TILE_PX
	camera.limit_right = (WoodsLayout.SIZE.x + 1) * TILE_PX
	camera.limit_bottom = (WoodsLayout.SIZE.y + 1) * TILE_PX
