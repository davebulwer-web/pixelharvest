class_name ShopCounter
extends RefCounted
##
## ShopCounter — what happens when you talk to a shopkeeper, indoors or at a
## market stall: they turn you away if they're shut, otherwise they say their
## line for the day and then the shop menu opens (DECISIONS 027, 035, 037).
##
## It was in the shop interior until market stalls needed the same thing in
## town; one copy means a keeper behaves the same wherever they stand.
##
## Made by the scene that has a dialogue box and a shop menu, which then hands
## it every shopkeeper conversation with serve().
##

var _dialogue
var _menu

## The shop whose menu opens when the keeper finishes talking, or null when
## the conversation shouldn't lead to a menu (they've just said they're shut).
var _opens_after: ShopDef = null


func _init(dialogue, menu) -> void:
	_dialogue = dialogue
	_menu = menu
	_dialogue.finished.connect(_on_dialogue_finished)


## The player spoke to `shop`'s keeper.
func serve(shop: ShopDef) -> void:
	if not shop.is_open_at(GameState.minutes):
		_opens_after = null
		var closed_lines: Array[String] = [
			"Sorry, we're closed for today. Come back tomorrow — I'm open %s." % shop.hours_text()]
		if GameState.minutes < shop.opens_at:
			closed_lines = ["Not open yet, I'm afraid. I open at %s." % Clock.format_short(shop.opens_at)]
		_dialogue.say(shop.keeper_name, closed_lines)
		return
	if shop.greetings.is_empty():
		_menu.open(shop)
		return
	# One greeting a day: the same line all day, a new one tomorrow.
	_opens_after = shop
	var lines: Array[String] = [shop.greetings[GameState.day % shop.greetings.size()]]
	_dialogue.say(shop.keeper_name, lines)


func _on_dialogue_finished() -> void:
	# The dialogue box is shared with the rest of the scene (townsfolk, the
	# notice board), so only a conversation this started opens the menu.
	if _opens_after == null:
		return
	var shop := _opens_after
	_opens_after = null
	_menu.open(shop)
