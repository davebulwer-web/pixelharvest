class_name CalendarEvent
extends Resource
##
## CalendarEvent — something that happens on particular days of the calendar:
## market day, and later fairs and festivals (DECISIONS 037).
##
## An event is worked out from the date, never stored: it happens on day
## `first_day` of the game and then every `every_days` days after, counting
## straight through seasons and years (GameState.day_number). So nothing about
## events is in the save, and changing these numbers changes every game at once.
##
## What an event brings is data too. A market's stalls are StallDefs: a shop
## (an ordinary ShopDef, so it has a keeper, greetings, hours and stock) and
## where its stall stands. The town builds whatever stalls today's events
## have, so a second market, or a third stall, is a data change.
##
## Nothing in this file may touch an autoload: ContentDB loads it while the
## autoloads are still starting.
##

@export var id: StringName
@export var display_name: String

## The first day it happens, counting from day 1 of year 1 (spring day 1).
@export var first_day: int = 1

## How often it comes round, in days: 7 is once a week.
@export var every_days: int = 7

## The seasons it happens in, by SeasonTheme id. Empty means all year.
@export var seasons: Array[StringName] = []

## Where it happens (&"town"). That location's scene builds the stalls.
@export var location: StringName = &"town"

## One line for the notice board, after its name: what's on.
@export_multiline var description: String = ""

## The stalls set up while it's on.
@export var stalls: Array[StallDef] = []

## Doesn't happen until this is earned (DECISIONS 044), however the dates
## fall. Null: it happens from the start. happens_on() below is only the
## date; GameState.events_on() asks this too.
@export var requires_unlock: UnlockDef


## True if the date alone says this happens on `day_number`
## (GameState.day_number), when the season that day is `season_id`.
func happens_on(day_number: int, season_id: StringName) -> bool:
	if every_days < 1 or day_number < first_day:
		return false
	if not seasons.is_empty() and season_id not in seasons:
		return false
	return (day_number - first_day) % every_days == 0
