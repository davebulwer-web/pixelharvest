class_name ShopCounter
extends RefCounted
##
## ShopCounter — what happens when you talk to a shopkeeper, indoors or at a
## market stall: they turn you away if they're shut, otherwise they say their
## line for the day (or about a request they've made, DECISIONS 044) and then
## the shop menu opens (DECISIONS 027, 035, 037).
##
## It was in the shop interior until market stalls needed the same thing in
## town; one copy means a keeper behaves the same wherever they stand.
##
## Made by the scene that has a dialogue box and a shop menu, which then hands
## it every shopkeeper conversation with serve().
##
## Orders (DECISIONS 050): a keeper with orders to choose from (Rosa, on
## market day) asks which you'll take, with "Not this week" last. Whatever
## you pick, the menu opens after, as it always does.
##

var _dialogue
var _menu

## The shop whose menu opens when the keeper finishes talking, or null when
## the conversation shouldn't lead to a menu (they've just said they're shut).
var _opens_after: ShopDef = null

## The keeper whose orders are being chosen between, and those orders.
var _asking: ShopDef = null
var _asking_giver: StringName = &""
var _offers: Array[QuestDef] = []


func _init(dialogue, menu) -> void:
	_dialogue = dialogue
	_menu = menu
	_dialogue.finished.connect(_on_dialogue_finished)
	_dialogue.chosen.connect(_on_order_chosen)


## The player spoke to `shop`'s keeper. Requests and orders are asked of
## `giver`, the keeper's id for the Quests service: the shop's own id for a
## shopkeeper, or a person's CharacterDef id when the counter is theirs
## (Tam on the quay, CharacterDef.counter; DECISIONS 065), and then `lines`
## are what they say when they've nothing to ask (before the shop's own
## greetings, which are said when no lines are given: DECISIONS 068).
func serve(shop: ShopDef, giver: StringName = &"", lines: Array[String] = []) -> void:
	if giver == &"":
		giver = shop.id
	if not shop.is_open_at(GameState.minutes):
		_opens_after = null
		var closed_lines: Array[String] = [
			"Sorry, we're closed for today. Come back tomorrow — I'm open %s." % shop.hours_text()]
		if GameState.minutes < shop.opens_at:
			closed_lines = ["Not open yet, I'm afraid. I open at %s." % Clock.format_short(shop.opens_at)]
		_dialogue.say(shop.keeper_name, closed_lines)
		return
	# A keeper with a request to make, remind you of or take in says that
	# instead of their greeting (DECISIONS 044), and the menu opens after, as
	# usual: Brann can ask you to prove yourself and still sell you a hoe.
	var about_requests := Quests.talk(giver)
	if not about_requests.is_empty():
		_opens_after = shop
		_dialogue.say(shop.keeper_name, about_requests)
		return
	var offers := Quests.orders_on_offer(giver)
	if not offers.is_empty():
		_opens_after = null
		_asking = shop
		_asking_giver = giver
		_offers = offers
		var answers: Array[String] = []
		for order in offers:
			answers.append(Quests.order_choice_text(order))
		answers.append("Not this time")
		_dialogue.ask(shop.keeper_name, Quests.choice_line(giver), answers)
		return
	# What the caller gives to say comes first (Nell's rumour for tonight,
	# DECISIONS 068; Tam's own lines), then the shop's greetings.
	var greetings: Array[String] = lines if not lines.is_empty() else shop.greetings
	if greetings.is_empty():
		_menu.open(shop)
		return
	# One greeting a day: the same line all day, a new one tomorrow.
	_opens_after = shop
	var said: Array[String] = [greetings[GameState.day % greetings.size()]]
	_dialogue.say(shop.keeper_name, said)


## The player picked one of the keeper's orders, or none (the last answer).
func _on_order_chosen(index: int) -> void:
	if _asking == null:
		return  # someone else's question
	var shop := _asking
	var giver := _asking_giver
	var offers := _offers
	_asking = null
	_asking_giver = &""
	_offers = []
	_opens_after = shop
	if index < offers.size():
		_dialogue.say(shop.keeper_name, Quests.take(offers[index]))
		return
	Quests.decline(giver)
	var lines: Array[String] = ["Another time, then."]
	_dialogue.say(shop.keeper_name, lines)


func _on_dialogue_finished() -> void:
	# The dialogue box is shared with the rest of the scene (townsfolk, the
	# notice board), so only a conversation this started opens the menu.
	if _opens_after == null:
		return
	var shop := _opens_after
	_opens_after = null
	_menu.open(shop)
