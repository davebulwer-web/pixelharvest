extends Node2D
##
## Town — the town scene: a road, a pond, trees, and a door for every shop.
##
## Like the farm it owns no game state. It draws a fixed map (TownLayout),
## builds a Building for every location whose door is on this map (so a new
## shop appears here with no edit), and puts the arriving player at the spawn
## point LocationManager asked for. Tools are off in town (the farm's tiles
## aren't here to be hoed), and so is sleeping.
##
##   Town
##   ├── Ground      (TileMapLayer, same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made here: one per door, one for the farm gate)
##   ├── Entities    (y-sorted: player, trees, shop fronts)
##   ├── Weather     (the season's overlay — winter's snow — as on the farm)
##   └── Hud         (the same HUD scene as the farm)
##

const TILE_PX := 16
const TOWN_ID := &"town"
const FARM_ID := &"farm"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather


func _ready() -> void:
	_player.can_farm = false
	var doors: Array[LocationDef] = _buildings()
	var door_cells: Array[Vector2i] = []
	for def in doors:
		door_cells.append(def.door_cell)

	SeasonLook.apply_ground(_ground)
	var tiles := TownLayout.build(door_cells)
	for cell: Vector2i in tiles:
		_ground.set_cell(cell, GroundTiles.SOURCE_ID, tiles[cell])

	for def in doors:
		_entities.add_child(Building.create(def))
		_add_spawn(StringName("from_%s" % def.id), Vector2(
				def.door_cell.x * TILE_PX + TILE_PX / 2.0, (def.door_cell.y + 2) * TILE_PX - 2))
	_add_spawn(&"from_farm", TownLayout.ARRIVAL_FROM_FARM)
	_place_trees()
	_add_farm_gate()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	_limit_camera()


## Every location with its door on this map.
func _buildings() -> Array[LocationDef]:
	var result: Array[LocationDef] = []
	for def in LocationManager.all():
		if def.outside == TOWN_ID and def.exterior != null:
			result.append(def)
	return result


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


func _add_spawn(point_name: StringName, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = String(point_name)
	marker.position = at
	_spawns.add_child(marker)


func _place_trees() -> void:
	var tree := ContentDB.object(&"tree")
	if tree == null or tree.scene == null:
		push_warning("Town has no tree to plant: data/objects/tree.tres is missing or has no scene")
		return
	for cell in TownLayout.TREE_CELLS:
		var node: Node2D = tree.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, &"tree")


## The way back: the gap beyond the east end of the road.
func _add_farm_gate() -> void:
	var top_left: Vector2i = TownLayout.FARM_GATE[0]
	var rect := Rect2(top_left * TILE_PX, Vector2(TILE_PX, TILE_PX * TownLayout.FARM_GATE.size()))
	_add_zone(rect, FARM_ID, &"from_town")


func _add_zone(rect: Rect2, to: StringName, arrival: StringName) -> void:
	add_child(ExitZone.create(rect, to, arrival))


func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_farm") as Marker2D
	if spawn == null:
		push_warning("Town has no spawn point '%s'" % point)
		spawn = _spawns.get_node(^"from_farm")
	_player.position = spawn.position


## Keep the camera inside the town and its border, so it never shows past the
## edge of the world.
func _limit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = -TILE_PX
	camera.limit_top = -TILE_PX
	camera.limit_right = (TownLayout.SIZE.x + 1) * TILE_PX
	camera.limit_bottom = (TownLayout.SIZE.y + 1) * TILE_PX
