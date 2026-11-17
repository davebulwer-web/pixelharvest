extends Node
##
## Festivals — the four set-piece days of the year (DECISIONS 059): who runs
## each, entering its contest, the judging, and the keepsake.
##
## A festival is a CalendarEvent with a `host` (the mayor, or Wren at the
## pond). The town stands the host at the festival all day and puts up its
## decorations; talking to them comes here, as talking to anyone with a
## request goes to Quests. This service decides what the host says, and
## keeps the day's entries.
##
## A contest, step by step:
##   1. The host invites you, and asks what you'll enter: the best few
##      things in your bag that the contest's rule accepts (or, for the
##      fishing contest, signs you up). The entry is taken from the bag.
##   2. At the contest's `judged_at` (as the clock passes it, or as the day
##      ends if you've gone to bed early) the judge scores everyone. The
##      rivals' scores come from dice seeded by the festival and the date,
##      so a day always turns out the same.
##   3. If you entered, your prize is handed over there and then, and the
##      HUD says how you did; the host reads out the results when you next
##      speak to them, and the night's summary lists it. It goes in the
##      festival log (GameState.festival_log, saved) for the year review.
##
## Nothing about the day itself is saved: a festival lasts one day, and the
## game saves at dawn, so there's never an entry in hand at a save. Quitting
## mid-festival loses that day, as it loses any other day's work.
##
## Rule 3 holds: a new festival, contest, rival or prize is a .tres. A new
## *kind* of contest is one ContestRule script (scripts/festivals/).
##

## Today's entries, by festival id: {"item": item id (&"" if nothing yet),
## "name": what it's called, lower case, "score": int}.
var _entries: Dictionary = {}

## Today's judged contests, by festival id: {"place": the farmer's place, 0
## if they didn't enter, "field": the entrants, best first, each
## {"who", "entry", "score", "farmer"}, "prize": the prize in words}.
var _judged: Dictionary = {}

## Festivals whose results the host has read out to the farmer today.
var _told: Dictionary = {}

## Festivals whose keepsake the farmer has been given today.
var _gifted: Dictionary = {}

## What's being offered to enter, by host id, while the question is up:
## items, or [null] for signing up.
var _offered: Dictionary = {}


func _ready() -> void:
	EventBus.time_changed.connect(func(_m: int) -> void: _judge_due(false))
	# Gone to bed before the judging: it happens as the day ends, so the
	# night's summary still has the result.
	EventBus.day_ended.connect(func(_d: int) -> void: _judge_due(true))
	EventBus.fish_caught.connect(_on_fish_caught)
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _forget_today())
	EventBus.new_game_started.connect(_forget_today)
	EventBus.game_loaded.connect(_forget_today)


# --- Questions ---------------------------------------------------------------

## Today's festivals (events with a host), in id order.
func today() -> Array[CalendarEvent]:
	var result: Array[CalendarEvent] = []
	for event in GameState.events_today():
		if event.is_festival():
			result.append(event)
	return result


## The festival `npc_id` runs today, or null. A host who isn't in the world
## yet (waiting for an unlock) runs nothing.
func hosted_by(npc_id: StringName) -> CalendarEvent:
	for event in today():
		if event.host == npc_id and Quests.is_about(npc_id):
			return event
	return null


## Where `npc_id` stands today: at their festival if they host one, else
## `usual`.
func spot_for(npc_id: StringName, usual: Vector2i) -> Vector2i:
	var event := hosted_by(npc_id)
	return event.host_cell if event != null else usual


## True if the host of a festival has something to say about it to the
## farmer: a gift to give, a contest still open, or results to read out.
## Otherwise talking to them is the usual thing (requests, their line).
func has_something_for(npc_id: StringName) -> bool:
	var event := hosted_by(npc_id)
	if event == null:
		return false
	_judge_due(false)
	if _gift_waiting(event):
		return true
	if event.contest == null:
		return false
	return not _judged.has(event.id) or not _told.has(event.id)


## "!" over a host with a gift waiting, or a contest you haven't entered
## that's still open; "?" once your result is in and not yet heard; else "".
func marker_for(npc_id: StringName) -> String:
	var event := hosted_by(npc_id)
	if event == null:
		return ""
	if _gift_waiting(event):
		return "!"
	if event.contest == null:
		return ""
	if _judged.has(event.id):
		return "?" if _judged[event.id]["place"] > 0 and not _told.has(event.id) else ""
	return "" if _entries.has(event.id) else "!"


## True if `event`'s contest can still be entered: not judged yet, and the
## clock hasn't reached the judging.
func is_open(event: CalendarEvent) -> bool:
	return event.contest != null and not _judged.has(event.id) \
			and GameState.minutes < event.contest.judged_at


## True if the farmer has entered `event`'s contest today.
func has_entered(event_id: StringName) -> bool:
	return _entries.has(event_id)


## The farmer's place in `event_id`'s contest today: 0 if not judged yet or
## not entered.
func place_in(event_id: StringName) -> int:
	return int(_judged.get(event_id, {}).get("place", 0))


## "Judging at 2 PM.", for the notice board and the morning summary, or "".
func judging_text(event: CalendarEvent) -> String:
	if event.contest == null:
		return ""
	return "Judging at %s." % Clock.format_short(event.contest.judged_at)


## The morning summary's lines about today's festivals: "Flower show today!
## … Judging at 2 PM: see Mayor Bramble to enter."
func news_today() -> Array[String]:
	var news: Array[String] = []
	for event in today():
		var text := "%s today! %s" % [event.display_name, event.description]
		var judging := judging_text(event)
		if judging != "":
			text += " " + judging
		news.append(text.strip_edges())
	return news


# --- Talking -----------------------------------------------------------------

## `npc_id`, a festival's host, was spoken to. Returns what they say. If
## there's a question to follow (what to enter), question_for() has it.
func talk(npc_id: StringName) -> Array[String]:
	_offered.erase(npc_id)
	var event := hosted_by(npc_id)
	var lines: Array[String] = []
	if event == null:
		return lines
	_judge_due(false)
	if _gift_waiting(event):
		lines.append_array(event.host_lines)
		lines.append(_give_gift(event))
		return lines
	var contest := event.contest
	if contest == null:
		lines.append_array(event.host_lines)
		return lines
	if _judged.has(event.id):
		_told[event.id] = true
		return _results(event)
	if _entries.has(event.id):
		lines.append(_waiting_line(event))
		return lines
	lines.append_array(contest.invite_lines)
	var tool := contest.rule.needs_tool() if contest.rule != null else null
	if tool != null and GameState.inventory.count(tool) == 0:
		lines.append(contest.nothing_line)
		return lines
	var options := _options(event)
	if options.is_empty():
		lines.append(contest.nothing_line)
		return lines
	_offered[npc_id] = options
	return lines


## The question to ask after talk(), if there is one: {"question": String,
## "answers": Array[String]} (the last answer is "Not yet"), or {}.
func question_for(npc_id: StringName) -> Dictionary:
	if not _offered.has(npc_id):
		return {}
	var event := hosted_by(npc_id)
	if event == null:
		return {}
	var answers: Array[String] = []
	for item: ItemDef in _offered[npc_id]:
		if item == null:
			answers.append(event.contest.sign_up_choice)
		else:
			answers.append("%s (%s)" % [item.display_name,
					event.contest.rule.score_text(_score_of(event, item))])
	answers.append("Not yet")
	return {"question": event.contest.question, "answers": answers}


## The farmer picked answer `index` to question_for(npc_id). Returns what the
## host says.
func answer(npc_id: StringName, index: int) -> Array[String]:
	var lines: Array[String] = []
	var options: Array = _offered.get(npc_id, [])
	_offered.erase(npc_id)
	var event := hosted_by(npc_id)
	if event == null or not is_open(event) or _entries.has(event.id):
		return lines
	var time := Clock.format_short(event.contest.judged_at)
	if index < 0 or index >= options.size():
		lines.append("Come back before %s if you change your mind." % time)
		return lines
	var item: ItemDef = options[index]
	if item == null:
		_entries[event.id] = {"item": &"", "name": "", "score": 0}
		EventBus.festival_entered.emit(event.id, "a place")
	else:
		if not GameState.inventory.remove(item, 1):
			return lines
		var name := item.display_name.to_lower()
		_entries[event.id] = {"item": item.id, "name": name, "score": _score_of(event, item)}
		EventBus.festival_entered.emit(event.id, name)
	lines.append(ContestDef.fill(event.contest.entered_line, {"entry": _entries[event.id]["name"], "time": time}))
	return lines


# --- The contest -------------------------------------------------------------

## What the farmer could enter in `event`'s contest: for a contest with
## something to hand over, the best three different things in the bag the
## rule accepts, best first; for one you sign up to, [null].
func _options(event: CalendarEvent) -> Array:
	var rule := event.contest.rule
	if rule == null:
		return []
	if not rule.takes_entry():
		return [null]
	var candidates: Array[ItemDef] = []
	for item in GameState.inventory.items():
		if item != null and GameState.inventory.count(item) > 0 \
				and rule.can_enter(item, ContentDB.crop_giving(item) != null):
			candidates.append(item)
	candidates.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		var sa := _score_of(event, a)
		var sb := _score_of(event, b)
		return sa > sb if sa != sb else String(a.id) < String(b.id))
	return candidates.slice(0, 3)


func _score_of(event: CalendarEvent, item: ItemDef) -> int:
	return event.contest.rule.score_of(item, _bonus_count(event.contest.rule))


## How many of a BestItemRule's bonus objects stand on the farm.
func _bonus_count(rule: ContestRule) -> int:
	if not (rule is BestItemRule) or rule.bonus_object == &"" or GameState.farm == null:
		return 0
	var count := 0
	for cell: Vector2i in GameState.farm.cells():
		if GameState.farm.tile(cell).object_id == rule.bonus_object:
			count += 1
	return count


## A fish landed: the fishing contest keeps the biggest that counts, until
## the judging.
func _on_fish_caught(fish_id: StringName, size: int, location_id: StringName, water: StringName,
		through_ice: bool) -> void:
	for event in today():
		if not _entries.has(event.id) or not is_open(event) or event.contest.rule == null:
			continue
		var score := event.contest.rule.score_event(&"fish_caught", [fish_id, size, location_id, water, through_ice])
		if score > int(_entries[event.id]["score"]):
			var fish := ContentDB.item(fish_id)
			_entries[event.id] = {"item": fish_id, "score": score,
					"name": fish.display_name.to_lower() if fish != null else String(fish_id)}


## Judge every contest today whose time has come (or, with `day_over`, every
## one not judged yet).
func _judge_due(day_over: bool) -> void:
	for event in today():
		if event.contest == null or _judged.has(event.id):
			continue
		if day_over or GameState.minutes >= event.contest.judged_at:
			_judge(event)


func _judge(event: CalendarEvent) -> void:
	var contest := event.contest
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("%s/%d" % [event.id, GameState.day_number()])
	var field: Array[Dictionary] = []
	for rival in contest.rivals:
		if rival != null:
			field.append({"who": rival.name, "entry": rival.entry, "farmer": false,
					"score": dice.randi_range(rival.min_score, maxi(rival.min_score, rival.max_score))})
	var place := 0
	var entry: Dictionary = _entries.get(event.id, {})
	if not entry.is_empty() and int(entry["score"]) > 0:
		var score := int(entry["score"])
		place = 1 + field.filter(func(f: Dictionary) -> bool: return f["score"] > score).size()
		field.append({"who": "you", "entry": entry["name"], "score": score, "farmer": true})
	# Best first; on a tie the farmer goes first, as the judge decided.
	field.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["farmer"] and not b["farmer"])
	var prize := contest.prize_for(place)
	var prize_text := prize.text() if prize != null else ""
	_judged[event.id] = {"place": place, "field": field, "prize": prize_text}
	if entry.is_empty():
		return
	if place == 0:
		# Signed up, and nothing landed that counted.
		GameState.record_festival(event.id, 0)
		EventBus.message_posted.emit("%s: judged. You had nothing to show this time." % event.display_name)
		EventBus.festival_judged.emit(event.id, 0, "")
		return
	if prize != null:
		GameState.add_gold(prize.gold)
		for item: ItemDef in prize.items:
			GameState.inventory.add(item, prize.items[item])
	GameState.record_festival(event.id, place, StringName(entry["item"]), int(entry["score"]))
	var text := "%s: you came %s%s" % [event.display_name, ContestDef.place_text(place), "!" if prize != null else "."]
	if prize_text != "":
		text += " You won %s." % prize_text
	EventBus.message_posted.emit(text)
	EventBus.festival_judged.emit(event.id, place, prize_text)


## What the host says once the judging's done: the top three, read from
## third up, and where the farmer came if lower.
func _results(event: CalendarEvent) -> Array[String]:
	var lines: Array[String] = [event.contest.results_line]
	var result: Dictionary = _judged[event.id]
	var field: Array = result["field"]
	var rule := event.contest.rule
	var podium: Array[String] = []
	for i in range(mini(3, field.size()) - 1, -1, -1):
		podium.append("%s: %s." % [ContestDef.place_text(i + 1), _entrant_text(field[i], rule)])
	lines.append(" ".join(podium))
	var place: int = result["place"]
	if place > 3:
		lines.append("And you came %s, with %s. Better luck next year!"
				% [ContestDef.place_text(place), _entrant_text(field[place - 1], rule)])
	if place > 0 and result["prize"] != "":
		lines.append("Your prize, %s, is yours already. Well done!" % result["prize"])
	elif _entries.has(event.id) and place == 0:
		lines.append("Nothing to show this time. There's always next year.")
	return lines


## "Mrs Pell's sweet pea (58 points)", "your tench (34 cm)".
func _entrant_text(entrant: Dictionary, rule: ContestRule) -> String:
	var who: String = "your"
	if not entrant["farmer"]:
		var name: String = entrant["who"]
		who = name + ("'" if name.ends_with("s") else "'s")
	var score := rule.score_text(int(entrant["score"])) if rule != null else str(entrant["score"])
	return "%s %s (%s)" % [who, entrant["entry"], score]


func _waiting_line(event: CalendarEvent) -> String:
	var entry: Dictionary = _entries[event.id]
	var rule := event.contest.rule
	var name: String = entry["name"]
	var words := {"entry": name if name != "" else "nothing yet",
			"score": rule.score_text(int(entry["score"])) if rule != null else "",
			"time": Clock.format_short(event.contest.judged_at)}
	return ContestDef.fill(event.contest.waiting_line, words)


# --- The keepsake ------------------------------------------------------------

func _gift_waiting(event: CalendarEvent) -> bool:
	return not event.gift_items.is_empty() and not _gifted.has(event.id)


## Hand over `event`'s keepsake. Returns the host's line, with what was given.
func _give_gift(event: CalendarEvent) -> String:
	_gifted[event.id] = true
	var given: Array[String] = []
	for item: ItemDef in event.gift_items:
		var count: int = event.gift_items[item]
		GameState.inventory.add(item, count)
		var word := item.display_name.to_lower()
		given.append("%d %s" % [count, QuestGoal.plural(item.display_name, count)] if count != 1
				else ("an " if "aeiou".contains(word.left(1)) else "a ") + word)
	GameState.record_festival(event.id, 0)
	EventBus.festival_gift_given.emit(event.id)
	return "%s (You got %s.)" % [event.gift_line, " and ".join(given)]


## A new day, or a different game: nothing from the last one carries over.
func _forget_today() -> void:
	_entries.clear()
	_judged.clear()
	_told.clear()
	_gifted.clear()
	_offered.clear()
