class_name FindDef
extends Resource
##
## FindDef — something that now and then turns up while clearing the farm's
## new ground (DECISIONS 061): an old seed tin, a rusty tool head, a page of
## the old farmer's notebook, the cover of a buried well. One .tres in
## data/finds/ per find; ContentDB finds them.
##
## Each time a piece of debris is cleared, the finds that could be under it
## are rolled in file order, and the first that comes up is found. At most
## GameRules.finds_per_day turn up a day, so a long day's clearing can't
## empty the list. The dice are the cell and the day, so the same clearing on
## the same day always finds the same thing.
##
## What a find does is all data: it can put items in the bag (`gives`), earn
## an unlock (a request that waits for it: Brann's mending), and leave
## something standing where it was dug up (the old well). What the player is
## told is `words`, and for a find that turns up more than once, the next of
## `pages` each time (the notebook).
##
## What's saved is only how many times each find has turned up
## (GameState.finds), so this file can change freely.
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var id: StringName

## What it is, as the dialogue box's heading: "An old seed tin".
@export var display_name: String

## The debris it can be under, by ObjectDef id (&"stones"). Empty: any.
@export var found_under: Array[StringName] = []

## The chance it turns up when one of those is cleared (0.05 is one in twenty).
@export_range(0.0, 1.0) var chance: float = 0.05

## How many times it can turn up in a game. 0: no limit.
@export var times: int = 1

## The first day it can turn up, counting from day 1 of year 1
## (GameState.day_number), like QuestDef.first_day.
@export var first_day: int = 1

## Seasons (SeasonTheme ids) it turns up in. Empty means any.
@export var seasons: Array[StringName] = []

## What the player is told each time it turns up, one page each.
@export var words: Array[String] = []

## For a find that turns up more than once with something new each time (the
## notebook's pages): the page for each time, in order, shown after `words`.
@export var pages: Array[String] = []

## What it puts in the bag, and how many of each.
@export var gives: Dictionary[ItemDef, int] = {}

## What finding it earns (DECISIONS 043), or null: the rusty tool head earns
## the one Brann's mending waits for.
@export var gives_unlock: UnlockDef

## Something left standing where it was found, by ObjectDef id (the old
## well), or &"" for nothing: the tile is left as clear grass.
@export var leaves_object: StringName = &""


## True if this could turn up under `debris_id` on day `day_number` of
## `season_id`, having turned up `found_before` times already.
func could_turn_up(debris_id: StringName, day_number: int, season_id: StringName, found_before: int) -> bool:
	if times > 0 and found_before >= times:
		return false
	if day_number < first_day:
		return false
	if not seasons.is_empty() and season_id not in seasons:
		return false
	return found_under.is_empty() or debris_id in found_under


## What the player is told the time it's found for the `nth` time (counting
## from 1): its words, then that time's page (the last page again if there
## are more times than pages).
func lines_for(nth: int) -> Array[String]:
	var lines: Array[String] = words.duplicate()
	if not pages.is_empty():
		lines.append(pages[clampi(nth - 1, 0, pages.size() - 1)])
	return lines
