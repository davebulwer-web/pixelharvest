extends Node2D
##
## Woods — the Woods scene (DECISIONS 052): the place over the new bridge,
## north of the town, with its glades, its stream and whatever's growing wild
## today.
##
## Like the town it owns no game state. It draws a fixed map (WoodsLayout),
## stands the trees on it, and lays out today's forage (Forage.spots_today),
## a ForageSpot on each, which the player picks up with E. Tools are off here,
## as in town: the farm's tiles aren't here to be hoed. (Stage 14 session 2's
## axe will be the first tool that works here.)
##
##   Woods
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── Footbridge  (the planks over the stream, drawn over the ground)
##   ├── SpawnPoints (Marker2Ds, made here: one for the way in from town)
##   ├── Entities    (y-sorted: player, trees, forage)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   └── Hud         (the same HUD scene as the farm)
##

const TILE_PX := 16
const WOODS_ID := &"woods"
const TOWN_ID := &"town"

@onready var _ground: TileMapLayer = $Ground
@onready var _footbridge: Sprite2D = $Footbridge
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather


func _ready() -> void:
	_player.can_farm = false
	SeasonLook.apply_ground(_ground)
	var tiles := WoodsLayout.build()
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	# The footbridge's picture covers its cells, which are path underneath.
	_footbridge.position = Vector2(WoodsLayout.FOOTBRIDGE.position * TILE_PX)

	_add_spawn(&"from_town", WoodsLayout.ARRIVAL_FROM_TOWN)
	_place_objects()
	_place_forage()
	_add_town_gate()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	_limit_camera()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


func _add_spawn(point_name: StringName, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = String(point_name)
	marker.position = at
	_spawns.add_child(marker)


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


## The way back: the gap in the south edge, over the bridge into town.
func _add_town_gate() -> void:
	var top_left: Vector2i = WoodsLayout.TOWN_GATE[0]
	var rect := Rect2(top_left * TILE_PX, Vector2(TILE_PX * WoodsLayout.TOWN_GATE.size(), TILE_PX))
	add_child(ExitZone.create(rect, TOWN_ID, &"from_woods"))


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
