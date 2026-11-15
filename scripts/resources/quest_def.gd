class_name QuestDef
extends Resource
##
## QuestDef — a request someone in town makes of the farmer: who asks, what
## they want (a QuestGoal), what they say, and what they give in return
## (DECISIONS 038). One .tres in data/quests/ per request; ContentDB finds them.
##
## A request is offered by talking to its `giver` (a CharacterDef id) on a day
## it's available: on or after `first_day`, in one of `seasons`, on a day
## `on_event` is on (market day), and once `requires` is done — which is how
## one person's requests come in a chain. Each person asks one thing at a time.
## Accepting is just listening: the giver says their piece, the request goes
## in the log (J), and they remind you of it until it's done.
##
## What's saved is only which requests have been taken and finished, and a
## running count for each (GameState.quests); this file can change freely.
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var id: StringName

## Short, for the request log: "Mabel's parsnips".
@export var title: String

## The CharacterDef id of who asks (&"baker").
@export var giver: StringName

@export var goal: QuestGoal

## What the giver says when asking, one page each.
@export var offer_lines: Array[String] = []

## What they say if you come back before it's done. The progress is added on.
@export var reminder_line: String = ""

## What they say when it's handed in. The reward is added on.
@export var thanks_lines: Array[String] = []

@export var reward_gold: int = 0

## Items given as a reward, and how many of each.
@export var reward_items: Dictionary[ItemDef, int] = {}

# --- When it's offered ---------------------------------------------------------

## Another request that must be finished first, or null.
@export var requires: QuestDef

## The first day it can be offered, counting from day 1 of year 1
## (GameState.day_number), so a request can wait until the farm has grown.
@export var first_day: int = 1

## Seasons (SeasonTheme ids) it's offered in. Empty means any. Once taken it
## stays open across seasons until it's done.
@export var seasons: Array[StringName] = []

## A calendar event (CalendarEvent id) that must be on that day, or &"" for
## any day. &"market_day": only asked on market day.
@export var on_event: StringName = &""


## "150g and 5 potato seeds", or "" for no reward.
func reward_text() -> String:
	var parts: Array[String] = []
	if reward_gold > 0:
		parts.append("%dg" % reward_gold)
	for item: ItemDef in reward_items:
		var count: int = reward_items[item]
		if count == 1:
			var word := item.display_name.to_lower()
			parts.append(("an " if "aeiou".contains(word.left(1)) else "a ") + word)
		else:
			parts.append("%d %s" % [count, QuestGoal.plural(item.display_name, count)])
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
