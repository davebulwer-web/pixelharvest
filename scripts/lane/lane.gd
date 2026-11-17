extends Node2D
##
## Lane — the Lane scene (DECISIONS 060): the country lane between the farm
## and the town, with hedgerows to pick from on the way past.
##
## Like the Woods it owns no game state. It draws a fixed map (LaneLayout),
## stands the fence, the signpost and the trees on it, lays out today's
## hedgerow forage (Forage.spots_today, the same as the Woods' mushrooms),
## and builds its two ends from its LocationDef's exits (Exits): west to the
## town, east to the farm. Tools are off here, as in town.
##
##   Lane
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made by Exits: "from_town", "from_farm")
##   ├── Entities    (y-sorted: player, trees, the fence, the signpost, forage)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   └── Hud         (the same HUD scene as the farm)
##

const TILE_PX := 16
const LANE_ID := &"lane"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	var location := LocationManager.find(LANE_ID)
	SeasonLook.apply_ground(_ground)
	var tiles := LaneLayout.build(Exits.gap_cells(location))
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	Exits.add(self, location, _spawns)
	_place_objects()
	_place_forage()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	_limit_camera()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## Stand everything from LaneLayout.objects(). Each is an ObjectDef, so it
## wears its season's picture (snow on the trees in winter).
func _place_objects() -> void:
	var objects := LaneLayout.objects()
	for cell: Vector2i in objects:
		var id: StringName = objects[cell]
		var def := ContentDB.object(id)
		if def == null or def.scene == null:
			push_warning("The Lane can't place '%s' at %s: no data/objects/ file with that id and a scene"
					% [id, cell])
			continue
		var node: Node2D = def.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, id)


## Today's hedgerow forage, a ForageSpot on each spot that still has something.
func _place_forage() -> void:
	var spots := Forage.spots_today(LocationManager.find(LANE_ID), LaneLayout.forage_cells())
	for cell: Vector2i in spots:
		_entities.add_child(ForageSpot.create(LANE_ID, cell, spots[cell]))


## The fishing rod asks this: no fish in the stream yet (LaneLayout.water_at).
func water_at(cell: Vector2i) -> StringName:
	return LaneLayout.water_at(cell)


## Put the player where LocationManager asked: "from_farm" or "from_town",
## made by Exits. With no arrival point (shouldn't happen: the game always
## starts at home), the farm end.
func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_farm") as Marker2D
	if spawn == null:
		push_warning("The Lane has no spawn point '%s'" % point)
		spawn = _spawns.get_node_or_null(^"from_farm") as Marker2D
	if spawn != null:
		_player.position = spawn.position


## Keep the camera inside the Lane and its border.
func _limit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = -TILE_PX
	camera.limit_top = -TILE_PX
	camera.limit_right = (LaneLayout.SIZE.x + 1) * TILE_PX
	camera.limit_bottom = (LaneLayout.SIZE.y + 1) * TILE_PX
