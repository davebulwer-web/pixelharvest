extends "res://scripts/main.gd"
##
## Greenhouse — inside the farm's old greenhouse, once Ivy has had it mended
## (DECISIONS 057): a room with a plot of soil that ignores the seasons and
## the weather.
##
## The plot is a FarmData (GameState.greenhouse), so this scene is the farm's
## scene with a different plot and different surroundings: it extends main.gd,
## and every crop, patch of soil, sprinkler and hive is drawn by the same code
## as on the farm. What it changes:
##
##   _plot()                the greenhouse's FarmData, not the farm's
##   _build_surroundings()  the glass walls, the walkway and the door back out,
##                          instead of the farm's buildings and town gate
##   _apply_season_theme()  nothing: the soil keeps one look all year
##   _apply_season_overlay  nothing: no rain or snow falls indoors
##   _skin_object()         nothing: no snow on a sprinkler under glass
##   _atlas_for()           soil that isn't dug over shows as bare earth, not grass
##
## The room is GreenhouseLayout's: the plot with a walkway round it, and the
## door in the bottom wall. The tools work here exactly as on the farm,
## because the player asks GameState.plot_here() which plot it's standing in.
##

## The spawn point the farm's greenhouse door leads to (Building's ExitZone).
const FROM_DOOR := &"door"

# Atlas coordinates into assets/tilesets/greenhouse_interior.png. The walls
# and wall tops are solid (greenhouse_tileset.tres gives them collision).
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const TILE_WALL_TOP := Vector2i(3, 0)
const TILE_MAT := Vector2i(4, 0)
const FLOOR_SOURCE_ID := 0

@onready var _floor: TileMapLayer = $Floor


func _plot() -> FarmData:
	return GameState.greenhouse


func _build_surroundings() -> void:
	_draw_room()
	_add_door()
	_fit_camera()


## The walls, the walkway and the doormat, round the plot. The plot's own
## tiles are drawn on Ground by main.gd's _draw_all(), over the floor.
func _draw_room() -> void:
	var room := GreenhouseLayout.ROOM
	for y in range(-1, room.y + 1):
		for x in range(-1, room.x + 1):
			var cell := Vector2i(x, y)
			_floor.set_cell(cell, FLOOR_SOURCE_ID, _room_tile_for(cell))


func _room_tile_for(cell: Vector2i) -> Vector2i:
	var room := GreenhouseLayout.ROOM
	if cell.y == room.y:  # the bottom wall, with a gap for the door
		return TILE_MAT if cell.x in GreenhouseLayout.DOOR_CELLS else TILE_WALL_TOP
	if cell.x < 0 or cell.x >= room.x or cell.y <= 0:
		return TILE_WALL_TOP
	if cell.y == 1:
		return TILE_WALL
	return TILE_FLOOR_ALT if (cell.x * 3 + cell.y) % 7 == 0 else TILE_FLOOR


## The doormat: stepping onto it goes back out to the farm, in front of the
## greenhouse's door; and the spawn point for coming in.
func _add_door() -> void:
	var room := GreenhouseLayout.ROOM
	var doors := GreenhouseLayout.DOOR_CELLS
	var rect := Rect2(doors[0] * TILE_PX, room.y * TILE_PX, TILE_PX * doors.size(), TILE_PX)
	var here := LocationManager.current()
	var id := here.id if here != null else GameState.RULES.greenhouse_location
	var outside := here.outside if here != null else LocationManager.FARM_ID
	add_child(ExitZone.create(rect, outside, StringName("from_%s" % id)))
	var marker := Marker2D.new()
	marker.name = String(FROM_DOOR)
	marker.position = Vector2(doors[1] * TILE_PX, room.y * TILE_PX - 4)
	$SpawnPoints.add_child(marker)
	# Whichever way in, the farmer starts at the door (a loaded game never
	# starts in here: every morning is in the farmhouse).
	_player.position = marker.position


## The room is smaller than the screen, so pin the camera to it (as the
## farmhouse and the shops do).
func _fit_camera() -> void:
	var room := GreenhouseLayout.ROOM
	var camera := _player.get_node("Camera2D") as Camera2D
	var centre := Vector2(room.x * TILE_PX / 2.0, (room.y + 1) * TILE_PX / 2.0 - TILE_PX / 2.0)
	var half_view := Vector2(get_viewport_rect().size) / 2.0 / camera.zoom
	camera.limit_left = int(centre.x - half_view.x)
	camera.limit_right = int(centre.x + half_view.x)
	camera.limit_top = int(centre.y - half_view.y)
	camera.limit_bottom = int(centre.y + half_view.y)
	camera.position_smoothing_enabled = false


## The soil keeps the ground tileset the scene was built with (spring's, the
## plainest), whatever the season outside.
func _apply_season_theme() -> void:
	pass


## No rain or snow indoors.
func _apply_season_overlay() -> void:
	pass


## Nothing under glass wears the season's look.
func _skin_object(_node: Node, _object_id: StringName) -> void:
	pass


## A plot tile that isn't dug over (where a sprinkler stood) is bare earth.
func _atlas_for(cell: Vector2i) -> Vector2i:
	var t: FarmTile = plot.tile(cell)
	if t != null and t.tilled:
		return GroundTiles.TILLED_WET if t.watered else GroundTiles.TILLED
	return GroundTiles.PATH


func _print_help() -> void:
	pass
