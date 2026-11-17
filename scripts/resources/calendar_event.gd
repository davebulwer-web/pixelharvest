class_name CalendarEvent
extends Resource
##
## CalendarEvent — something that happens on particular days of the calendar:
## market day, and the four festivals (DECISIONS 037, 059).
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
## A festival (DECISIONS 059) is an event with a `host`: someone who stands
## at `host_cell` all day and runs it. They may hold a contest (`contest`:
## a judge, rivals and prizes), hand everyone a keepsake (`gift_items`), or
## both. The festival's dressing (bunting, the show table, lanterns) is
## `decorations`, objects set up on the event's map for the day.
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

@export_group("Festival")

## Who runs it (a CharacterDef id): they stand at `host_cell` all day, and
## you talk to them to enter its contest or be given its gift. &"": it isn't
## a festival.
@export var host: StringName = &""

## Where the host stands while it's on.
@export var host_cell: Vector2i

## What the host says about the day, before anything else, each time you
## speak to them (a festival with no contest: lantern night).
@export var host_lines: Array[String] = []

## The judging, or null for no contest.
@export var contest: ContestDef

## Given to the farmer by the host, once on the day: lantern night's lantern.
@export var gift_items: Dictionary[ItemDef, int] = {}

## What the host says as they hand the gift over.
@export var gift_line: String = ""

## The festival's dressing: ObjectDef ids by the cell each stands on, put
## up on the event's map for the day, like the town's own objects.
@export var decorations: Dictionary[Vector2i, StringName] = {}


## True if someone runs it (a festival), rather than only setting up stalls.
func is_festival() -> bool:
	return host != &""


## True if the date alone says this happens on `day_number`
## (GameState.day_number), when the season that day is `season_id`.
func happens_on(day_number: int, season_id: StringName) -> bool:
	if every_days < 1 or day_number < first_day:
		return false
	if not seasons.is_empty() and season_id not in seasons:
		return false
	return (day_number - first_day) % every_days == 0
