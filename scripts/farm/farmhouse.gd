extends Node2D
##
## Farmhouse — inside the farmer's house: the bed, the stove, a table, and the
## door back out to the farm. Going to bed (E at the bed) ends the day, and
## every morning starts here (TimeSystem, DECISIONS 033). E at the stove cooks,
## once Mabel has opened the kitchen (DECISIONS 056).
##
## The room, in cells (the back wall is the top two rows):
##
##       wall top  . . . . . . . .
##       wall face ░ ░ ░ ░ ░ ░ ░ ░         y 0-1
##       floor    bed      stove table     y 2   (bed head)
##       floor    bed  you                 y 3   (bed foot; you wake beside it)
##       floor        (  rug  )            y 4-5
##       door ──────── ▒▒ ────────         y 6 (x 3-4)
##
## Nothing here is saved, and nothing farms: like a shop, it's built from data
## each time you come in. It uses the shops' interior tiles.
##

const TILE_PX := 16
const ROOM := Vector2i(8, 6)
const DOOR_CELLS := [3, 4]
const BED_FOOT := Vector2i(1, 3)
const WAKE_CELL := Vector2i(2, 3)
const TABLE_CELL := Vector2i(6, 2)
const STOVE_CELL := Vector2i(4, 2)
const RUG := Rect2i(2, 4, 4, 2)

## The spawn point the farm's door leads to; anything else (a fresh morning, a
## loaded save, a new game) puts the player beside the bed.
const FROM_DOOR := &"door"

# Atlas coordinates into assets/tilesets/interior.png (as in interior.gd)
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const TILE_WALL_TOP := Vector2i(3, 0)
const TILE_RUG := Vector2i(4, 0)
const SOURCE_ID := 0

const BED_TEXTURE := preload("res://assets/sprites/farm/bed.png")
const TABLE_TEXTURE := preload("res://assets/sprites/farm/table.png")
const STOVE_TEXTURE := preload("res://assets/sprites/farm/stove.png")
const STOVE_COLD_TEXTURE := preload("res://assets/sprites/farm/stove_cold.png")

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player


func _ready() -> void:
	_player.can_farm = false
	_draw_room()
	_entities.add_child(Bed.create(BED_TEXTURE, BED_FOOT))
	_add_table()
	_add_stove()
	_add_door()
	_place_player()
	_fit_camera()


func _draw_room() -> void:
	for y in range(-1, ROOM.y + 1):
		for x in range(-1, ROOM.x + 1):
			_ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(Vector2i(x, y)))


func _tile_for(cell: Vector2i) -> Vector2i:
	if cell.y == ROOM.y:  # the bottom wall, with a gap for the door
		return TILE_RUG if cell.x in DOOR_CELLS else TILE_WALL_TOP
	if cell.x < 0 or cell.x >= ROOM.x or cell.y <= 0:
		return TILE_WALL_TOP
	if cell.y == 1:
		return TILE_WALL
	if RUG.has_point(cell):
		return TILE_RUG
	return TILE_FLOOR_ALT if (cell.x + cell.y) % 5 == 0 else TILE_FLOOR


## A small table: solid, scenery only.
func _add_table() -> void:
	var table := StaticBody2D.new()
	table.name = "Table"
	table.position = Vector2(TABLE_CELL.x * TILE_PX + TILE_PX / 2.0, (TABLE_CELL.y + 1) * TILE_PX)
	var sprite := Sprite2D.new()
	sprite.texture = TABLE_TEXTURE
	sprite.offset = Vector2(0, -TABLE_TEXTURE.get_height() / 2.0)
	table.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE_PX - 2, TILE_PX / 2.0)
	shape.shape = box
	shape.position = Vector2(0, -box.size.y / 2.0)
	table.add_child(shape)
	_entities.add_child(table)


## The stove, and the cooking menu it opens (DECISIONS 056). The menu is
## built here in code: it belongs to this room, like a shop's counter menu
## belongs to the shop.
func _add_stove() -> void:
	var menu := CookMenu.new()
	menu.name = "CookMenu"
	add_child(menu)
	var stove := Stove.create(STOVE_TEXTURE, STOVE_COLD_TEXTURE, STOVE_CELL)
	stove.used.connect(menu.open)
	_entities.add_child(stove)


## The doormat: stepping out goes back to the farm, in front of the door.
func _add_door() -> void:
	var rect := Rect2(DOOR_CELLS[0] * TILE_PX, ROOM.y * TILE_PX, TILE_PX * DOOR_CELLS.size(), TILE_PX)
	var here := LocationManager.current()
	var id := here.id if here != null else &"farmhouse"
	var outside := here.outside if here != null else LocationManager.FARM_ID
	add_child(ExitZone.create(rect, outside, StringName("from_%s" % id)))


func _place_player() -> void:
	if LocationManager.take_arrival_point() == FROM_DOOR:
		_player.position = Vector2(DOOR_CELLS[1] * TILE_PX, ROOM.y * TILE_PX - 4)
	else:
		_player.position = Vector2(WAKE_CELL.x * TILE_PX + TILE_PX / 2.0, (WAKE_CELL.y + 1) * TILE_PX - 2)


## The room is smaller than the screen, so pin the camera to it (as the shops do).
func _fit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	var centre := Vector2(ROOM.x * TILE_PX / 2.0, (ROOM.y + 1) * TILE_PX / 2.0 - TILE_PX / 2.0)
	var half_view := Vector2(get_viewport_rect().size) / 2.0 / camera.zoom
	camera.limit_left = int(centre.x - half_view.x)
	camera.limit_right = int(centre.x + half_view.x)
	camera.limit_top = int(centre.y - half_view.y)
	camera.limit_bottom = int(centre.y + half_view.y)
	camera.position_smoothing_enabled = false
