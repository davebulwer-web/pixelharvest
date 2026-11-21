extends Node2D
##
## Tavern — inside Nell's tavern, the Wheatsheaf (DECISIONS 068, ROADMAP 13.3
## #10): open 4 PM to 1 AM, the evening's place to be.
##
## The room, in cells (the back wall is the top two rows):
##
##       wall top  . . . . . . . . . . . . . . . .
##       wall face ░ ░ ░ ░ ░ ░ ░ ░ [chalk] [fire] ░ [darts]   y 0-1
##        Nell behind the bar     ▒barrels                   y 2-3
##       [=====  bar  =====]                                 y 4
##                              (table)                      y 6
##          (table)                     (table)              y 7-8
##       door ────────────────  ▒▒ ─────────────             y 10 (x 7-8)
##
## Nell keeps the bar like a shop's keeper (her ShopDef, data/shops/
## tavern.tres, keeper_id &"nell"): talk to her across it for her requests
## first, then tonight's rumour (Tavern.rumour_tonight), then the menu: a hot
## meal, and selling her what's on the chalkboard. Everyone else here is
## here by their schedule (a stop at &"tavern" with a cell in this room) and
## comes and goes by the door: PeopleHere, as on the maps outside.
##
## On the back wall: the chalkboard (what's wanted today) and the dartboard,
## which on darts night (Fridays from 7 PM) gives you one go a night at the
## pot (DartsGame). Like the shops, nothing here is saved: leave and the room
## is rebuilt from data.
##

const TILE_PX := 16
const ROOM := Vector2i(16, 10)
const DOOR_CELLS := [7, 8]
const KEEPER_CELL := Vector2i(2, 3)
const BAR_CELLS := Rect2i(0, 4, 6, 1)
## The end of the bar, where the barrels stand: solid, so nobody walks
## round behind it.
const BARRELS_CELLS := Rect2i(6, 2, 2, 2)
const CHALKBOARD_CELLS: Array[Vector2i] = [Vector2i(9, 1), Vector2i(10, 1)]
const FIREPLACE_CELLS := Rect2i(11, 1, 2, 2)
const DARTBOARD_CELLS: Array[Vector2i] = [Vector2i(14, 1)]
## Each table's left cell; a table is two cells wide.
const TABLES: Array[Vector2i] = [Vector2i(2, 7), Vector2i(9, 6), Vector2i(12, 8)]

# Atlas coordinates into assets/tilesets/interior.png (as the shops).
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const TILE_WALL_TOP := Vector2i(3, 0)
const TILE_RUG := Vector2i(4, 0)
const SOURCE_ID := 0

const BAR_TEXTURE := preload("res://assets/sprites/town/tavern_bar.png")
const TABLE_TEXTURE := preload("res://assets/sprites/town/tavern_table.png")
const BARRELS_TEXTURE := preload("res://assets/sprites/town/barrels.png")
const FIREPLACE_TEXTURE := preload("res://assets/sprites/town/fireplace.png")
const CHALKBOARD_TEXTURE := preload("res://assets/sprites/town/chalkboard.png")
const DARTBOARD_TEXTURE := preload("res://assets/sprites/town/dartboard.png")

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

var _location: LocationDef
var _shop: ShopDef
var _counter: ShopCounter
var _people: PeopleHere
var _darts: DartsGame

## The "!" or "?" over Nell's head.
var _marker: Label

## True while the dialogue box is asking whether you'll have a go at darts.
var _asking_darts: bool = false


func _ready() -> void:
	_player.can_farm = false
	_location = LocationManager.current()
	if _location == null or _location.shop == null or not _location.shop.chalkboard:
		# Run on its own with F6: use the tavern, so the room can still be seen.
		_location = LocationManager.find(Tavern.SHOP_ID)
	if _location == null or _location.shop == null:
		push_error("The tavern's room opened but there's no tavern in game_rules.tres")
		return
	_shop = _location.shop

	_draw_room()
	_add_furniture()
	_add_keeper()
	_add_door()
	# TEST (DECISIONS 083): the Cozy Interiors pack's furniture, if built (Ctrl+R).
	InteriorLook.dress(self, _entities, &"tavern", ROOM, DOOR_CELLS)
	var exclude: Array[StringName] = [_shop.keeper_id]
	_people = PeopleHere.create_inside(_location.id, _entities, ROOM, _dialogue, _menu,
			Vector2i(DOOR_CELLS[0], ROOM.y), exclude)
	add_child(_people)
	_darts = DartsGame.new()
	_darts.name = "Darts"
	add_child(_darts)
	_darts.finished.connect(_on_darts_finished)
	_player.position = Vector2(DOOR_CELLS[1] * TILE_PX, ROOM.y * TILE_PX - 4)
	LocationManager.take_arrival_point()
	_fit_camera()
	_counter = ShopCounter.new(_dialogue, _menu)
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	_dialogue.chosen.connect(_on_chosen)


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
	# A long rug from the door up to the bar.
	if cell.x >= 6 and cell.x <= 9 and cell.y >= 5:
		return TILE_RUG
	return TILE_FLOOR_ALT if (cell.x * 3 + cell.y) % 7 == 0 else TILE_FLOOR


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## A solid picture covering `cells`, its bottom edge on their bottom row.
func _add_solid(node_name: String, texture: Texture2D, cells: Rect2i, pictures: int = 1) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = Vector2(cells.get_center().x * TILE_PX, cells.end.y * TILE_PX)
	var step := float(cells.size.x * TILE_PX) / pictures
	for i in pictures:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(-cells.size.x * TILE_PX / 2.0 + step * (i + 0.5), 0)
		sprite.offset = Vector2(0, -texture.get_height() / 2.0)
		body.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(cells.size.x * TILE_PX, cells.size.y * TILE_PX)
	shape.shape = box
	shape.position = Vector2(0, -cells.size.y * TILE_PX / 2.0)
	body.add_child(shape)
	_entities.add_child(body)


func _add_furniture() -> void:
	_add_solid("Bar", BAR_TEXTURE, BAR_CELLS, 2)
	_add_solid("Barrels", BARRELS_TEXTURE, BARRELS_CELLS)
	_add_solid("Fireplace", FIREPLACE_TEXTURE, FIREPLACE_CELLS)
	for i in TABLES.size():
		# Only the table's middle is solid (one cell high): the stools drawn
		# either side are where people stand.
		_add_solid("Table%d" % (i + 1), TABLE_TEXTURE, Rect2i(TABLES[i], Vector2i(2, 1)))

	var chalkboard := TavernFixture.create("Chalkboard", CHALKBOARD_TEXTURE, CHALKBOARD_CELLS)
	chalkboard.used.connect(_read_chalkboard)
	_entities.add_child(chalkboard)
	var dartboard := TavernFixture.create("Dartboard", DARTBOARD_TEXTURE, DARTBOARD_CELLS)
	dartboard.used.connect(_face_dartboard)
	_entities.add_child(dartboard)


## Nell behind the bar: the shop's keeper, talked to across it.
func _add_keeper() -> void:
	var keeper := Npc.create(_shop.id, _shop.keeper_sprite, KEEPER_CELL)
	for x in range(BAR_CELLS.position.x, BAR_CELLS.end.x):
		keeper.talk_cells.append(Vector2i(x, BAR_CELLS.position.y))
	_entities.add_child(keeper)
	_marker = keeper.add_quest_marker()
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed, EventBus.gold_changed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: _refresh_marker())
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: _refresh_marker())
	_refresh_marker()


func _refresh_marker() -> void:
	_marker.text = Quests.marker_for(_giver())


func _giver() -> StringName:
	return _shop.keeper_id if _shop.keeper_id != &"" else _shop.id


func _add_door() -> void:
	var rect := Rect2(DOOR_CELLS[0] * TILE_PX, ROOM.y * TILE_PX, TILE_PX * DOOR_CELLS.size(), TILE_PX)
	add_child(ExitZone.create(rect, _location.outside, StringName("from_%s" % _location.id)))


## The room is smaller than the screen: pin the camera to it.
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

## Nell, across the bar: her requests first (the counter asks them), then
## tonight's rumour, then the menu.
func _on_npc_talked_to(npc_id: StringName) -> void:
	if npc_id != _shop.id:
		return
	var lines: Array[String] = []
	var rumour := Tavern.rumour_tonight()
	if rumour != "":
		lines.append(rumour)
	_counter.serve(_shop, _giver(), lines)


func _read_chalkboard() -> void:
	_dialogue.say("Chalkboard", Tavern.chalkboard_lines())


## The dartboard: on darts night, once the darts are out, a go at the pot
## (if you haven't had one tonight); otherwise when darts night is.
func _face_dartboard() -> void:
	if Tavern.darts_on_now() and not Tavern.has_played_tonight():
		var best := Tavern.tonights_best()
		_asking_darts = true
		var answers: Array[String] = ["Have a go", "Not now"]
		_dialogue.ask("Darts night",
				"Three darts. Tonight's best is %s's %d: beat it and the pot's yours, %dg. One go a night."
				% [best["who"], best["score"], Tavern.rules().darts_prize_gold], answers)
		return
	_dialogue.say("Dartboard", Tavern.darts_board_lines())


func _on_chosen(index: int) -> void:
	if not _asking_darts:
		return  # someone else's question
	_asking_darts = false
	if index == 0:
		_darts.open.call_deferred()


func _on_darts_finished(lines: Array[String]) -> void:
	if not lines.is_empty():
		_dialogue.say("Darts night", lines)
