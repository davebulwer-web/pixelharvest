extends Node2D
##
## Lane — the Lane scene (DECISIONS 060): the country lane between the farm
## and the town, with hedgerows to pick from on the way past.
##
## Like the Woods it owns no game state. It draws a fixed map (LaneLayout),
## stands the fence, the signpost, Dot's cart and the trees on it, builds
## every building whose door is on the Lane (Pip's family's cottage and
## Dot's yard, DECISIONS 061: homes seen from outside, whose doors say who
## lives there), lays out today's hedgerow forage (Forage.spots_today, the
## same as the Woods' mushrooms), and builds its two ends from its
## LocationDef's exits (Exits): west to the town, east to the farm.
##
## Odd jobs and errands (DECISIONS 062): Dot the carrier stands at her gate
## (a CharacterDef who lives on the Lane), with her errands; the allotment
## holders chalk jobs on their slate by the allotments' gate. Both are
## talked to with E, and this scene shows what the Quests service says, and
## asks which to take. The farm's tools work here on an allotment job's bed
## only: the hoe, the can and the sickle ask this scene work_wanted_at() and
## do_work(), which pass to the Allotments service; AllotmentBeds draws the
## beds as it says they are. A tile outline shows where a tool would work.
##
##   Lane
##   ├── Ground      (TileMapLayer, the same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made by Exits: "from_town", "from_farm")
##   ├── Entities    (y-sorted: player, buildings, trees, the fence, the
##   │                signpost, the cart, forage)
##   ├── Weather     (the season's and the day's overlays, as on the farm)
##   ├── Daylight    (the time-of-day tint, as on the farm)
##   ├── Hud         (the same HUD scene as the farm)
##   └── Dialogue    (the dialogue box: Dot, the slate)
##

const TILE_PX := 16
const LANE_ID := &"lane"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather
@onready var _dialogue = $Dialogue

## The outline on the tiles a held tool would work on an allotment job's bed.
var _cursor: Node2D

## The "!" or "?" over Dot's head and the slate, by giver id.
var _markers: Dictionary = {}  # StringName -> Label

## Whose orders are being chosen between (Dot's id or Quests.ALLOTMENTS), and
## the orders; empty when nothing is being asked.
var _asking_for: StringName = &""
var _asking: Array[QuestDef] = []


func _ready() -> void:
	_player.can_farm = false
	_player.tool_place = self
	var location := LocationManager.find(LANE_ID)
	SeasonLook.apply_ground(_ground)
	var buildings := LocationManager.buildings_on(LANE_ID)
	var door_cells: Array[Vector2i] = []
	for def in buildings:
		door_cells.append_array(Building.door_cells(def))
	var tiles := LaneLayout.build(Exits.gap_cells(location), door_cells)
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])
	Exits.add(self, location, _spawns)
	_add_buildings(buildings)
	_place_objects()
	_place_forage()
	_place_people()
	_place_allotments()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	EventBus.weather_changed.connect(func(_w: StringName) -> void: SeasonLook.apply_overlay(_weather))
	_limit_camera()
	_cursor = preload("res://scripts/tile_cursor.gd").new()
	_cursor.name = "TileCursor"
	add_child(_cursor)
	move_child(_cursor, _entities.get_index())
	EventBus.npc_talked_to.connect(_on_talked_to)
	_dialogue.chosen.connect(_on_chosen)
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed, EventBus.time_changed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: _refresh_markers())
	EventBus.quest_expired.connect(func(_id: StringName, _t: String) -> void: _refresh_markers())
	_refresh_markers()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## Every building with its door on the Lane (DECISIONS 061), as the town
## builds its shops. One that can be gone into gets a spawn point on its
## doorstep for coming back out; a home seen only from outside needs none.
func _add_buildings(buildings: Array[LocationDef]) -> void:
	for def in buildings:
		_entities.add_child(Building.create(def))
		if def.has_inside():
			var marker := Marker2D.new()
			marker.name = "from_%s" % def.id
			marker.position = Building.doorstep(def)
			_spawns.add_child(marker)


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


## An Npc for everyone who lives on the Lane (Dot, DECISIONS 062), as the
## town builds its townsfolk, each with a request marker.
func _place_people() -> void:
	for person in ContentDB.characters_in(LANE_ID):
		if person.spots.is_empty() or not GameState.has_unlock(person.requires_unlock):
			continue
		var npc := Npc.create(person.id, person.sprite, person.spot_on(GameState.day))
		_entities.add_child(npc)
		_markers[person.id] = npc.add_quest_marker()


## The allotment holders' slate, and the beds as today's jobs leave them
## (DECISIONS 062).
func _place_allotments() -> void:
	var slate := JobSlate.create(LaneLayout.JOB_SLATE)
	_entities.add_child(slate)
	_markers[Quests.ALLOTMENTS] = Npc.quest_marker_on(slate, JobSlate.MARKER_HEIGHT)
	add_child(AllotmentBeds.create(_ground, _entities))


## What each marker should say now (Quests.marker_for).
func _refresh_markers() -> void:
	for id: StringName in _markers:
		_markers[id].text = Quests.marker_for(id)


# --- Tools on the allotments (DECISIONS 062) -----------------------------------
# The hoe, the can and the sickle ask these (ToolAction.can_use_away and
# apply_away) with the work they do.

func work_wanted_at(cell: Vector2i, works: Array[StringName]) -> bool:
	return Allotments.can_work(cell, works)


func do_work(cell: Vector2i, works: Array[StringName]) -> void:
	Allotments.do_work(cell, works)


func _physics_process(_delta: float) -> void:
	# Outline the tiles the held tool would work, only where it would.
	var cells: Array[Vector2i] = []
	var tool := GameState.selected_tool()
	if tool != null and tool.action != null and not Fishing.is_busy():
		for cell in _player.target_cells():
			if tool.action.can_use_away(self, cell):
				cells.append(cell)
	_cursor.set_cells(cells)


# --- Talking: Dot and the slate (DECISIONS 062) ----------------------------------

func _on_talked_to(npc_id: StringName) -> void:
	var speaker := _speaker(npc_id)
	if speaker == "":
		return
	var lines := Quests.talk(npc_id)
	if not lines.is_empty():
		_dialogue.say(speaker, lines)
		return
	var offers := Quests.orders_on_offer(npc_id)
	if not offers.is_empty():
		_asking_for = npc_id
		_asking = offers
		var answers: Array[String] = []
		for order in offers:
			answers.append(Quests.order_choice_text(order))
		answers.append("Leave it" if npc_id == Quests.ALLOTMENTS else "Not today")
		_dialogue.ask(speaker, Quests.choice_line(npc_id), answers)
		return
	var idle: Array[String] = []
	if npc_id == Quests.ALLOTMENTS:
		idle.append("Nothing chalked on the slate that's yours to take. Try again tomorrow.")
	else:
		var person := ContentDB.character(npc_id)
		if person != null and person.line_on(GameState.day) != "":
			idle.append(person.line_on(GameState.day))
	if not idle.is_empty():
		_dialogue.say(speaker, idle)


## Who's speaking for `npc_id` here, or "" if it's nobody on the Lane.
func _speaker(npc_id: StringName) -> String:
	if npc_id == Quests.ALLOTMENTS:
		return "The allotment slate"
	var person := ContentDB.character(npc_id)
	if person != null and person.location == LANE_ID:
		return person.display_name
	return ""


## One of the orders was picked, or none (the last answer). Turning Dot down
## means she doesn't ask again today; the slate can be read again any time.
func _on_chosen(index: int) -> void:
	if _asking_for == &"":
		return
	var npc_id := _asking_for
	var offers := _asking
	_asking_for = &""
	_asking = []
	if index >= offers.size():
		if npc_id != Quests.ALLOTMENTS:
			Quests.decline(npc_id)
		_refresh_markers.call_deferred()
		return
	_dialogue.say(_speaker(npc_id), Quests.take(offers[index]))


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
