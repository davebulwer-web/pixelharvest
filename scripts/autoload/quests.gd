extends Node
##
## Quests — the townsfolk's requests: who has one to offer, what happens when
## you talk to them about it, and keeping count as you play (DECISIONS 038).
##
## Stage 8 called this "the architecture's exam": quests had to arrive without
## the farming code changing. They do. Progress comes entirely from EventBus —
## this file listens to signals the farm, the bin and the shops already
## announced (crop_harvested, items_shipped, items_sold_to_shop, item_bought)
## and offers each one to every active request's goal (QuestGoal.counts).
## Nothing that grows, ships or sells knows a request exists.
##
## What's saved lives in GameState.quests (a QuestLog). The requests
## themselves are data (QuestDef, data/quests/), so a new request is a file.
##
## Talking: the town asks talk(npc_id) when someone is spoken to. If they have
## a request to make, to remind you of, or to take in, the lines come back and
## the town says them; otherwise it's an empty list and they say their usual
## line for the day. A question asked directly, like ContentDB's, because the
## town has to know the answer before it decides what to say.
##
## Announces quest_started, quest_progressed and quest_completed, so the HUD,
## the request log and the town's markers keep up without asking.
##

## Requests already announced as ready to hand in, so the message comes once.
## Not saved: after loading, the "?" over the giver's head says it.
var _told_ready: Dictionary = {}  # StringName -> true


func _ready() -> void:
	# Every signal a goal might count. A new kind of goal that needs another
	# signal adds one line here, and nothing else changes. Deferred, so the
	# HUD has said "Harvested 1 Strawberry" before a request's progress is
	# counted and shown over it.
	EventBus.crop_harvested.connect(func(cell: Vector2i, crop_id: StringName, amount: int) -> void:
		_record(&"crop_harvested", [cell, crop_id, amount]), CONNECT_DEFERRED)
	EventBus.items_shipped.connect(func(count: int, value: int) -> void:
		_record(&"items_shipped", [count, value]), CONNECT_DEFERRED)
	EventBus.items_sold_to_shop.connect(func(item_id: StringName, amount: int, gold: int) -> void:
		_record(&"items_sold_to_shop", [item_id, amount, gold]), CONNECT_DEFERRED)
	EventBus.item_bought.connect(func(item_id: StringName, amount: int, cost: int) -> void:
		_record(&"item_bought", [item_id, amount, cost]), CONNECT_DEFERRED)
	# Deliveries count what's in the bag, so any change to the bag may finish one.
	EventBus.item_added.connect(func(_id: StringName, _n: int) -> void: _check_ready(), CONNECT_DEFERRED)
	EventBus.game_loaded.connect(func() -> void: _told_ready.clear())


# --- Questions ---------------------------------------------------------------

## The requests in hand, in the order they were taken.
func active() -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for id in GameState.quests.active_ids():
		var quest := ContentDB.quest(id)
		if quest != null:
			result.append(quest)
	return result


## How far along `quest` is, capped at what it needs.
func progress(quest: QuestDef) -> int:
	if quest.goal == null:
		return 0
	return mini(quest.goal.progress(GameState.quests.recorded(quest.id), GameState.inventory), quest.goal.amount)


## True if `quest` is taken and has everything it needs.
func is_ready(quest: QuestDef) -> bool:
	return GameState.quests.is_active(quest.id) and quest.goal != null \
			and progress(quest) >= quest.goal.amount


## The request `npc_id` has given you that's still open, or null.
func active_for(npc_id: StringName) -> QuestDef:
	for quest in active():
		if quest.giver == npc_id:
			return quest
	return null


## The request `npc_id` would ask today if spoken to, or null. One at a time:
## nobody asks a second thing while the first is still open.
func offer_for(npc_id: StringName) -> QuestDef:
	if active_for(npc_id) != null:
		return null
	for quest in ContentDB.quests():
		if quest.giver == npc_id and is_offered_today(quest):
			return quest
	return null


## True if `quest` hasn't been taken and today it can be offered.
func is_offered_today(quest: QuestDef) -> bool:
	if GameState.quests.state(quest.id) != &"":
		return false
	if quest.requires != null and not GameState.quests.is_done(quest.requires.id):
		return false
	if GameState.day_number() < quest.first_day:
		return false
	if not quest.seasons.is_empty() and GameState.season_id() not in quest.seasons:
		return false
	if quest.on_event != &"" and not GameState.events_today().any(
			func(e: CalendarEvent) -> bool: return e.id == quest.on_event):
		return false
	return true


## What to show over `npc_id`'s head: "?" if they're waiting to be handed
## something you now have, "!" if they've something to ask, else "".
func marker_for(npc_id: StringName) -> String:
	var quest := active_for(npc_id)
	if quest != null:
		return "?" if is_ready(quest) else ""
	return "!" if offer_for(npc_id) != null else ""


## Everyone with something to ask today, by CharacterDef id.
func givers_with_offers() -> Array[StringName]:
	var ids: Array[StringName] = []
	for quest in ContentDB.quests():
		if quest.giver not in ids and offer_for(quest.giver) == quest:
			ids.append(quest.giver)
	return ids


# --- Talking -----------------------------------------------------------------

## `npc_id` was spoken to. Returns what they say about requests (taking one
## in, reminding you, or asking a new one), or an empty list if they've
## nothing to say about requests today.
func talk(npc_id: StringName) -> Array[String]:
	var quest := active_for(npc_id)
	if quest != null:
		if is_ready(quest):
			return _complete(quest)
		var reminder := quest.reminder_line if quest.reminder_line != "" else "%s?" % quest.goal.describe()
		var lines: Array[String] = ["%s (%s)" % [reminder, quest.goal.progress_text(progress(quest))]]
		return lines
	quest = offer_for(npc_id)
	if quest != null:
		return _start(quest)
	return []


func _start(quest: QuestDef) -> Array[String]:
	GameState.quests.start(quest.id)
	EventBus.quest_started.emit(quest.id)
	var lines: Array[String] = quest.offer_lines.duplicate()
	var giver := ContentDB.character(quest.giver)
	var text := "New request: %s. %s" % [quest.title, quest.goal.describe()]
	if giver != null and quest.goal is DeliverGoal:
		text += " to %s" % giver.display_name
	text += "."
	var reward := quest.reward_text()
	if reward != "":
		text += " Reward: %s." % reward
	lines.append(text + " (J shows your requests.)")
	# A delivery can be ready the moment it's taken, if the bag already has it.
	_check_ready()
	return lines


func _complete(quest: QuestDef) -> Array[String]:
	quest.goal.hand_in(GameState.inventory)
	GameState.quests.finish(quest.id)
	_told_ready.erase(quest.id)
	GameState.add_gold(quest.reward_gold)
	for item: ItemDef in quest.reward_items:
		GameState.inventory.add(item, quest.reward_items[item])
	EventBus.quest_completed.emit(quest.id)
	var lines: Array[String] = quest.thanks_lines.duplicate()
	var reward := quest.reward_text()
	lines.append("Request done: %s.%s" % [quest.title, " You got %s." % reward if reward != "" else ""])
	return lines


# --- Keeping count -----------------------------------------------------------

## Something happened (`event`, with its signal's `args`): add whatever it's
## worth to every request in hand.
func _record(event: StringName, args: Array) -> void:
	for quest in active():
		if quest.goal == null:
			continue
		var amount := quest.goal.counts(event, args)
		if amount <= 0:
			continue
		GameState.quests.add(quest.id, amount)
		EventBus.quest_progressed.emit(quest.id, progress(quest), quest.goal.amount)
	_check_ready()


## Tell the player, once, when a request has everything it needs.
func _check_ready() -> void:
	for quest in active():
		if _told_ready.has(quest.id) or not is_ready(quest):
			continue
		_told_ready[quest.id] = true
		var giver := ContentDB.character(quest.giver)
		EventBus.message_posted.emit("%s: done! Go and see %s" % [quest.title,
				giver.display_name if giver != null else "whoever asked"])
