class_name PeopleHere
extends Node
##
## PeopleHere — the townsfolk on the map you're on (DECISIONS 067): who's
## here, walking between the stops of their day, and talking to them.
##
## Every outdoor map with people (the town, the Lane, the Cove) adds one.
## When the map opens it asks Schedules where everyone is and stands an Npc
## for each person here, already in place: nobody is simulated off-screen,
## so arriving shows them where the clock says they'd be. Then, every ten
## minutes, it asks again. Someone whose stop has moved walks there along
## the map's paths (AStarGrid2D); someone leaving for elsewhere walks to the
## road that leads there, or to the door of the building they're going
## into, and is gone; someone arriving comes in along the road, or out of
## the door, and walks to their spot.
##
## Which cells can be walked is found by asking the physics world, cell by
## cell, whether a pair of feet would fit (the same small box as an Npc's
## body): so trees, fences, walls, water, the tide and anything else the
## farmer bumps into are avoided with no list of them here, and a new map
## needs nothing more than adding this node.
##
## Talking (moved here from the town, the Lane and the Cove, so a person
## behaves the same wherever their day takes them): a festival's host about
## the festival; someone with a counter of their own (Tam) through a
## ShopCounter; then their requests, their orders to choose from (Dot's
## errands), or their line for the day. Knocking on a home's door (an
## ExitZone that says door_knocked) brings whoever's in to the door.
##
## Each Npc wears a "!" or "?" (Quests.marker_for, Festivals.marker_for).
##

const TILE_PX := 16

## The size of a pair of feet, for finding which cells can be walked: the
## same box as an Npc's body (Npc.create).
const FEET := Vector2(10, 6)

var _place: StringName
var _entities: Node2D
var _size: Vector2i
var _dialogue
var _counter: ShopCounter

## Everyone standing or walking here, by character id, and where each was
## last told to be.
var _npcs: Dictionary = {}  # StringName -> Npc
var _stops: Dictionary = {}  # StringName -> ScheduleStop
var _markers: Dictionary = {}  # StringName -> Label

## The walkable cells, worked out again at most once a game minute (the tide
## and the doors' hours change them).
var _grid: AStarGrid2D
var _grid_minute: int = -1

## Orders being chosen between (Dot's errands), and a festival question to
## ask after the host's lines (DECISIONS 059).
var _asking_for: StringName = &""
var _asking: Array[QuestDef] = []
var _festival_to_ask: StringName = &""
var _festival_asking: StringName = &""


## Make the people for map `place` (size `size` in cells), standing in
## `entities` (the y-sorted node), talking through `dialogue`. With `menu`,
## someone with a counter of their own can sell and buy (Tam).
static func create(place: StringName, entities: Node2D, size: Vector2i, dialogue,
		menu = null) -> PeopleHere:
	var people := PeopleHere.new()
	people.name = "People"
	people._place = place
	people._entities = entities
	people._size = size
	people._dialogue = dialogue
	if menu != null:
		people._counter = ShopCounter.new(dialogue, menu)
	return people


func _ready() -> void:
	for person in ContentDB.characters():
		var stop := Schedules.stop_now(person)
		_stops[person.id] = stop
		if stop.place == _place:
			_add_npc(person, _base_of(stop.cell))
	EventBus.time_changed.connect(func(_m: int) -> void: _update())
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _update())
	EventBus.npc_talked_to.connect(_on_talked_to)
	EventBus.door_knocked.connect(_on_door_knocked)
	_dialogue.finished.connect(_ask_festival_question)
	_dialogue.chosen.connect(_on_chosen)
	_dialogue.chosen.connect(func(_i: int) -> void: refresh_markers.call_deferred())
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed, EventBus.gold_changed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: refresh_markers())
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: refresh_markers())
	EventBus.quest_expired.connect(func(_id: StringName, _t: String) -> void: refresh_markers())
	EventBus.festival_entered.connect(func(_e: StringName, _w: String) -> void: refresh_markers())
	EventBus.festival_judged.connect(func(_e: StringName, _p: int, _w: String) -> void: refresh_markers())
	EventBus.festival_gift_given.connect(func(_e: StringName) -> void: refresh_markers())
	refresh_markers()


## The Npc for `id` if they're on this map now (standing or walking), or null.
func npc(id: StringName) -> Npc:
	return _npcs.get(id)


## Who's on this map now, by id.
func here() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _npcs:
		ids.append(id)
	return ids


## What each marker should say now: a festival's host about the festival
## first, then the Quests service.
func refresh_markers() -> void:
	for id: StringName in _markers:
		var text := Festivals.marker_for(id)
		_markers[id].text = text if text != "" else Quests.marker_for(id)


# --- Where everyone is ----------------------------------------------------------

## Every ten minutes (and when the weather turns): ask where everyone should
## be, and set off anyone whose stop has changed.
func _update() -> void:
	for person in ContentDB.characters():
		var stop := Schedules.stop_now(person)
		var was: ScheduleStop = _stops.get(person.id)
		if was != null and was.place == stop.place and (stop.place != _place or was.cell == stop.cell):
			continue
		_stops[person.id] = stop
		var from_place: StringName = was.place if was != null else &""
		_move(person, from_place, stop)
	refresh_markers()


func _move(person: CharacterDef, from_place: StringName, stop: ScheduleStop) -> void:
	var walker: Npc = _npcs.get(person.id)
	if stop.place == _place:
		if walker == null:
			# Coming in: along the road from where they were, or out of the
			# door of the building they were in.
			var entry := _gate_toward(from_place, stop.cell)
			walker = _add_npc(person, _base_of(entry))
		_walk(walker, stop.cell, false)
	elif walker != null:
		# Going: to the road that leads to their next place, or to its door.
		_walk(walker, _gate_toward(stop.place, walker.cell()), true)


## Send `walker` to `cell`; with `leave`, they're gone when they get there.
## If there's no way through (shouldn't happen), they're simply there.
func _walk(walker: Npc, cell: Vector2i, leave: bool) -> void:
	for connection in walker.arrived.get_connections():
		walker.arrived.disconnect(connection["callable"])
	if leave:
		walker.arrived.connect(_remove.bind(walker.npc_id), CONNECT_ONE_SHOT)
	var points := _path(walker.cell(), cell)
	if points.is_empty() and walker.cell() != cell:
		walker.position = _base_of(cell)
	walker.walk(points, GameState.RULES.people_walk_speed * TILE_PX)


## The cells' bottom-middles from `from` to `to` along walkable cells, not
## counting where they start; empty if there's no way or they're there.
func _path(from: Vector2i, to: Vector2i) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var grid := _walkable()
	if grid == null or from == to or not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to):
		return points
	# Where they start and end must count as open, even if someone's standing
	# there or it's a doorway's edge.
	var was_solid := [grid.is_point_solid(from), grid.is_point_solid(to)]
	grid.set_point_solid(from, false)
	grid.set_point_solid(to, false)
	var cells := grid.get_id_path(from, to)
	grid.set_point_solid(from, was_solid[0])
	grid.set_point_solid(to, was_solid[1])
	for i in range(1, cells.size()):
		points.append(_base_of(cells[i]))
	return points


## Which cells of this map (and its border, where the roads leave) a pair of
## feet fits on, asking the physics world. Built when first needed, and again
## if the clock has moved on since.
func _walkable() -> AStarGrid2D:
	if _grid != null and _grid_minute == GameState.minutes:
		return _grid
	var viewport := get_viewport()
	if viewport == null:
		return null
	var space := viewport.world_2d.direct_space_state
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(-1, -1, _size.x + 2, _size.y + 2)
	_grid.cell_size = Vector2(TILE_PX, TILE_PX)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	var box := RectangleShape2D.new()
	box.size = FEET
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var ignore: Array[RID] = []
	for body in get_tree().get_nodes_in_group(&"player"):
		if body is CollisionObject2D:
			ignore.append(body.get_rid())
	for each: Npc in _npcs.values():
		ignore.append(each.get_rid())
	query.exclude = ignore
	for y in range(-1, _size.y + 1):
		for x in range(-1, _size.x + 1):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, _base_of(cell) - Vector2(0, FEET.y / 2.0))
			if not space.intersect_shape(query, 1).is_empty():
				_grid.set_point_solid(cell, true)
	_grid_minute = GameState.minutes
	return _grid


## The cell someone goes to on leaving for `other` (or comes in at, coming
## from it): the door of a building on this map; the road that leads that
## way; for "away" (or anywhere there's no road to), the road nearest `near`.
func _gate_toward(other: StringName, near: Vector2i) -> Vector2i:
	var location := LocationManager.find(other)
	if location != null and location.outside == _place and location.exterior != null:
		return Building.door_cells(location)[0]
	var here := LocationManager.find(_place)
	var exits: Array[ExitDef] = []
	if here != null:
		for exit in here.exits:
			if exit != null and not exit.cells.is_empty():
				exits.append(exit)
	if exits.is_empty():
		return near
	var next := Schedules.next_map(_place, Schedules.map_of(other))
	for exit in exits:
		if exit.to == next:
			return exit.cells[0]
	var best: ExitDef = exits[0]
	for exit in exits:
		if Vector2(exit.cells[0]).distance_to(near) < Vector2(best.cells[0]).distance_to(near):
			best = exit
	return best.cells[0]


func _add_npc(person: CharacterDef, at: Vector2) -> Npc:
	var cell := Vector2i(floori(at.x / TILE_PX), floori((at.y - 1.0) / TILE_PX))
	var walker := Npc.create(person.id, person.sprite, cell)
	_entities.add_child(walker)
	_npcs[person.id] = walker
	_markers[person.id] = walker.add_quest_marker()
	return walker


func _remove(id: StringName) -> void:
	var walker: Npc = _npcs.get(id)
	_npcs.erase(id)
	_markers.erase(id)
	if walker != null:
		walker.queue_free()


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


# --- Talking ---------------------------------------------------------------------

func _on_talked_to(npc_id: StringName) -> void:
	if not _npcs.has(npc_id):
		return
	var person := ContentDB.character(npc_id)
	if person != null:
		_talk(person)


## Someone knocked on the door of a home on this map: whoever's in comes to
## the door. Nobody in: the door's own words.
func _on_door_knocked(location_id: StringName) -> void:
	var location := LocationManager.find(location_id)
	if location == null or location.outside != _place:
		return
	# Someone still walking home isn't in yet: they're out here on the map.
	var inside := Schedules.people_at(location_id).filter(
			func(p: CharacterDef) -> bool: return not _npcs.has(p.id))
	if inside.is_empty():
		EventBus.message_posted.emit(location.door_words if location.door_words != "" else "Nobody answers.")
		return
	var person: CharacterDef = inside[0]
	EventBus.message_posted.emit("%s comes to the door." % person.display_name)
	_talk(person)


## What `person` says: about the festival they're hosting, their counter,
## their requests, their orders, or their line for the day.
func _talk(person: CharacterDef) -> void:
	var id := person.id
	if not Quests.has_ready_for(id) and Festivals.has_something_for(id):
		var festival_lines := Festivals.talk(id)
		_festival_to_ask = id if not Festivals.question_for(id).is_empty() else &""
		_dialogue.say(person.display_name, festival_lines)
		return
	if person.counter != null and _counter != null:
		_counter.serve(person.counter, id, person.lines)
		return
	var lines := Quests.talk(id)
	if not lines.is_empty():
		_dialogue.say(person.display_name, lines)
		return
	var offers := Quests.orders_on_offer(id)
	if not offers.is_empty():
		_asking_for = id
		_asking = offers
		var answers: Array[String] = []
		for order in offers:
			answers.append(Quests.order_choice_text(order))
		answers.append("Not today")
		_dialogue.ask(person.display_name, Quests.choice_line(id), answers)
		return
	var line := person.line_on(GameState.day)
	if line != "":
		var said: Array[String] = [line]
		_dialogue.say(person.display_name, said)


## One of someone's orders was picked, or none (the last answer, and then
## they don't ask again today), or a festival question was answered.
func _on_chosen(index: int) -> void:
	if _festival_asking != &"":
		var host := _festival_asking
		_festival_asking = &""
		var host_def := ContentDB.character(host)
		_dialogue.say(host_def.display_name if host_def != null else "", Festivals.answer(host, index))
		return
	if _asking_for == &"":
		return  # someone else's question
	var id := _asking_for
	var offers := _asking
	_asking_for = &""
	_asking = []
	if index >= offers.size():
		Quests.decline(id)
		return
	var person := ContentDB.character(id)
	_dialogue.say(person.display_name if person != null else "", Quests.take(offers[index]))


## After a festival host's lines: what will you enter?
func _ask_festival_question() -> void:
	var id := _festival_to_ask
	_festival_to_ask = &""
	if id == &"":
		return
	var question := Festivals.question_for(id)
	if question.is_empty():
		return
	var person := ContentDB.character(id)
	_festival_asking = id
	var answers: Array[String] = []
	answers.assign(question["answers"])
	_dialogue.ask(person.display_name if person != null else "", question["question"], answers)
