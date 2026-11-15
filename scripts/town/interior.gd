extends Node2D
##
## Interior — the inside of a shop. One scene serves every shop: the room is the
## same, and the LocationDef the player entered by says whose it is (its ShopDef
## gives the shopkeeper, their words and the menu behind the counter).
##
## The room, in cells (the back wall is the top two rows):
##
##       wall top  . . . . . . . . . . . .
##       wall face ░ ░ ░ shelves ░ ░ ░ ░ ░         y 0-1
##       floor        keeper                       y 3
##       floor      [  counter  ]                  y 4
##       floor   (rug)                             y 5-7
##       door ──────────  ▒▒ ──────────            y 8 (x 5-6)
##
## Talking is E at the counter (Npc announces it on EventBus; this listens for
## its own keeper). The dialogue box runs first, then the shop menu. After
## closing time (ShopDef.closes_at) the keeper says so instead, and the menu
## stays shut; the door still lets you out (DECISIONS 035). The door
## is a walk-in ExitZone back to the town, appearing in front of that shop's
## door. Nothing here is saved: leave and the room is rebuilt from data.
##

const TILE_PX := 16
const ROOM := Vector2i(12, 8)
const DOOR_CELLS := [5, 6]
const KEEPER_CELL := Vector2i(6, 3)
const COUNTER_CELLS := Rect2i(3, 4, 6, 1)

# Atlas coordinates into assets/tilesets/interior.png
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const TILE_WALL_TOP := Vector2i(3, 0)
const TILE_RUG := Vector2i(4, 0)
const SOURCE_ID := 0

const COUNTER_TEXTURE := preload("res://assets/sprites/town/counter.png")
const SHELF_TEXTURE := preload("res://assets/sprites/town/shelf.png")

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

var _location: LocationDef
var _shop: ShopDef

## True while the keeper is saying "we're closed", so the menu doesn't open
## when that conversation ends.
var _turning_away: bool = false


func _ready() -> void:
	_player.can_farm = false
	_location = LocationManager.current()
	if _location == null or _location.shop == null:
		# Run on its own with F6, or a save naming something that isn't a
		# shop: use the first shop there is, so the room can still be seen.
		for def in LocationManager.all():
			if def.shop != null:
				_location = def
				break
	if _location == null:
		push_error("Interior opened but no location has a shop")
		return
	_shop = _location.shop

	_draw_room()
	_add_furniture()
	_add_keeper()
	_add_door()
	_player.position = Vector2(DOOR_CELLS[1] * TILE_PX, ROOM.y * TILE_PX - 4)
	LocationManager.take_arrival_point()
	_fit_camera()
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	_dialogue.finished.connect(_on_dialogue_finished)


func _draw_room() -> void:
	for y in range(-1, ROOM.y + 1):
		for x in range(-1, ROOM.x + 1):
			_ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(Vector2i(x, y)))


func _tile_for(cell: Vector2i) -> Vector2i:
	if cell.y == ROOM.y:  # the bottom wall, with a gap for the door
		return TILE_RUG if cell.x in DOOR_CELLS else TILE_WALL_TOP
	if cell.x < 0 or cell.x >= ROOM.x or cell.y < 0:
		return TILE_WALL_TOP
	if cell.y == 0:
		return TILE_WALL_TOP
	if cell.y == 1:
		return TILE_WALL
	if cell.x >= 4 and cell.x <= 7 and cell.y >= 6:
		return TILE_RUG
	return TILE_FLOOR_ALT if (cell.x + cell.y) % 5 == 0 else TILE_FLOOR


func _add_furniture() -> void:
	# The counter: two pictures side by side and one solid box under them.
	var counter := StaticBody2D.new()
	counter.name = "Counter"
	counter.position = Vector2(COUNTER_CELLS.get_center().x * TILE_PX, COUNTER_CELLS.end.y * TILE_PX)
	for x_offset in [-24.0, 24.0]:
		var sprite := Sprite2D.new()
		sprite.texture = COUNTER_TEXTURE
		sprite.position = Vector2(x_offset, 0)
		sprite.offset = Vector2(0, -COUNTER_TEXTURE.get_height() / 2.0)
		counter.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(COUNTER_CELLS.size.x * TILE_PX, TILE_PX)
	shape.shape = box
	shape.position = Vector2(0, -TILE_PX / 2.0)
	counter.add_child(shape)
	_entities.add_child(counter)

	# Shelves along the back wall: scenery only (the wall itself is solid).
	for x in [1, 3, 8, 10]:
		var shelf := Sprite2D.new()
		shelf.texture = SHELF_TEXTURE
		shelf.position = Vector2(x * TILE_PX + SHELF_TEXTURE.get_width() / 2.0 - TILE_PX / 2.0, 2 * TILE_PX - 4)
		shelf.offset = Vector2(0, -SHELF_TEXTURE.get_height() / 2.0)
		_entities.add_child(shelf)


func _add_keeper() -> void:
	var keeper := Npc.create(_shop.id, _shop.keeper_sprite, KEEPER_CELL)
	# You can't reach the keeper, so facing any cell of the counter counts.
	for x in range(COUNTER_CELLS.position.x, COUNTER_CELLS.end.x):
		keeper.talk_cells.append(Vector2i(x, COUNTER_CELLS.position.y))
	_entities.add_child(keeper)


## The doormat: stepping out of the room's gap goes back to the town, to the
## spot in front of this shop's door (the town makes a "from_<id>" for each).
func _add_door() -> void:
	var rect := Rect2(DOOR_CELLS[0] * TILE_PX, ROOM.y * TILE_PX, TILE_PX * DOOR_CELLS.size(), TILE_PX)
	add_child(ExitZone.create(rect, _location.outside, StringName("from_%s" % _location.id)))


## The room is smaller than the screen, so pin the camera to it rather than
## letting it drift after the player: it ends up centred on the room.
func _fit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	var centre := Vector2(ROOM.x * TILE_PX / 2.0, (ROOM.y + 1) * TILE_PX / 2.0 - TILE_PX / 2.0)
	var half_view := Vector2(get_viewport_rect().size) / 2.0 / camera.zoom
	camera.limit_left = int(centre.x - half_view.x)
	camera.limit_right = int(centre.x + half_view.x)
	camera.limit_top = int(centre.y - half_view.y)
	camera.limit_bottom = int(centre.y + half_view.y)
	camera.position_smoothing_enabled = false


# --- Talking -----------------------------------------------------------------

func _on_npc_talked_to(npc_id: StringName) -> void:
	if npc_id == _shop.id and not _shop.is_open_at(GameState.minutes):
		_turning_away = true
		var closed_lines: Array[String] = [
			"Sorry, we're closed for today. Come back tomorrow — I'm open %s." % _shop.hours_text()]
		_dialogue.say(_shop.keeper_name, closed_lines)
		return
	if npc_id != _shop.id or _shop.greetings.is_empty():
		if npc_id == _shop.id:
			_menu.open(_shop)
		return
	# One greeting a day: the same line all day, a new one tomorrow.
	var greeting := _shop.greetings[GameState.day % _shop.greetings.size()]
	var lines: Array[String] = [greeting]
	_dialogue.say(_shop.keeper_name, lines)


func _on_dialogue_finished() -> void:
	if _turning_away:
		_turning_away = false
		return
	_menu.open(_shop)
