class_name ScheduleDef
extends Resource
##
## ScheduleDef — where someone is through the day (DECISIONS 067, ROADMAP
## 13.4): their home, and a plan for each kind of day. Set on a CharacterDef
## (`schedule`); someone without one stands where their `spots` say, all
## day, as everyone did before Stage 22.
##
## Nothing about it is saved: where a person is follows from the date, the
## weekday, the weather and the clock (Schedules), the same way market day
## and the tides do. Off the map you're on, nobody is simulated; when you
## arrive somewhere, everyone who should be there is already standing in
## their place. On the map you're on, they walk.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## Where they are before the day's first stop, and on a day no plan fits: a
## building's LocationDef id (their home), or empty for "away".
@export var home: StringName = &""

## What the request log says while they're at home: "at home".
@export var home_words: String = "at home"

## The plans, most particular first: the first that fits today is used.
@export var plans: Array[DayPlan] = []


## The plan for a day that's `weekday`, in `season_id`, with `weather_id`,
## or null if none fits (then they're home all day).
func plan_for(weekday: int, season_id: StringName, weather_id: StringName) -> DayPlan:
	for plan in plans:
		if plan != null and plan.fits(weekday, season_id, weather_id):
			return plan
	return null
