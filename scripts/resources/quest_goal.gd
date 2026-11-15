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
@export var amount: int = 1


## What the goal asks, in words, without the person: "Bring 5 parsnips".
func describe() -> String:
	return ""


## How much `event` (an EventBus signal's name) with `args` (its values, in
## order) counts towards this goal. 0 if it's nothing to do with it.
func counts(_event: StringName, _args: Array) -> int:
	return 0


## How far along the goal is, given `recorded` (everything counts() has added
## up since the request was accepted) and the player's bag. Most goals are the
## running total; a delivery is whatever is in the bag right now.
func progress(recorded: int, _bag: Inventory) -> int:
	return recorded


## "3 / 5": progress in words, for the request log and reminders.
func progress_text(done: int) -> String:
	return "%d / %d" % [mini(done, amount), amount]


## Called once, when the request is handed in: take whatever the goal asked
## for (a delivery takes its items out of the bag). Most goals take nothing.
func hand_in(_bag: Inventory) -> void:
	pass


## "parsnip" -> "parsnips", "strawberry" -> "strawberries", "potato" ->
## "potatoes", lower case. One of something stays singular, and a name
## that already ends in s ("potato seeds") is left alone.
static func plural(name: String, count: int) -> String:
	var word := name.to_lower()
	if count == 1 or word == "":
		return word
	if word.ends_with("y") and word.length() > 1 and not "aeiou".contains(word[-2]):
		return word.left(-1) + "ies"
	if word.ends_with("s"):
		return word  # already plural: "potato seeds"
	if word.ends_with("o") or word.ends_with("sh") or word.ends_with("ch"):
		return word + "es"
	return word + "s"
