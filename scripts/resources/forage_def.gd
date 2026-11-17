class_name ForageDef
extends ItemDef
##
## ForageDef — something wild you can pick up in the Woods: a mushroom, a
## handful of berries, a sprig of holly (DECISIONS 052).
##
## It is an item like any other (name, icon, sell price, tags), so the bag,
## the shipping bin, the shops and requests treat it as one. What this adds
## is where and when it grows wild. Each morning a few spots in each place
## that has forage get something, chosen by `weight` among the forage that is
## in season there today; see Forage (scripts/woods/forage.gd).
##
## One .tres per kind, in data/forage/. A new kind of mushroom is a new file
## and an icon, nothing else (rule 3).
##
## On the ground it shows its own icon, so it needs no second picture.
##

## The seasons it can be found in, by id (&"autumn"). Empty: never.
@export var seasons: Array[StringName] = []

## The locations it grows in, by id. The Woods for now.
@export var found_in: Array[StringName] = [&"woods"]

## How likely it is, against the other forage that could be there: 10 is
## common, 3 is a lucky find. Only the ratio between them matters.
@export var weight: int = 10

## Only on days with one of these weathers (by id), such as worms, which come
## up when it rains. Empty: any weather.
@export var only_in_weather: Array[StringName] = []

## --- The Cove (DECISIONS 064) -----------------------------------------------------

## True for something that lives in the rockpools and on the sand bar
## (shrimps, mussels): it turns up only on the spots the sea uncovers at low
## tide (LocationDef.low_tide_forage_per_day of them), and can only be picked
## while the tide is out. False: the ordinary spots (a beach's strand line,
## the Woods, the hedgerows).
@export var at_low_tide: bool = false

## What picking it up puts in the bag, if not itself: driftwood is timber.
## Null: the forage itself (a mushroom is a mushroom).
@export var gives: ItemDef

## How many of `gives` it puts in the bag.
@export var gives_count: int = 1


## True if it can be found in `location_id` on a day of `season_id` with
## `weather_id`.
func grows(location_id: StringName, season_id: StringName, weather_id: StringName) -> bool:
	if weight <= 0 or location_id not in found_in or season_id not in seasons:
		return false
	return only_in_weather.is_empty() or weather_id in only_in_weather
