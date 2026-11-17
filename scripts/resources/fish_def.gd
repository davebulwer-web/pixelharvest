class_name FishDef
extends ItemDef
##
## FishDef — a kind of fish (DECISIONS 054): where it lives, when it bites,
## how big it grows and how hard it fights.
##
## It is an item like any other (name, icon, sell price, tags), so the bag,
## the shipping bin, Marlow's counter and requests treat a caught fish as
## produce. What this adds is when and where it bites: a kind of water, the
## seasons, a stretch of the day and, for a few, the weather. When something
## bites, Fishing (scripts/autoload/fishing.gd) picks one by `weight` among
## the fish biting there and then.
##
## Each catch has its own size, rolled between min_size and max_size. Size
## doesn't change the price (the bag holds "4 perch", not four different
## perch): it's for the fish log's records, and later for the summer contest
## and Pip's biggest fish.
##
## One .tres per kind, in data/fish/. A new fish is a new file and an icon,
## nothing else (rule 3).
##
## Nothing in this file may touch an autoload (it is plain data).
##

## The kinds of water it lives in: &"pond" (the farm's and the town's),
## &"river" (along the top of the town), &"stream" (in the Woods) or &"sea"
## (off the Cove's pier, quay and breakwater, DECISIONS 065).
@export var waters: Array[StringName] = [&"pond"]

## Only in these locations, by id, for a fish that lives in one place only
## (the town pond's legend, one day). Empty: wherever its water is.
@export var found_in: Array[StringName] = []

## The seasons it bites in, by id. Empty: never. Winter fish wait for the
## ice hole (Stage 15 session 2): until then all water is frozen in winter.
@export var seasons: Array[StringName] = []

## The stretch of the day it bites in, in minutes after midnight, as the
## clock counts them (6 AM is 360; past midnight it keeps counting, so 1 AM
## is 1500). The whole day by default.
@export var bites_from: int = 360
@export var bites_until: int = 1560

## Only in one of these weathers (by id): the sea trout runs up the stream
## in the rain. Empty: any weather.
@export var only_in_weather: Array[StringName] = []

## How likely it is to be the one that bites, against the other fish biting
## there then: 10 is common, 3 a lucky catch. Only the ratio matters.
@export var weight: int = 10

## How big one can be, in centimetres. Each catch is somewhere in between,
## most often in the middle.
@export var min_size: int = 10
@export var max_size: int = 30

## How hard it fights on the line, from 1 (a minnow) to 5 (a pike). The
## fishing rules (data/fishing_rules.tres) say what each step means: how
## fast the reel bar's marker swings, how wide its green zone is, and how
## many good pulls land it.
@export_range(1, 5) var fight: int = 1

## Only while the tide is in (DECISIONS 065): the bass comes in over the
## rocks with the flood. Only means anything in the sea; elsewhere there's
## no tide and it's ignored.
@export var only_at_high_tide: bool = false


## True if it would bite in `water` at `location_id`, on a day of
## `season_id` at `minutes` with `weather_id`, with the tide in or out
## (`tide_in`; only the sea has a tide, so the default suits every other water).
func bites(water: StringName, location_id: StringName, season_id: StringName, minutes: int,
		weather_id: StringName, tide_in: bool = true) -> bool:
	if weight <= 0 or water not in waters or season_id not in seasons:
		return false
	if not found_in.is_empty() and location_id not in found_in:
		return false
	if minutes < bites_from or minutes >= bites_until:
		return false
	if only_at_high_tide and not tide_in:
		return false
	return only_in_weather.is_empty() or weather_id in only_in_weather


## "6 AM to 11 AM", "all day": when it bites, for its description and the
## almanac.
func hours_text() -> String:
	if bites_from <= 360 and bites_until >= 1560:
		return "all day"
	return "%s to %s" % [clock_text(bites_from), clock_text(bites_until)]


## 1080 -> "6 PM", 1500 -> "1 AM", 630 -> "10:30 AM".
static func clock_text(minutes: int) -> String:
	var hour := posmod(floori(minutes / 60.0), 24)
	var minute := posmod(minutes, 60)
	var suffix := "AM" if hour < 12 else "PM"
	var shown := hour % 12
	if shown == 0:
		shown = 12
	if minute == 0:
		return "%d %s" % [shown, suffix]
	return "%d:%02d %s" % [shown, minute, suffix]
