extends Node2D
##
## Town — the town scene: the road, the square, a door for every shop, and
## the people who live here, and on market day the market's stalls.
##
## Like the farm it owns no game state. It draws a fixed map (TownLayout) and
## stands its decoration on it, builds a Building for every location whose
## door is on this map and an Npc for every CharacterDef who lives here (so a
## new shop or a new townsperson appears with no edit to this file), sets up
## a Stall for every stall of today's calendar events (DECISIONS 037), and puts
## the arriving player at the spawn point LocationManager asked for. Tools are
## off in town (the farm's tiles aren't here to be hoed), and so is sleeping.
##
## Talking: E on a townsperson or the notice board is announced on EventBus
## (npc_talked_to, notice_board_read); this scene answers with the dialogue
## box. Shopkeepers indoors never reach here; a market stall's keeper does,
## and is served by a ShopCounter, exactly as a keeper indoors is.
##
## Requests (DECISIONS 038): a townsperson with a request to make, remind you
## of or take in says that instead of their line for the day — the Quests
## service decides, this scene only says it. A "!" over someone's head means
## they have something to ask, a "?" that you have what they asked for.
##
##   Town
##   ├── Ground      (TileMapLayer, same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made here: one per door, one for the farm gate)
##   ├── Entities    (y-sorted: player, trees, decoration, shop fronts, people,
##   │                market stalls and their keepers)
##   ├── Weather     (the season's overlay — winter's snow — as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm; lamp posts glow at night)
##   ├── Hud         (the same HUD scene as the farm)
##   ├── Dialogue    (the dialogue box, as in the shops)
##   └── ShopMenu    (the shop menu, for the market stalls)
##

const TILE_PX := 16
const TOWN_ID := &"town"
const FARM_ID := &"farm"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

var _counter: ShopCounter

## The market stalls' shops standing here today, by shop id.
var _stall_shops: Dictionary = {}  # StringName -> ShopDef

## Each stall's nodes (the stall and its keeper), by shop id, so they can be
## packed away when the market closes.
var _stall_nodes: Dictionary = {}  # StringName -> Array[Node]

## The "!" or "?" over each townsperson's head, by character id.
var _markers: Dictionary = {}  # StringName -> Label

## How high the marker floats above a townsperson's feet, in pixels.
const MARKER_HEIGHT := 54


func _ready() -> void:
	_player.can_farm = false
	var doors: Array[LocationDef] = LocationManager.buildings_on(TOWN_ID)
	var door_cells: Array[Vector2i] = []
	for def in doors:
		door_cells.append(def.door_cell)

	SeasonLook.apply_ground(_ground)
	var tiles := TownLayout.build(door_cells)
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])

	for def in doors:
		_entities.add_child(Building.create(def))
		_add_spawn(StringName("from_%s" % def.id), Vector2(
				def.door_cell.x * TILE_PX + TILE_PX / 2.0, (def.door_cell.y + 2) * TILE_PX - 2))
	_add_spawn(&"from_farm", TownLayout.ARRIVAL_FROM_FARM)
	_place_objects()
	_place_townsfolk()
	_place_stalls()
	_add_farm_gate()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	_limit_camera()
	_counter = ShopCounter.new(_dialogue, _menu)
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	EventBus.notice_board_read.connect(_on_notice_board_read)
	EventBus.time_changed.connect(func(_m: int) -> void: _pack_up_closed_stalls())
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: _refresh_markers())
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: _refresh_markers())
	_refresh_markers()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


func _add_spawn(point_name: StringName, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = String(point_name)
	marker.position = at
	_spawns.add_child(marker)


## Stand every tree, lamp, bench and flower bed from TownLayout.OBJECTS. Each
## is an ObjectDef, so it wears its season's picture if the season has one.
func _place_objects() -> void:
	for cell: Vector2i in TownLayout.OBJECTS:
		var id: StringName = TownLayout.OBJECTS[cell]
		var def := ContentDB.object(id)
		if def == null or def.scene == null:
			push_warning("Town can't place '%s' at %s: no data/objects/ file with that id and a scene"
					% [id, cell])
			continue
		var node: Node2D = def.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, id)


## An Npc for everyone who lives in town, at today's spot.
func _place_townsfolk() -> void:
	for person in ContentDB.characters_in(TOWN_ID):
		if person.spots.is_empty():
			continue  # ContentDB has already said so
		var npc := Npc.create(person.id, person.sprite, person.spot_on(GameState.day))
		_entities.add_child(npc)
		_markers[person.id] = _add_marker(npc)


## A small "!" or "?" floating over someone's head, bobbing gently. Empty
## (and so invisible) until they have something to do with a request.
func _add_marker(npc: Npc) -> Label:
	var marker := Label.new()
	marker.name = "QuestMarker"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(16, 14)
	marker.position = Vector2(-8, -MARKER_HEIGHT)
	UiStyle.style_label(marker, 12, UiStyle.HIGHLIGHT)
	npc.add_child(marker)
	var bob := marker.create_tween().set_loops()
	bob.tween_property(marker, ^"position:y", -MARKER_HEIGHT - 2.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, ^"position:y", float(-MARKER_HEIGHT), 0.5).set_trans(Tween.TRANS_SINE)
	return marker


## Ask the Quests service what each townsperson's marker should say now.
func _refresh_markers() -> void:
	for id: StringName in _markers:
		_markers[id].text = Quests.marker_for(id)


## Today's market stalls, if any: every stall of every calendar event on
## today that happens in town. They're up from the start of the day (before
## opening time the keeper says they're not open yet) until their shop's
## closing time, when they're packed away: the square is empty again by the
## evening.
func _place_stalls() -> void:
	for event in GameState.events_today():
		if event.location != TOWN_ID:
			continue
		for stall in event.stalls:
			if stall == null or stall.shop == null:
				continue  # ContentDB has already said so
			if _packed_up(stall.shop):
				continue
			var nodes: Array[Node] = [Stall.create(stall), Stall.keeper_for(stall)]
			for node in nodes:
				_entities.add_child(node)
			_stall_shops[stall.shop.id] = stall.shop
			_stall_nodes[stall.shop.id] = nodes


## True once `shop`'s closing time has passed today.
func _packed_up(shop: ShopDef) -> bool:
	return shop.keeps_hours() and GameState.minutes >= shop.closes_at


## Every 10 minutes: take down any stall whose market has closed.
func _pack_up_closed_stalls() -> void:
	for shop_id: StringName in _stall_shops.keys():
		if not _packed_up(_stall_shops[shop_id]):
			continue
		for node: Node in _stall_nodes[shop_id]:
			node.queue_free()
		_stall_shops.erase(shop_id)
		_stall_nodes.erase(shop_id)


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


# --- Talking -----------------------------------------------------------------

func _on_npc_talked_to(npc_id: StringName) -> void:
	if _stall_shops.has(npc_id):
		_counter.serve(_stall_shops[npc_id])
		return
	var person := ContentDB.character(npc_id)
	if person == null or person.location != TOWN_ID:
		return
	var about_requests := Quests.talk(npc_id)
	if not about_requests.is_empty():
		_dialogue.say(person.display_name, about_requests)
		return
	var line := person.line_on(GameState.day)
	if line == "":
		return
	var lines: Array[String] = [line]
	_dialogue.say(person.display_name, lines)


func _on_notice_board_read() -> void:
	_dialogue.say("Notice board", Notices.today())
