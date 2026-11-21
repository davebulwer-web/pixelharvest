extends Node2D
##
## Home — inside one of the townsfolk's homes (DECISIONS 084): the mayor's
## house, Wren's cottage, Pip's family's and Ivy's cottages, Dot's yard, Tam's
## fish shed, Rosa's cottage. One scene serves them all, like the shops'
## interior: the LocationDef you came in by gives the room's size, its door
## and where whoever lives there stands (room_size, room_door_x,
## resident_cell), so a new home is data, never code.
##
## The room, in cells (the back wall's face is the top two rows):
##
##       wall top  . . . . . . . . . .
##       wall face ░ ░ ░ ░ ░ ░ ░ ░ ░ ░       y 0-1
##       floor                                y 2 …
##       floor              resident          (resident_cell)
##       door ──────────  ▒▒ ──────────       y = room_size.y (room_door_x, +1)
##
## What makes each one somebody's (the bed, the books, the nets) is the Cozy
## Interiors pack's furniture, laid in by InteriorLook from
## art/build_interior_look.py. Without the pack (it's kept out of git) a home
## is a plain room with our interior tiles: it still works.
##
## Who's in comes from their schedule, as in the Wheatsheaf (PeopleHere,
## DECISIONS 068): someone at home stands at their spot and talks as they do
## outside (requests, their counter, the day's line); someone due out walks
## to the door and goes. Nothing here is saved: leave and the room is rebuilt
## from data. The door is open in visiting hours (LocationDef.open_from,
## open_until); you can stay on past them, it just won't let you back in.
##

const TILE_PX := 16

# Atlas coordinates into assets/tilesets/interior.png (as in interior.gd)
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const TILE_WALL_TOP := Vector2i(3, 0)
const TILE_RUG := Vector2i(4, 0)
const SOURCE_ID := 0

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

var _location: LocationDef
var _room: Vector2i
var _door: Array = []
var _people: PeopleHere


func _ready() -> void:
	_player.can_farm = false
	_location = LocationManager.current()
	if _location == null or _location.scene_path != scene_file_path:
		# Run on its own with F6, or a save naming somewhere else: use the
		# first home there is, so the room can still be seen.
		for def in LocationManager.all():
			if def.scene_path == scene_file_path:
				_location = def
				break
	if _location == null:
		push_error("Home opened but no location uses scenes/home.tscn")
		return
	_room = _location.room_size
	_door = [_location.room_door_x, _location.room_door_x + 1]

	# The player first, just inside the door: the scene's own spot for them can
	# be on the doormat of a smaller room, which would send them straight out.
	_player.position = Vector2(_door[1] * TILE_PX, _room.y * TILE_PX - 4)
	LocationManager.take_arrival_point()
	_draw_room()
	_add_door()
	# The Cozy Interiors pack's furniture, if built (Ctrl+R flips it).
	InteriorLook.dress(self, _entities, _location.id, _room, _door)
	_people = PeopleHere.create_inside(_location.id, _entities, _room, _dialogue, _menu,
			Vector2i(_door[0], _room.y), [], _location.resident_cell)
	add_child(_people)
	_fit_camera()


func _draw_room() -> void:
	for y in range(-1, _room.y + 1):
		for x in range(-1, _room.x + 1):
			_ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(Vector2i(x, y)))


func _tile_for(cell: Vector2i) -> Vector2i:
	if cell.y == _room.y:  # the bottom wall, with a gap for the door
		return TILE_RUG if cell.x in _door else TILE_WALL_TOP
	if cell.x < 0 or cell.x >= _room.x or cell.y <= 0:
		return TILE_WALL_TOP
	if cell.y == 1:
		return TILE_WALL
	return TILE_FLOOR_ALT if (cell.x + cell.y) % 5 == 0 else TILE_FLOOR


## The doormat: stepping out goes back to the map outside, onto the doorstep.
func _add_door() -> void:
	var rect := Rect2(_door[0] * TILE_PX, _room.y * TILE_PX, TILE_PX * _door.size(), TILE_PX)
	add_child(ExitZone.create(rect, _location.outside, StringName("from_%s" % _location.id)))


## The room is smaller than the screen, so pin the camera to it (as the shops do).
func _fit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	var centre := Vector2(_room.x * TILE_PX / 2.0, (_room.y + 1) * TILE_PX / 2.0 - TILE_PX / 2.0)
	var half_view := Vector2(get_viewport_rect().size) / 2.0 / camera.zoom
	camera.limit_left = int(centre.x - half_view.x)
	camera.limit_right = int(centre.x + half_view.x)
	camera.limit_top = int(centre.y - half_view.y)
	camera.limit_bottom = int(centre.y + half_view.y)
	camera.position_smoothing_enabled = false
