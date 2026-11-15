extends Node
##
## Quests — the townsfolk's requests: who has one to offer, what happens when
## you talk to them about it, and keeping count as you play (DECISIONS 038).
##
## Stage 8 called this "the architecture's exam": quests had to arrive without
## the farming code changing. They do. Progress comes entirely from EventBus —
## this file listens to signals the farm, the bin and the shops already
## announced (crop_harvested, items_shipped, items_sold_to_shop, item_bought,
## giant_harvested) and offers each one to every active request's goal (QuestGoal.counts).
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

## Where the notice board's jobs are posted and handed in: it stands in for
## a giver's id.
const BOARD := &"notice_board"

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
	if template == null or item == null:
		return null
	return _build_order(id, template, item, int(params["count"]), int(params["gold"]), int(params["day"]))


## How far along `quest` is, capped at what it needs.
func progress(quest: QuestDef) -> int:
	if quest.goal == null:
		return 0
	return mini(quest.goal.progress(GameState.quests.recorded(quest.id), GameState.inventory, GameState.gold),
			quest.goal.needed())


## True if `quest` is taken and has everything it needs.
func is_ready(quest: QuestDef) -> bool:
	return GameState.quests.is_active(quest.id) and quest.goal != null \
			and progress(quest) >= quest.goal.needed()


## The request `npc_id` has given you that's still open, or null.
func active_for(npc_id: StringName) -> QuestDef:
	for quest in active():
		if quest.giver == npc_id:
			return quest
	return null


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
	var quest := active_for(npc_id)
	if quest != null:
		return "?" if is_ready(quest) else ""
	if offer_for(npc_id) != null or not orders_on_offer(npc_id).is_empty():
		return "!"
	return ""


## "today", "tomorrow", "in 5 days (summer day 10)": when `quest`'s time runs
## out, or "" if it has no deadline or isn't in hand.
func due_text(quest: QuestDef) -> String:
	var due := GameState.quests.due_day(quest.id)
	if due <= 0:
		return ""
	var ahead := due - GameState.day_number()
	if ahead <= 0:
		return "today"
	if ahead == 1:
		return "tomorrow"
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
	var quest := active_for(npc_id)
	if quest != null:
		if is_ready(quest):
			return _complete(quest)
		var reminder := quest.reminder_line if quest.reminder_line != "" else "%s?" % quest.goal.describe()
		var line := "%s (%s)" % [reminder, quest.goal.progress_text(progress(quest))]
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
	EventBus.quest_started.emit(quest.id)
	var lines: Array[String] = quest.offer_lines.duplicate()
	var text := "New request: %s. %s" % [quest.title, quest.goal.describe()]
	# "Bring 5 parsnips to Mabel". A gift of gold already says what it's for.
	if quest.goal.is_handed_over() and quest.goal.gold_to_hand_in() == 0:
		text += " to %s" % giver_name(quest.giver)
	if due > 0:
		text += ", %s" % ("by tonight" if due == GameState.day_number() else "due " + due_text(quest))
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
	# After quest_completed, so the day's summary lists the request before
	# what it opened.
	EventBus.quest_completed.emit(quest.id)
	for unlock_def in quest.reward_unlocks:
		GameState.unlock(unlock_def)
	var lines: Array[String] = quest.thanks_lines.duplicate()
	var reward := quest.reward_text()
	lines.append("Request done: %s.%s" % [quest.title, " You got %s." % reward if reward != "" else ""])
	return lines


# --- Orders (DECISIONS 050) ---------------------------------------------------

## The orders `place` (Rosa's shop id, or BOARD) has up today for the player
## to choose from, or none: none while the player has a request from there in
## hand or a written one to be asked first, or after turning them down today.
## The same every time it's asked today.
func orders_on_offer(place: StringName) -> Array[QuestDef]:
	var offers: Array[QuestDef] = []
	var today := GameState.day_number()
	if active_for(place) != null or _declined.get(place, -1) == today:
		return offers
	if place != BOARD and (not is_about(place) or offer_for(place) != null):
		return offers
	var template := _template_today(place, today)
	if template == null:
		return offers
	var dice := _dice(place, today, 1)
	var pool := _in_season(template)
	# Shuffled by the day's own dice, then the first few: different items.
	for i in range(pool.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for n in mini(template.choices, pool.size()):
		var id := StringName("%s@%d#%d" % [template.id, today, n + 1])
		if GameState.quests.state(id) != &"":
			return []  # one was taken today: the rest are off the table
		var item: ItemDef = pool[n]
		var count := dice.randi_range(template.count_min, template.count_max)
		var price := Economy.sell_price(item)
		if template.max_value > 0 and price > 0:
			count = clampi(mini(count, floori(template.max_value / float(price))), 1, count)
		var gold := ceili(price * count * template.pay_rate) + template.bonus_gold
		offers.append(_build_order(id, template, item, count, gold, today))
	return offers


## Take `order` (one of orders_on_offer): it goes in the log like any request.
## Returns what's said.
func take(order: QuestDef) -> Array[String]:
	if GameState.quests.state(order.id) != &"":
		return []
	return _start(order)


## The player turned down `place`'s orders: don't offer them again today.
func decline(place: StringName) -> void:
	_declined[place] = GameState.day_number()


## What `place`'s pattern today says before its choices, or "".
func choice_line(place: StringName) -> String:
	var template := _template_today(place, GameState.day_number())
	return template.choice_line if template != null else ""


## "8 tomatoes, 420g": an order in a few words, for choosing between them.
func order_choice_text(order: QuestDef) -> String:
	var params: Dictionary = _order_params.get(order.id, {})
	var item := ContentDB.item(StringName(params.get("item", "")))
	var count := int(params.get("count", 0))
	var client := ""
	var template := ContentDB.order_template(StringName(params.get("template", "")))
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
		var template := _template_today(place, GameState.day_number())
		if template != null and template.news_line != "":
			news.append(template.news_line)
	return news


## Which of `place`'s patterns is up on day `number`: one of those available
## that day with something in season to ask for, picked by weight with the
## day's dice. Null if none.
func _template_today(place: StringName, number: int) -> OrderTemplate:
	var candidates: Array[OrderTemplate] = []
	var total := 0
	for template in ContentDB.order_templates():
		if template.posted_at != place or number < template.first_day \
				or not GameState.has_unlock(template.requires_unlock) or template.weight <= 0:
			continue
		if template.on_event != &"" and not GameState.events_on(number).any(
				func(e: CalendarEvent) -> bool: return e.id == template.on_event):
			continue
		if _in_season(template).is_empty():
			continue
		candidates.append(template)
		total += template.weight
	if candidates.is_empty():
		return null
	var roll := _dice(place, number, 0).randi_range(1, total)
	for template in candidates:
		roll -= template.weight
		if roll <= 0:
			return template
	return candidates[-1]


## The items of `template` that can be asked for today: produce of a crop
## growing this season whose seeds are on sale to the player (unlocked, with
## a price), and anything nobody grows (fibre). In the template's own order.
func _in_season(template: OrderTemplate) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	var season := GameState.season_id()
	for item in template.items:
		if item == null:
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


## Build the QuestDef for an order: a delivery of `count` `item`, paying `gold`,
## from `template`, offered on day `day`.
func _build_order(id: StringName, template: OrderTemplate, item: ItemDef, count: int, gold: int,
		day: int) -> QuestDef:
	var goal := DeliverGoal.new()
	goal.item = item
	goal.amount = count
	var quest := QuestDef.new()
	quest.id = id
	quest.giver = template.posted_at
	quest.goal = goal
	quest.reward_gold = gold
	quest.deadline_days = template.deadline_days
	var words := {"count": count, "item": QuestGoal.plural(item.display_name, count), "gold": gold,
			"client": template.client}
	quest.title = OrderTemplate.fill(template.title, words)
	if template.offer_line != "":
		quest.offer_lines = [OrderTemplate.fill(template.offer_line, words)]
	quest.reminder_line = OrderTemplate.fill(template.reminder_line, words)
	if template.thanks_line != "":
		quest.thanks_lines = [OrderTemplate.fill(template.thanks_line, words)]
	_orders[id] = quest
	_order_params[id] = {"template": String(template.id), "item": String(item.id), "count": count,
			"gold": gold, "day": day}
	return quest


## Night, step 1: anything due today that's still in hand runs out.
func _expire_overdue() -> void:
	for id in GameState.quests.overdue_ids(GameState.day_number()):
		var quest := find(id)
		GameState.quests.expire(id)
		_told_ready.erase(id)
		EventBus.quest_expired.emit(id, quest.title if quest != null else String(id))


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
	_check_ready()


## Tell the player, once, when a request has everything it needs.
func _check_ready() -> void:
	for quest in active():
		if _told_ready.has(quest.id) or not is_ready(quest):
			continue
		_told_ready[quest.id] = true
		EventBus.message_posted.emit("%s: done! Go and see %s" % [quest.title, giver_name(quest.giver)])
