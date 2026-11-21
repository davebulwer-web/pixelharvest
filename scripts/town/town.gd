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
## off in town (the farm's tiles aren't here to be hoed), and so is sleeping,
## except the fishing rod (DECISIONS 054): the player asks this scene
## water_at(cell), the pond or the river, and the tile cursor shows where
## the rod would cast.
##
## The bridge to the Woods (DECISIONS 052) stands at the top of the pond path:
## broken until the Woods open (the mayor's request pays for it, and it's
## ready by summer), then whole, with the way into the Woods beyond it.
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
## Shopkeepers can ask too (DECISIONS 044): their ShopCounter asks Quests.
##
## Festivals (DECISIONS 059): on a festival day its host stands at the
## festival, its decorations are put up like the town's own objects, and
## talking to the host goes to the Festivals service first (entering the
## contest, the results, the keepsake), unless they're waiting for a request
## you can hand in.
##
## The townsfolk themselves (DECISIONS 067) are PeopleHere's: who's in town
## now by their schedules, walking between their stops, coming and going
## along the roads and through the doors, and what they say. This scene keeps
## the notice board and the market stalls.
##
##   Town
##   ├── Ground      (TileMapLayer, same seasonal tilesets as the farm)
##   ├── Bridge      (the bridge over the river to the Woods, whole or broken)
##   ├── SpawnPoints (Marker2Ds, made here: one per door, one for the road east
##   │                to the Lane (made by Exits, DECISIONS 060), one for the bridge)
##   ├── Entities    (y-sorted: player, trees, decoration, shop fronts, people
##   │                (PeopleHere's), market stalls and their keepers)
##   ├── Weather     (the season's and the day's overlays — rain, snow — as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm; lamp posts glow at night)
##   ├── Hud         (the same HUD scene as the farm)
##   ├── Dialogue    (the dialogue box, as in the shops)
##   ├── ShopMenu    (the shop menu, for the market stalls)
##   └── People      (PeopleHere, made here: the townsfolk; DECISIONS 067)
##

const TILE_PX := 16
const TOWN_ID := &"town"
const WOODS_ID := &"woods"

## The bridge's pictures: whole (the Woods are open) and broken (not yet).
const BRIDGE_WHOLE: Texture2D = preload("res://assets/sprites/town/bridge.png")
const BRIDGE_BROKEN: Texture2D = preload("res://assets/sprites/town/bridge_broken.png")

@onready var _ground: TileMapLayer = $Ground
@onready var _bridge: Sprite2D = $Bridge
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather
@onready var _dialogue = $Dialogue
@onready var _menu = $ShopMenu

var _counter: ShopCounter

## True once the bridge to the Woods is mended: its cells are dry then.
var _bridge_open: bool = false

## The outline on the water the fishing rod would cast into, shown only when
## it would (as in the Woods).
var _cursor: Node2D

## The market stalls' shops standing here today, by shop id.
var _stall_shops: Dictionary = {}  # StringName -> ShopDef

## Each stall's nodes (the stall and its keeper), by shop id, so they can be
## packed away when the market closes.
var _stall_nodes: Dictionary = {}  # StringName -> Array[Node]

## The "!" or "?" over each market keeper's head, by shop id, and the
## notice board's (the townsfolk's are PeopleHere's).
var _markers: Dictionary = {}  # StringName -> Label

## The board's job, waiting to be offered once its notices have been read,
## and while the player is choosing whether to take it (DECISIONS 050).
var _board_offers: Array[QuestDef] = []
var _asking_at_board: Array[QuestDef] = []

## The townsfolk (DECISIONS 067).
var _people: PeopleHere


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	var doors: Array[LocationDef] = LocationManager.buildings_on(TOWN_ID)
	var door_cells: Array[Vector2i] = []
	for def in doors:
		door_cells.append_array(Building.door_cells(def))

	SeasonLook.apply_ground(_ground)
	GroundEdges.attach(_ground)
	var bridge_open := _woods_open()
	_bridge_open = bridge_open
	var town := LocationManager.find(TOWN_ID)
	var tiles := TownLayout.build(door_cells, Exits.gap_cells(town), bridge_open)
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	_cursor = preload("res://scripts/tile_cursor.gd").new()
	_cursor.name = "TileCursor"
	add_child(_cursor)
	move_child(_cursor, _entities.get_index())

	for def in doors:
		_entities.add_child(Building.create(def))
		_add_spawn(StringName("from_%s" % def.id), Building.doorstep(def))
	_add_spawn(&"from_woods", TownLayout.ARRIVAL_FROM_WOODS)
	# The road east to the Lane (and on to the farm): town.tres's exits.
	Exits.add(self, town, _spawns)
	_add_bridge(bridge_open)
	_place_objects()
	_place_festival_decorations()
	PackLook.dress(_entities, TOWN_ID)  # TEST (DECISIONS 081)
	Scenery.add_to(self, _entities, TOWN_ID)  # Dave's scenery (DECISIONS 082)
	_mark_notice_board()
	_people = PeopleHere.create(TOWN_ID, _entities, TownLayout.SIZE, _dialogue, _menu)
	add_child(_people)
	_place_stalls()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	_limit_camera()
	_counter = ShopCounter.new(_dialogue, _menu)
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	EventBus.notice_board_read.connect(_on_notice_board_read)
	_dialogue.finished.connect(func() -> void: _offer_board_job())
	_dialogue.chosen.connect(_on_board_job_chosen)
	# Turning orders down takes the "!" away (Rosa's or the board's).
	_dialogue.chosen.connect(func(_i: int) -> void: _refresh_markers.call_deferred())
	EventBus.time_changed.connect(func(_m: int) -> void: _pack_up_closed_stalls())
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: _refresh_markers())
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: _refresh_markers())
	# A festival's "!" goes once you've entered, and "?" comes with the results.
	EventBus.festival_entered.connect(func(_e: StringName, _w: String) -> void: _refresh_markers())
	EventBus.festival_judged.connect(func(_e: StringName, _p: int, _w: String) -> void: _refresh_markers())
	EventBus.festival_gift_given.connect(func(_e: StringName) -> void: _refresh_markers())
	# A gift of gold is ready when the purse is full enough (DECISIONS 049).
	EventBus.gold_changed.connect(func(_g: int, _d: int) -> void: _refresh_markers())
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
		_stand_object(cell, TownLayout.OBJECTS[cell])


## Today's festivals' decorations, put up for the day (DECISIONS 059).
func _place_festival_decorations() -> void:
	for event in GameState.events_today():
		if event.location != TOWN_ID:
			continue
		for cell: Vector2i in event.decorations:
			_stand_object(cell, event.decorations[cell])


func _stand_object(cell: Vector2i, id: StringName) -> void:
	var def := ContentDB.object(id)
	if def == null or def.scene == null:
		push_warning("Town can't place '%s' at %s: no data/objects/ file with that id and a scene"
				% [id, cell])
		return
	var node: Node2D = def.scene.instantiate()
	node.position = _base_of(cell)
	_entities.add_child(node)
	SeasonLook.skin_object(node, id)


## The board's daily job (DECISIONS 050) gets a "!" or "?" like a person's.
func _mark_notice_board() -> void:
	for board in get_tree().get_nodes_in_group(&"notice_board"):
		if is_ancestor_of(board):
			_markers[Quests.BOARD] = Npc.quest_marker_on(board, board.MARKER_HEIGHT)


## Ask what each stall keeper's and the board's marker should say now (a
## festival's host about the festival first, then the Quests service), and
## the townsfolk's.
func _refresh_markers() -> void:
	if _people != null:
		_people.refresh_markers()
	for id: StringName in _markers:
		var text := Festivals.marker_for(id)
		_markers[id].text = text if text != "" else Quests.marker_for(id)


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
			var keeper := Stall.keeper_for(stall)
			var nodes: Array[Node] = [Stall.create(stall), keeper]
			for node in nodes:
				_entities.add_child(node)
			_markers[stall.shop.id] = keeper.add_quest_marker()
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
		_markers.erase(shop_id)
		_stall_shops.erase(shop_id)
		_stall_nodes.erase(shop_id)


## The kind of water at `cell` for the fishing rod (DECISIONS 054): &"pond",
## &"river", or &"" for dry land.
func water_at(cell: Vector2i) -> StringName:
	return TownLayout.water_at(cell, _bridge_open)


func _physics_process(_delta: float) -> void:
	# Outline the water the held rod would cast into, only when it would.
	var cells: Array[Vector2i] = []
	var tool := GameState.selected_tool()
	if tool != null and tool.action != null and tool.action.usable_in_season(GameState.season_id()) \
			and not Fishing.is_busy():
		for cell in _player.target_cells():
			if tool.action.can_use_away(self, cell):
				cells.append(cell)
	_cursor.set_cells(cells)


## True once the Woods are open: the bridge is mended (DECISIONS 052).
func _woods_open() -> bool:
	var woods := _location(WOODS_ID)
	return woods != null and GameState.has_unlock(woods.requires_unlock)


func _location(id: StringName) -> LocationDef:
	for each in LocationManager.all():
		if each.id == id:
			return each
	return null


## The bridge over the river at the top of the pond path. Whole, it has the
## way into the Woods at its far end. Broken, its cells are river, and
## walking up to it says why there's no way across (the Woods' locked
## message), as a shut shop door does.
func _add_bridge(open: bool) -> void:
	var top_left: Vector2i = TownLayout.WOODS_GATE[0] if open else TownLayout.BRIDGE.position
	_bridge.texture = BRIDGE_WHOLE if open else BRIDGE_BROKEN
	_bridge.position = Vector2(top_left * TILE_PX)
	var width := TILE_PX * TownLayout.WOODS_GATE.size()
	if open:
		_add_zone(Rect2(TownLayout.WOODS_GATE[0] * TILE_PX, Vector2(width, TILE_PX)), WOODS_ID, &"from_town")
	else:
		# Just this side of the river: the bank at the top of the path.
		var bank := Vector2i(TownLayout.BRIDGE.position.x, TownLayout.BRIDGE.end.y)
		_add_zone(Rect2(bank * TILE_PX, Vector2(width, TILE_PX / 2.0)), WOODS_ID, &"from_town")


func _add_zone(rect: Rect2, to: StringName, arrival: StringName) -> void:
	add_child(ExitZone.create(rect, to, arrival))


func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_lane") as Marker2D
	if spawn == null:
		push_warning("Town has no spawn point '%s'" % point)
		spawn = _spawns.get_node(^"from_lane")
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

## A market stall's keeper was spoken to (the townsfolk are PeopleHere's).
func _on_npc_talked_to(npc_id: StringName) -> void:
	if _stall_shops.has(npc_id):
		_counter.serve(_stall_shops[npc_id])


## Reading the board: first the day's job, if one is in hand (handed in at
## the board if it's ready, or a reminder), then the notices, then, if
## today's job hasn't been taken, whether to take it (DECISIONS 050).
func _on_notice_board_read() -> void:
	var lines := Quests.talk(Quests.BOARD)
	lines.append_array(Notices.today())
	_board_offers = Quests.orders_on_offer(Quests.BOARD)
	_dialogue.say("Notice board", lines)


## After the notices: the job, if there's one to take.
func _offer_board_job() -> void:
	var offers := _board_offers
	_board_offers = []
	if offers.is_empty():
		return
	_asking_at_board = offers
	var answers: Array[String] = []
	for order in offers:
		answers.append("Take it: " + Quests.order_choice_text(order))
	answers.append("Leave it")
	var question := Quests.choice_line(Quests.BOARD)
	if offers.size() == 1:
		question = offers[0].offer_lines[0] if not offers[0].offer_lines.is_empty() else question
	_dialogue.ask("Help wanted", question, answers)


func _on_board_job_chosen(index: int) -> void:
	var offers := _asking_at_board
	_asking_at_board = []
	if offers.is_empty():
		return  # a shopkeeper's question, answered by the ShopCounter
	if index >= offers.size():
		Quests.decline(Quests.BOARD)
		return
	var lines := Quests.take(offers[index])
	# The offer line was the question; the rest says it's taken.
	if lines.size() > 1:
		lines = lines.slice(1)
	_dialogue.say("Notice board", lines)
