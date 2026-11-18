class_name DayPlan
extends Resource
##
## DayPlan — how someone spends one kind of day (DECISIONS 067): a list of
## stops through the day, and which days it's for: some weekdays, some
## seasons, some weathers. "Pip, on a school day: in town from 9, by the
## ford from 3, home at 7." "Pip, in the rain: indoors."
##
## A ScheduleDef has several; the first whose conditions fit today is the
## one used, so a rainy-day plan goes before the everyday one.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## Which weekdays this plan is for: 0 Monday … 6 Sunday (Weekdays). Empty:
## any day.
@export var weekdays: Array[int] = []

## Which seasons, by SeasonTheme id. Empty: any season.
@export var seasons: Array[StringName] = []

## Which weathers, by WeatherDef id (&"rain", &"storm"). Empty: any weather.
@export var weathers: Array[StringName] = []

## The day's stops, in time order. Before the first, they're at home (the
## ScheduleDef's `home`).
@export var stops: Array[ScheduleStop] = []


## True if this plan is for a day that's `weekday` (0–6), in `season_id`,
## with `weather_id`.
func fits(weekday: int, season_id: StringName, weather_id: StringName) -> bool:
	if not weekdays.is_empty() and weekday not in weekdays:
		return false
	if not seasons.is_empty() and season_id not in seasons:
		return false
	if not weathers.is_empty() and weather_id not in weathers:
		return false
	return true


## The stop in force at `minute`, or null before the first one.
func stop_at(minute: int) -> ScheduleStop:
	var found: ScheduleStop = null
	for stop in stops:
		if stop != null and stop.at <= minute and (found == null or stop.at >= found.at):
			found = stop
	return found


## The time of the first stop after `minute`, or -1 if there's none today.
func next_change_after(minute: int) -> int:
	var next := -1
	for stop in stops:
		if stop != null and stop.at > minute and (next < 0 or stop.at < next):
			next = stop.at
	return next
