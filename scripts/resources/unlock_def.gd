class_name UnlockDef
extends Resource
##
## UnlockDef — something that opens up as the game goes on: Hollis's spring
## seeds, Brann's forge, the summer catalogue (DECISIONS 043). One .tres in
## data/unlocks/ per unlock; ContentDB finds them.
##
## An unlock is only a name the game remembers once it's earned
## (GameState.unlocks, saved by id). It does nothing by itself. Content points
## at it instead: an item, an upgrade, a request or a building with
## `requires_unlock` set to this file stays hidden (or locked) until it's
## earned. So a new thing to drip-feed is data: an UnlockDef, and the field
## set on whatever it opens.
##
## Two ways to earn one:
##   - a request gives it as a reward (QuestDef.reward_unlocks);
##   - the calendar gives it on `on_day`, overnight (the forge on day 8).
##
## Rule for writing content (ROADMAP section 4): an unlock is announced by a
## person or the notice board, never silently. `announcement` is the line the
## morning summary shows the day it opens; a calendar unlock is also pinned on
## the notice board for the days before it comes.
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var id: StringName

## A short name, for request rewards and the notice board: "Hollis's spring
## seeds". Read as part of a sentence, so it starts in lower case unless it's
## a name.
@export var display_name: String

## What the morning summary says the day it opens: "Hollis has potato seeds in."
@export var announcement: String = ""

## The day it opens by itself, counting from day 1 of year 1
## (GameState.day_number), like QuestDef.first_day. 0 means never by the
## calendar: only a request can give it.
@export var on_day: int = 0


## True if the calendar opens it at all.
func opens_by_date() -> bool:
	return on_day > 0
