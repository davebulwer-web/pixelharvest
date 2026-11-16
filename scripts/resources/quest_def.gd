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
## Not every QuestDef is a file: Rosa's market orders and the notice board's
## daily jobs are made fresh each day from an OrderTemplate (DECISIONS 050),
## as QuestDefs like these, so everything that shows or counts requests
## treats them the same.
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

## What finishing it opens up (DECISIONS 043): the mayor's first request opens
## Hollis's spring seeds. Each is named in the reward text, so the player is
## told what they've opened.
@export var reward_unlocks: Array[UnlockDef] = []

## Upgrades given as a reward (DECISIONS 055): Wren's fine rod is a better
## tier of the rod, given the way a bought upgrade gives the wide hoe. Mark
## them gift_only so no shop sells them too.
@export var reward_upgrades: Array[UpgradeDef] = []

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

## Not offered until this is earned (DECISIONS 043). Null: no wait.
@export var requires_unlock: UnlockDef

## How many days the player has to do it once it's taken, counting the day
## it's taken (DECISIONS 050): 1 means "by tonight", 8 "by the end of next
## week's market day". 0: no deadline. When it runs out the request is
## simply gone overnight: no penalty, only the reward missed. A request that
## ran out isn't asked again (Rosa's orders and the board's jobs are new
## requests each time, so they keep coming).
@export var deadline_days: int = 0


## "150g, 5 potato seeds and Hollis's spring seeds", or "" for no reward.
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
	for upgrade in reward_upgrades:
		if upgrade != null:
			var word := upgrade.display_name.to_lower()
			parts.append(("an " if "aeiou".contains(word.left(1)) else "a ") + word)
	for unlock in reward_unlocks:
		if unlock != null and unlock.display_name != "":
			parts.append(unlock.display_name)
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
