class_name QuestGoal
extends Resource
##
## QuestGoal — what a request asks for: "bring 5 parsnips", "harvest 3
## strawberries", "sell 200g of produce" (DECISIONS 038).
##
## The base class asks for nothing. Each kind of goal is a small script in
## scripts/quests/ that overrides the methods it needs — the same pattern as
## ToolAction and UpgradeEffect. A new request of an existing kind is only a
## .tres in data/quests/; a new *kind* of request is one small script here.
##
## How progress is counted: the Quests service listens on EventBus for what
## happens in the game (crop_harvested, items_shipped, …) and offers every
## event to each active request's goal through counts(). The goal says how
## much of it counts towards itself. So a goal never connects to anything
## and never touches an autoload: it's plain data with a few questions it can
## answer, which is why the farming code doesn't know quests exist.
##

## How many are needed: items, harvests, or gold, depending on the goal.
## (A goal that asks for one of each of a list works it out from the list:
## see needed().)
@export var amount: int = 1


## How many of whatever this goal counts are needed to finish it. Usually
## `amount`; DeliverEachGoal's is the length of its list.
func needed() -> int:
	return amount


## What the goal asks, in words, without the person: "Bring 5 parsnips".
func describe() -> String:
	return ""


## How much `event` (an EventBus signal's name) with `args` (its values, in
## order) counts towards this goal. 0 if it's nothing to do with it.
func counts(_event: StringName, _args: Array) -> int:
	return 0


## How far along the goal is, given `recorded` (everything counts() has added
## up since the request was accepted), the player's bag and the gold they
## carry. Most goals are the running total; a delivery is whatever is in the
## bag right now, and a gift of gold is what's in the purse.
func progress(recorded: int, _bag: Inventory, _gold: int) -> int:
	return recorded


## "3 / 5": progress in words, for the request log and reminders.
func progress_text(done: int) -> String:
	return "%d / %d" % [mini(done, needed()), needed()]


## What's still missing, in words, for a goal that asks for several
## different things: "leek and cabbage". "" when there's nothing to name.
func still_needed(_bag: Inventory) -> String:
	return ""


## True if the request is finished by handing something over to its giver
## (items or gold), so the request's text says who to take it to.
func is_handed_over() -> bool:
	return false


## Called once, when the request is handed in: take whatever the goal asked
## for (a delivery takes its items out of the bag). Most goals take nothing.
func hand_in(_bag: Inventory) -> void:
	pass


## Gold taken from the player when the request is handed in (a gift towards
## the bridge). The Quests service takes it, since a goal touches no autoload.
func gold_to_hand_in() -> int:
	return 0


## Called once, when the request is taken: a goal that comes with something
## to carry (Dot's parcel, DECISIONS 062) puts it in the bag. Most give nothing.
func on_taken(_bag: Inventory) -> void:
	pass


## Called once, if the request runs out: whatever on_taken() gave goes back
## (the parcel returns to Dot). Most take nothing.
func on_expired(_bag: Inventory) -> void:
	pass


## True for a goal that's finished the moment it's done, with nobody to go
## back to: an allotment job is paid on the spot (DECISIONS 062). False for
## every request that's handed in.
func finishes_itself() -> bool:
	return false


## "parsnip, radish and potato": names joined for a sentence, lower case.
static func list_names(items: Array[ItemDef]) -> String:
	var names: Array[String] = []
	for item in items:
		names.append(item.display_name.to_lower() if item != null else "?")
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## Names that stay the same for more than one: "20 timber", "12 fibre", not
## "timbers" (DECISIONS 053). Most fish too (DECISIONS 054).
const SAME_IN_PLURAL: Array[String] = ["timber", "fibre", "holly", "kale", "garlic", "wild garlic",
		"corn", "rhubarb",
		# Fish, as anglers say them (DECISIONS 054): "3 perch", "2 pike".
		"fish", "bait", "perch", "roach", "rudd", "dace", "tench", "chub", "pike", "carp", "crucian carp",
		"barbel", "grayling", "brown trout", "sea trout",
		# And in recipes (DECISIONS 056): "any 3 fruit".
		"fruit"]


## "parsnip" -> "parsnips", "strawberry" -> "strawberries", "potato" ->
## "potatoes", lower case. One of something stays singular, and a name
## that already ends in s ("potato seeds") is left alone.
static func plural(name: String, count: int) -> String:
	var word := name.to_lower()
	if count == 1 or word == "" or word in SAME_IN_PLURAL:
		return word
	if word.ends_with("y") and word.length() > 1 and not "aeiou".contains(word[-2]):
		return word.left(-1) + "ies"
	if word.ends_with("s"):
		return word  # already plural: "potato seeds"
	if word.ends_with("o") or word.ends_with("sh") or word.ends_with("ch"):
		return word + "es"
	return word + "s"
