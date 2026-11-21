extends Node
##
## Quests — the townsfolk's requests: who has one to offer, what happens when
## you talk to them about it, and keeping count as you play (DECISIONS 038).
##
## Stage 8 called this "the architecture's exam": quests had to arrive without
## the farming code changing. They do. Progress comes entirely from EventBus —
## this file listens to signals the farm, the bin and the shops already
## announced (crop_harvested, items_shipped, items_sold_to_shop, item_bought,
## giant_harvested, fish_caught) and offers each one to every active request's goal (QuestGoal.counts).
## Nothing that grows, ships or sells knows a request exists.
##
## What's saved lives in GameState.quests (a QuestLog). The requests
## themselves are data (QuestDef, data/quests/), so a new request is a file.
##
## Givers (DECISIONS 044): a request's giver is a townsperson (CharacterDef
## id) or a shopkeeper (their ShopDef id: &"blacksmith" is Brann). Either way
## they only ask while they're about: a townsperson waiting for an unlock
## isn't in town yet, and a shopkeeper whose shop is still shut isn't either.
##
## Talking: the town (or a shop counter) asks talk(npc_id) when someone is spoken to. If they have
## a request to make, to remind you of, or to take in, the lines come back and
## the town says them; otherwise it's an empty list and they say their usual
## line for the day. A question asked directly, like ContentDB's, because the
## town has to know the answer before it decides what to say.
##
## Announces quest_started, quest_progressed and quest_completed, so the HUD,
## the request log and the town's markers keep up without asking.
##
## Deadlines and orders (DECISIONS 050): a request with deadline_days is due
## by a day, and if it's still in hand when that day ends it runs out
## (quest_expired) — no penalty, only the reward missed. Orders are requests
## made fresh each day from an OrderTemplate (data/orders/): Rosa's at her
## market stall, three to choose from, due by the next market day; and one
## small job a day on the notice board, due that night, handed in at the
## board. They're built here as ordinary QuestDefs, so from then on they're
## treated like any other request. What's on offer on a given day is the
## same however often you ask (the dice are seeded by the date), so walking
## away and back, or loading the morning's save, changes nothing.
##
## Handed to someone else, by a time (DECISIONS 062): a request can be handed
## in to someone other than its giver (QuestDef.hand_in_to: Dot's parcels go
## to whoever they're addressed to) and be due by a time of day
## (QuestDef.due_minute), when it runs out there and then. Dot's errands
## (ErrandTemplate) and the allotments' odd jobs (JobTemplate) are orders
## too. A job is paid on the spot, the moment its last tile of work is done
## (QuestGoal.finishes_itself), with nobody to go back to. Who a request is
## handed in to is its receiver; who it came from is still its giver, who
## asks nothing else while it's open.
##

## Where the notice board's jobs are posted and handed in: it stands in for
## a giver's id.
const BOARD := &"notice_board"

## Where the allotments' odd jobs are pinned up and paid from: the shed on
## the Lane (DECISIONS 062). Like the board, it stands in for a giver's id.
const ALLOTMENTS := &"allotments"

## Requests already announced as ready to hand in, so the message comes once.
## Not saved: after loading, the "?" over the giver's head says it.
var _told_ready: Dictionary = {}  # StringName -> true

## Orders built so far, by id: today's offers and those in hand. Built again
## from the log's "order" entry after loading. Cleared each morning.
var _orders: Dictionary = {}  # StringName -> QuestDef

## What each built order was made of, by id: the entry the log keeps.
var _order_params: Dictionary = {}  # StringName -> Dictionary

## Places whose orders the player turned down today (place -> day number), so
## Rosa doesn't ask again every time you want to sell her something.
var _declined: Dictionary = {}


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
	EventBus.giant_harvested.connect(func(cell: Vector2i, crop_id: StringName) -> void:
		_record(&"giant_harvested", [cell, crop_id]), CONNECT_DEFERRED)
	EventBus.fish_caught.connect(func(fish_id: StringName, size: int, location_id: StringName, water: StringName, through_ice: bool) -> void:
		_record(&"fish_caught", [fish_id, size, location_id, water, through_ice]), CONNECT_DEFERRED)
	EventBus.allotment_worked.connect(func(plot: int, work: StringName, cell: Vector2i) -> void:
		_record(&"allotment_worked", [plot, work, cell]), CONNECT_DEFERRED)
	EventBus.almanac_entry_added.connect(func(page: StringName, entry_id: StringName) -> void:
		_record(&"almanac_entry_added", [page, entry_id]), CONNECT_DEFERRED)
	# Deliveries count what's in the bag, and gifts of gold the purse, so any
	# change to either may finish one.
	EventBus.item_added.connect(func(_id: StringName, _n: int) -> void: _check_ready(), CONNECT_DEFERRED)
	EventBus.gold_changed.connect(func(_g: int, _d: int) -> void: _check_ready(), CONNECT_DEFERRED)
	EventBus.game_loaded.connect(_forget_today)
	EventBus.new_game_started.connect(_forget_today)
	# Step 1 of the night: whatever was due today and wasn't handed in runs
	# out, before the summary's record closes. In the morning, orders that
	# are finished with are cleared away, before the morning's save.
	EventBus.day_ended.connect(func(_d: int) -> void: _expire_overdue())
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _start_of_day())
	# A request due by a time of day runs out as the clock passes it
	# (DECISIONS 062), not only overnight.
	EventBus.time_changed.connect(func(_m: int) -> void: _expire_late())


# --- Questions ---------------------------------------------------------------

## The requests in hand, in the order they were taken.
func active() -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for id in GameState.quests.active_ids():
		var quest := find(id)
		if quest != null:
			result.append(quest)
	return result


## The request with this id: a written one (data/quests/) or an order, built
## again from the log if need be. Null if there's no such request.
func find(id: StringName) -> QuestDef:
	var quest := ContentDB.quest(id)
	if quest != null:
		return quest
	if _orders.has(id):
		return _orders[id]
	var params := GameState.quests.order_of(id)
	if params.is_empty():
		return null
	var template := ContentDB.order_template(StringName(params.get("template", "")))
	var item := ContentDB.item(StringName(params.get("item", "")))
	# A job asks for work, not an item (DECISIONS 062); everything else needs one.
	if template == null or (item == null and not template is JobTemplate):
		return null
	return _build_order(id, template, item, params)


## How far along `quest` is, capped at what it needs.
func progress(quest: QuestDef) -> int:
	if quest.goal == null:
		return 0
	return mini(quest.goal.progress(GameState.quests.recorded(quest.id), GameState.inventory, GameState.gold),
			quest.goal.needed())


## True if `quest` is taken and has everything it needs: the items, and any
## gold that goes with them (a CommissionGoal's fee, DECISIONS 053; a gift of
## gold already counts the purse as its progress).
func is_ready(quest: QuestDef) -> bool:
	return GameState.quests.is_active(quest.id) and quest.goal != null \
			and progress(quest) >= quest.goal.needed() \
			and GameState.gold >= quest.goal.gold_to_hand_in()


## The request `npc_id` has given you that's still open, or null.
func active_for(npc_id: StringName) -> QuestDef:
	for quest in active():
		if quest.giver == npc_id:
			return quest
	return null


## A request in hand that's ready to be handed in to `npc_id` (its receiver:
## the giver, or whoever a parcel is addressed to), or null.
func ready_for(npc_id: StringName) -> QuestDef:
	for quest in active():
		if quest.receiver() == npc_id and not quest.goal.finishes_itself() and is_ready(quest):
			return quest
	return null


## True if talking to `npc_id` now would hand something in.
func has_ready_for(npc_id: StringName) -> bool:
	return ready_for(npc_id) != null


## The face `npc_id` wears for what talk() would say now (the dialogue box's
## portrait moods, DECISIONS 074): happy when something's handed in, worried
## when a request of theirs is due today or later than that; otherwise
## neutral. Worked out before talk(), which changes what it looks at.
func mood_for(npc_id: StringName) -> StringName:
	if has_ready_for(npc_id):
		return &"happy"
	var quest := active_for(npc_id)
	if quest != null:
		var due: int = GameState.quests.due_day(quest.id)
		if due > 0 and due <= GameState.day_number():
			return &"worried"
	return &"neutral"


## The request `npc_id` would ask today if spoken to, or null. One at a time:
## nobody asks a second thing while the first is still open, and nobody asks
## anything before they've arrived.
func offer_for(npc_id: StringName) -> QuestDef:
	if active_for(npc_id) != null or not is_about(npc_id):
		return null
	for quest in ContentDB.quests():
		if quest.giver == npc_id and is_offered_today(quest):
			return quest
	return null


## True if giver `npc_id` is in the world: a townsperson whose unlock (if
## they wait for one) is earned, or a shopkeeper whose shop's door is open
## to the player (Brann, once the forge reopens). A market stall's keeper
## counts as about; their requests say which day with `on_event`.
func is_about(npc_id: StringName) -> bool:
	var person := ContentDB.character(npc_id)
	if person != null:
		return GameState.has_unlock(person.requires_unlock)
	for location in LocationManager.all():
		if location.shop != null and location.shop.id == npc_id:
			return GameState.has_unlock(location.requires_unlock)
	return true


## What to call giver `npc_id`: "Mabel", or a shopkeeper's name, "Brann".
func giver_name(npc_id: StringName) -> String:
	if npc_id == BOARD:
		return "the notice board"
	if npc_id == ALLOTMENTS:
		return "the allotment shed"
	var person := ContentDB.character(npc_id)
	if person != null:
		return person.display_name
	var shop := ContentDB.shop(npc_id)
	if shop != null:
		return shop.keeper_name
	return String(npc_id)


## True if `quest` hasn't been taken and today it can be offered.
func is_offered_today(quest: QuestDef) -> bool:
	if GameState.quests.state(quest.id) != &"":
		return false
	if quest.requires != null and not GameState.quests.is_done(quest.requires.id):
		return false
	if not GameState.has_unlock(quest.requires_unlock):
		return false
	return _date_allows(quest, GameState.day_number())


## True if the calendar lets `quest` be asked on day `number`
## (GameState.day_number): on or after its first day, in one of its seasons,
## on its event's day. Only the date: whether it's been taken is asked above.
func _date_allows(quest: QuestDef, number: int) -> bool:
	if number < quest.first_day:
		return false
	var season_id := GameState.season_id_on(number)
	if not quest.seasons.is_empty() and season_id not in quest.seasons:
		return false
	if quest.on_event != &"" and not GameState.events_on(number).any(
			func(e: CalendarEvent) -> bool: return e.id == quest.on_event):
		return false
	return true


## Everyone who has something new to ask today, by CharacterDef id: a request
## on offer today that the calendar didn't allow yesterday (Mabel arriving on
## day 5, Pip on a market day). The day's summary says who (DECISIONS 043).
## A request that opened because another was finished isn't counted: its
## giver has only just said thanks, and the "!" over them says the rest.
func givers_new_today() -> Array[StringName]:
	var ids: Array[StringName] = []
	var yesterday := GameState.day_number() - 1
	for giver in givers_with_offers():
		var quest := offer_for(giver)
		if quest != null and (yesterday < 1 or not _date_allows(quest, yesterday)):
			ids.append(giver)
	return ids


## What to show over `npc_id`'s head: "?" if they're waiting to be handed
## something you now have, "!" if they've something to ask (a request, or
## orders to choose from), else "".
func marker_for(npc_id: StringName) -> String:
	if has_ready_for(npc_id):
		return "?"
	if active_for(npc_id) != null:
		return ""
	if offer_for(npc_id) != null or not orders_on_offer(npc_id).is_empty():
		return "!"
	return ""


## "today", "tomorrow", "in 5 days (summer day 10)": when `quest`'s time runs
## out, or "" if it has no deadline or isn't in hand. With a time of day
## (DECISIONS 062): "today by 2 PM".
func due_text(quest: QuestDef) -> String:
	var due := GameState.quests.due_day(quest.id)
	if due <= 0:
		return ""
	var ahead := due - GameState.day_number()
	var at := " by %s" % Clock.format_short(quest.due_minute) if quest.due_minute > 0 else ""
	if ahead <= 0:
		return "today" + at
	if ahead == 1:
		return "tomorrow" + at
	var length := GameState.RULES.days_per_season
	return "in %d days (%s day %d)" % [ahead, GameState.season_name(GameState.season_id_on(due)).to_lower(),
			posmod(due - 1, length) + 1]


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
	# Something for them, from them or (a parcel) from someone else.
	var ready := ready_for(npc_id)
	if ready != null:
		return _complete(ready)
	var quest := active_for(npc_id)
	if quest != null:
		var reminder := quest.reminder_line if quest.reminder_line != "" else "%s?" % quest.goal.describe()
		var line := reminder
		# A parcel for someone else is in the bag from the start: "1 / 1"
		# would only confuse. Anything else says how far it's got.
		if quest.receiver() == quest.giver:
			line += " (%s)" % quest.goal.progress_text(progress(quest))
		var missing := quest.goal.still_needed(GameState.inventory)
		if missing != "":
			line += " Still to find: %s." % missing
		var due := due_text(quest)
		if due != "":
			line += " Due %s." % due
		var lines: Array[String] = [line]
		return lines
	quest = offer_for(npc_id)
	if quest != null:
		return _start(quest)
	return []


func _start(quest: QuestDef) -> Array[String]:
	var due := GameState.day_number() + quest.deadline_days - 1 if quest.deadline_days > 0 else 0
	GameState.quests.start(quest.id, due, _order_params.get(quest.id, {}))
	# Dot's parcel goes in the bag as the errand is taken (DECISIONS 062).
	quest.goal.on_taken(GameState.inventory)
	EventBus.quest_started.emit(quest.id)
	var lines: Array[String] = quest.offer_lines.duplicate()
	var text := "New request: %s. %s" % [quest.title, quest.goal.describe()]
	# "Bring 5 parsnips to Mabel", "Deliver the parcel to Hollis". A gift
	# of gold already says what it's for.
	if quest.goal.is_handed_over() and quest.goal.gold_to_hand_in() == 0:
		text += " to %s" % giver_name(quest.receiver())
	if due > 0:
		var tonight := due == GameState.day_number() and quest.due_minute == 0
		text += ", %s" % ("by tonight" if tonight else "due " + due_text(quest))
	text += "."
	var reward := quest.reward_text()
	if reward != "":
		text += " Reward: %s." % reward
	lines.append(text + " (J shows your requests.)")
	# A delivery can be ready the moment it's taken, if the bag already has it.
	_check_ready()
	return lines


func _complete(quest: QuestDef) -> Array[String]:
	# A gift of gold (DonateGoal) is taken here: the goal can't touch the
	# purse itself. is_ready() has already checked there's enough.
	var gift := quest.goal.gold_to_hand_in()
	if gift > 0 and not GameState.try_spend_gold(gift):
		var short: Array[String] = ["%s? (%s)" % [quest.goal.describe(), quest.goal.progress_text(progress(quest))]]
		return short
	quest.goal.hand_in(GameState.inventory)
	GameState.quests.finish(quest.id)
	_told_ready.erase(quest.id)
	GameState.add_gold(quest.reward_gold)
	for item: ItemDef in quest.reward_items:
		GameState.inventory.add(item, quest.reward_items[item])
	for upgrade in quest.reward_upgrades:
		if upgrade != null:
			GameState.add_upgrade(upgrade)
	# After quest_completed, so the day's summary lists the request before
	# what it opened.
	EventBus.quest_completed.emit(quest.id)
	for unlock_def in quest.reward_unlocks:
		GameState.unlock(unlock_def)
	for recipe in quest.reward_recipes:
		GameState.learn_recipe(recipe)
	var lines: Array[String] = quest.thanks_lines.duplicate()
	var reward := quest.reward_text()
	lines.append("Request done: %s.%s" % [quest.title, " You got %s." % reward if reward != "" else ""])
	return lines


# --- Orders (DECISIONS 050) ---------------------------------------------------

## The orders `place` (Rosa's shop id, BOARD, Dot, or ALLOTMENTS) has up
## today for the player to choose from, or none: none while the player has a
## request from there in hand or a written one to be asked first, or after
## turning them down today. The same every time it's asked today, except that
## one due by a time that has passed isn't offered any more (DECISIONS 062).
func orders_on_offer(place: StringName) -> Array[QuestDef]:
	var offers: Array[QuestDef] = []
	var today := GameState.day_number()
	if active_for(place) != null or _declined.get(place, -1) == today:
		return offers
	if place != BOARD and place != ALLOTMENTS and (not is_about(place) or offer_for(place) != null):
		return offers
	var slot := 0
	for template in _templates_today(place, today):
		offers.append_array(_orders_from(template, today, slot))
		slot += 1
	return offers


## Today's orders from one pattern: none if one of them was taken today
## (taking one takes the others off the table), else `choices` of them, each
## for something different. `slot` is the pattern's place among those up at
## its place today, so the allotment shed's jobs fall on different beds.
func _orders_from(template: OrderTemplate, today: int, slot: int) -> Array[QuestDef]:
	var orders: Array[QuestDef] = []
	for n in maxi(template.choices, 1):
		if GameState.quests.state(_order_id(template, today, n)) != &"":
			return orders
	var picks: Array[Dictionary] = []
	var dice := _dice(template.id, today, 1)
	if template is ErrandTemplate:
		picks = _pick_errands(template as ErrandTemplate, dice)
	elif template is JobTemplate:
		picks = _pick_job(template as JobTemplate, today, slot)
	else:
		picks = _pick_deliveries(template, dice)
	for n in picks.size():
		var params: Dictionary = picks[n]
		params["template"] = String(template.id)
		params["day"] = today
		# Too late to do today: not on offer (the rest keep their ids).
		if int(params.get("due_at", 0)) > 0 and GameState.minutes >= int(params["due_at"]):
			continue
		var item := ContentDB.item(StringName(params.get("item", "")))
		orders.append(_build_order(_order_id(template, today, n), template, item, params))
	return orders


func _order_id(template: OrderTemplate, today: int, n: int) -> StringName:
	return StringName("%s@%d#%d" % [template.id, today, n + 1])


## An ordinary order's picks (DECISIONS 050): `choices` different items in
## season, how many of each, and the pay.
func _pick_deliveries(template: OrderTemplate, dice: RandomNumberGenerator) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	var pool := _in_season(template)
	_shuffle(pool, dice)
	for n in mini(template.choices, pool.size()):
		var item: ItemDef = pool[n]
		var count := dice.randi_range(template.count_min, template.count_max)
		var price := Economy.sell_price(item)
		if template.max_value > 0 and price > 0:
			count = clampi(mini(count, floori(template.max_value / float(price))), 1, count)
		var gold := ceili(price * count * template.pay_rate) + template.bonus_gold
		picks.append({"item": String(item.id), "count": count, "gold": gold})
	return picks


## Dot's errands (DECISIONS 062): `choices` parcels, each to a different
## person who is about today, by a time of day; a shopkeeper only by a time
## after their shop opens (they can't take it in before), someone with a
## schedule only by a time they can be found all the hour before (DECISIONS
## 067: not the mayor at 6 PM on a Sunday, when he's gone home at 4), and
## never Dot herself.
func _pick_errands(template: ErrandTemplate, dice: RandomNumberGenerator) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	var people: Array[StringName] = []
	for person in template.deliver_to:
		if person != template.posted_at and is_about(person):
			people.append(person)
	_shuffle(people, dice)
	var times := template.due_times.duplicate()
	times.sort()
	for person in people:
		if picks.size() >= template.choices or template.items.is_empty() or times.is_empty():
			break
		var due: int = times[dice.randi_range(0, times.size() - 1)]
		var shop := ContentDB.shop(person)
		if shop != null:
			# The earliest time from the list that leaves an hour of opening.
			var possible := times.filter(func(t: int) -> bool:
				return t >= shop.opens_at + 60 and t <= shop.closes_at)
			if possible.is_empty():
				continue
			if due not in possible:
				due = possible[0]
		var character := ContentDB.character(person)
		if character != null and character.schedule != null:
			var findable := times.filter(func(t: int) -> bool:
				return Schedules.findable_before(character, t))
			if findable.is_empty():
				continue
			if due not in findable:
				due = findable[dice.randi_range(0, findable.size() - 1)]
		var item: ItemDef = template.items[dice.randi_range(0, template.items.size() - 1)]
		var gold := DifficultyDef.scale_price(dice.randi_range(template.pay_min, template.pay_max),
				GameState.difficulty.sell_price_multiplier)
		picks.append({"item": String(item.id), "count": 1, "gold": gold, "to": String(person),
				"due_at": due})
	return picks


## An allotment job (DECISIONS 062): which bed (different for each pattern
## up today, by `slot`), how much work and the pay. Watering and digging
## are the whole bed; weeding a few weeds.
func _pick_job(template: JobTemplate, today: int, slot: int) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	var beds := Allotments.bed_count()
	if beds <= 0:
		return picks
	var plots: Array = range(1, beds + 1)
	_shuffle(plots, _dice(template.posted_at, today, 2))
	var plot: int = plots[slot % beds]
	var room := Allotments.bed_size(plot)
	var count := room
	if template.work == &"weed":
		count = clampi(_dice(template.id, today, 3).randi_range(template.cells_min, template.cells_max), 1, room)
	var gold := DifficultyDef.scale_price(count * template.pay_per_cell + template.bonus_gold,
			GameState.difficulty.sell_price_multiplier)
	picks.append({"item": "", "count": count, "gold": gold, "plot": plot, "due_at": template.due_time})
	return picks


## Shuffle `list` in place with `dice` (the day's, so always the same way).
func _shuffle(list: Array, dice: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap


## Take `order` (one of orders_on_offer): it goes in the log like any request.
## Returns what's said.
func take(order: QuestDef) -> Array[String]:
	if GameState.quests.state(order.id) != &"":
		return []
	return _start(order)


## The player turned down `place`'s orders: don't offer them again today.
func decline(place: StringName) -> void:
	_declined[place] = GameState.day_number()


## What `place`'s patterns today say before their choices, or "".
func choice_line(place: StringName) -> String:
	for template in _templates_today(place, GameState.day_number()):
		if template.choice_line != "":
			return template.choice_line
	return ""


## "8 tomatoes, 420g": an order in a few words, for choosing between them.
## A pattern can put it its own way (choice_text): "A parcel to Hollis by 2
## PM: 30g".
func order_choice_text(order: QuestDef) -> String:
	var params: Dictionary = _order_params.get(order.id, {})
	var template := ContentDB.order_template(StringName(params.get("template", "")))
	if template != null and template.choice_text != "":
		return OrderTemplate.fill(template.choice_text, _words(template, params))
	var item := ContentDB.item(StringName(params.get("item", "")))
	var count := int(params.get("count", 0))
	var client := ""
	if template != null and template.client != "":
		client = " for %s" % template.client
	return "%d %s%s, %dg" % [count, QuestGoal.plural(item.display_name if item != null else "?", count),
			client, order.reward_gold]


## The morning summary's lines about orders up today: "Help wanted on the
## notice board today." One per place that has some.
func order_news_today() -> Array[String]:
	var news: Array[String] = []
	var places: Array[StringName] = []
	for template in ContentDB.order_templates():
		if template.posted_at not in places:
			places.append(template.posted_at)
	for place in places:
		if orders_on_offer(place).is_empty():
			continue
		for template in _templates_today(place, GameState.day_number()):
			if template.news_line != "":
				news.append(template.news_line)
				break
	return news


## Which of `place`'s patterns are up on day `number`: one of those available
## that day (with something in season to ask for), picked by weight with the
## day's dice, and every available one that's `always_up` (DECISIONS 062).
func _templates_today(place: StringName, number: int) -> Array[OrderTemplate]:
	var result: Array[OrderTemplate] = []
	var candidates: Array[OrderTemplate] = []
	var total := 0
	for template in ContentDB.order_templates():
		if template.posted_at != place or number < template.first_day \
				or not GameState.has_unlock(template.requires_unlock) or template.weight <= 0:
			continue
		if template.on_event != &"" and not GameState.events_on(number).any(
				func(e: CalendarEvent) -> bool: return e.id == template.on_event):
			continue
		if not _available(template, number):
			continue
		if template.always_up:
			result.append(template)
			continue
		candidates.append(template)
		total += template.weight
	if candidates.is_empty():
		return result
	var roll := _dice(place, number, 0).randi_range(1, total)
	for template in candidates:
		roll -= template.weight
		if roll <= 0:
			result.push_front(template)
			return result
	result.push_front(candidates[-1])
	return result


## True if `template` has something to ask for on day `number`: an
## allotment job in one of its seasons, anything else something in season.
func _available(template: OrderTemplate, number: int) -> bool:
	if template is JobTemplate:
		var seasons := (template as JobTemplate).seasons
		return seasons.is_empty() or GameState.season_id_on(number) in seasons
	return not _in_season(template).is_empty()


## The items of `template` that can be asked for today: produce of a crop
## growing this season whose seeds are on sale to the player (unlocked, with
## a price), fish that bite this season, and anything nobody grows (fibre).
## In the template's own order.
func _in_season(template: OrderTemplate) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	var season := GameState.season_id()
	for item in template.items:
		if item == null:
			continue
		# A fish (DECISIONS 055) is wanted only in a season it bites in, and
		# never one that waits for the weather: a job due tonight can't
		# promise rain.
		if item is FishDef:
			var fish := item as FishDef
			if season not in fish.seasons or not fish.only_in_weather.is_empty():
				continue
		var crop := ContentDB.crop_giving(item)
		if crop != null:
			if not crop.grows_in(season):
				continue
			var seeds := ContentDB.seeds_for(crop)
			if seeds == null or seeds.buy_price <= 0 or not GameState.has_unlock(seeds.requires_unlock):
				continue
		result.append(item)
	return result


## The day's dice for `place`: seeded by the date, so what's offered is the
## same however often it's asked. `roll` keeps the template's draw separate
## from the items'.
func _dice(place: StringName, number: int, roll: int) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("%s/%d/%d" % [place, number, roll])
	return dice


## Build the QuestDef for an order from `template` and what was picked for
## it (`params`: "item", "count", "gold", "day", and for an errand "to" and
## "due_at", for a job "plot" and "due_at"). `item` is params' item, looked
## up (null for a job).
func _build_order(id: StringName, template: OrderTemplate, item: ItemDef, params: Dictionary) -> QuestDef:
	var quest := QuestDef.new()
	quest.id = id
	quest.giver = template.posted_at
	quest.goal = template.make_goal(item, params)
	quest.reward_gold = int(params.get("gold", 0))
	quest.deadline_days = template.deadline_days
	quest.hand_in_to = StringName(params.get("to", ""))
	quest.due_minute = int(params.get("due_at", 0))
	var words := _words(template, params)
	quest.title = OrderTemplate.fill(template.title, words)
	if template.offer_line != "":
		quest.offer_lines = [OrderTemplate.fill(template.offer_line, words)]
	quest.reminder_line = OrderTemplate.fill(template.reminder_line, words)
	if template.thanks_line != "":
		quest.thanks_lines = [OrderTemplate.fill(template.thanks_line, words)]
	quest.late_line = OrderTemplate.fill(template.late_line, words)
	_orders[id] = quest
	_order_params[id] = params.duplicate()
	return quest


## What an order's words can name: {count} {item} {gold} {client}, and
## {to} {time} {plot} (DECISIONS 062).
func _words(template: OrderTemplate, params: Dictionary) -> Dictionary:
	var count := int(params.get("count", 0))
	var item := ContentDB.item(StringName(params.get("item", "")))
	var due := int(params.get("due_at", 0))
	return {"count": count, "item": QuestGoal.plural(item.display_name, count) if item != null else "",
			"gold": int(params.get("gold", 0)), "client": template.client,
			"to": giver_name(StringName(params.get("to", ""))) if params.has("to") else "",
			"time": Clock.format_short(due) if due > 0 else "tonight",
			"plot": int(params.get("plot", 0))}


## Night, step 1: anything due today that's still in hand runs out.
func _expire_overdue() -> void:
	for id in GameState.quests.overdue_ids(GameState.day_number()):
		_expire(id)


## Through the day (DECISIONS 062): anything due by a time of day that has
## now passed runs out there and then.
func _expire_late() -> void:
	var today := GameState.day_number()
	for quest in active():
		var due := GameState.quests.due_day(quest.id)
		if quest.due_minute > 0 and due > 0 and due <= today and GameState.minutes >= quest.due_minute:
			_expire(quest.id)


## Request `id` ran out: gone, with anything it gave to carry taken back.
func _expire(id: StringName) -> void:
	var quest := find(id)
	GameState.quests.expire(id)
	_told_ready.erase(id)
	if quest != null and quest.goal != null:
		quest.goal.on_expired(GameState.inventory)
	var title := quest.title if quest != null else String(id)
	EventBus.quest_expired.emit(id, title)
	var line := "Out of time: %s." % title
	if quest != null and quest.late_line != "":
		line += " " + quest.late_line
	EventBus.message_posted.emit(line)


## The morning: yesterday's orders are cleared away and today's will be built
## when they're asked for.
func _start_of_day() -> void:
	GameState.quests.forget_old_orders()
	for id: StringName in _orders.keys():
		if not GameState.quests.is_active(id):
			_orders.erase(id)
			_order_params.erase(id)


## A different game: nothing from this one's day carries over.
func _forget_today() -> void:
	_told_ready.clear()
	_orders.clear()
	_order_params.clear()
	_declined.clear()


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
		EventBus.quest_progressed.emit(quest.id, progress(quest), quest.goal.needed())
		# An allotment job is paid the moment its last tile is done
		# (DECISIONS 062): what would be said on handing in goes on the HUD.
		if quest.goal.finishes_itself() and is_ready(quest):
			for line in _complete(quest):
				EventBus.message_posted.emit(line)
	_check_ready()


## Tell the player, once, when a request has everything it needs.
func _check_ready() -> void:
	for quest in active():
		if _told_ready.has(quest.id) or quest.goal.finishes_itself() or not is_ready(quest):
			continue
		_told_ready[quest.id] = true
		# A parcel is ready the moment it's taken: the line that took it
		# already said where it goes.
		if quest.receiver() != quest.giver:
			continue
		EventBus.message_posted.emit("%s: done! Go and see %s" % [quest.title, giver_name(quest.receiver())])
