class_name Schedules
extends RefCounted
##
## Schedules — where everyone is, worked out from the clock (DECISIONS 067,
## ROADMAP 13.4).
##
## Nothing here is saved and nothing is simulated off-screen: a person's
## whereabouts are a function of today's date, weekday, season and weather
## and the time, read off their ScheduleDef, the same way market day and the
## tides are worked out. So a person can't get lost somewhere you aren't, and
## arriving anywhere shows everyone already in their place. The map you're on
## makes them walk between stops (PeopleHere); this only says where they
## should be.
##
## Weekdays: spring day 1 of year 1 is a Monday, and the days run on from
## there. With 28-day seasons, every season starts on a Monday, and market
## day (every 7 days from day 3) is always a Wednesday.
##
## Static functions only: there's no state to keep, so no autoload.
##

const WEEKDAY_NAMES: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
		"Saturday", "Sunday"]

## How long before a time someone has to be findable for a parcel to be
## handed to them by then (Dot's errands): the whole of the hour before.
const FINDABLE_FOR := 60


## The weekday of day `number` (GameState.day_number): 0 Monday … 6 Sunday.
static func weekday(number: int) -> int:
	return posmod(number - 1, 7)


static func weekday_name(number: int) -> String:
	return WEEKDAY_NAMES[weekday(number)]


## "Mon", "Tue"…: for the HUD's date.
static func weekday_short(number: int) -> String:
	return weekday_name(number).substr(0, 3)


## Where `person` is today at `minute`: a ScheduleStop, never null. Its place
## is empty when they're nowhere to be found (not arrived yet, or away).
static func stop_at(person: CharacterDef, minute: int) -> ScheduleStop:
	if not GameState.has_unlock(person.requires_unlock):
		return _away()
	# A festival's host is at the festival all day (DECISIONS 059).
	var event := Festivals.hosted_by(person.id)
	if event != null:
		return _stop(event.location, event.host_cell, "at the %s" % event.display_name.to_lower())
	if person.schedule == null:
		if person.spots.is_empty():
			return _away()
		return _stop(person.location, person.spot_on(GameState.day), "")
	var plan := todays_plan(person)
	var stop: ScheduleStop = plan.stop_at(minute) if plan != null else null
	if stop == null:
		return _home(person.schedule)
	return stop


## Where `person` is now.
static func stop_now(person: CharacterDef) -> ScheduleStop:
	return stop_at(person, GameState.minutes)


## The plan `person` follows today, or null (no schedule, or none fits).
static func todays_plan(person: CharacterDef) -> DayPlan:
	if person.schedule == null:
		return null
	# The first plan that fits today and has been earned (DayPlan.requires_unlock:
	# the tavern evenings wait for the tavern to open; DECISIONS 068).
	var day := weekday(GameState.day_number())
	for plan in person.schedule.plans:
		if plan != null and plan.fits(day, GameState.season_id(), GameState.weather_id()) \
				and GameState.has_unlock(plan.requires_unlock):
			return plan
	return null


## Everyone whose stop at `minute` is `place` (an outdoor map or a building),
## by id order.
static func people_at(place: StringName, minute: int = -1) -> Array[CharacterDef]:
	if minute < 0:
		minute = GameState.minutes
	var result: Array[CharacterDef] = []
	for person in ContentDB.characters():
		if stop_at(person, minute).place == place:
			result.append(person)
	return result


## True if a parcel or a request can be handed to `person` at `minute`:
## they're on a map, at home (knock on the door), or behind a counter that's
## open. Away, or in a shop that's shut, they can't be reached.
static func reachable_at(person: CharacterDef, minute: int) -> bool:
	var place := stop_at(person, minute).place
	if place == &"":
		return false
	var location := LocationManager.find(place)
	if location == null or location.outside == &"" or not location.has_inside():
		return true  # an outdoor map, or a home to knock at
	if location.shop != null:
		return location.shop.is_open_at(minute)
	return true


## True if `person` can be found all through the hour before `minute`
## (Dot's errands: a parcel can be due to them by then).
static func findable_before(person: CharacterDef, minute: int) -> bool:
	var step := 10
	var at := minute - FINDABLE_FOR
	while at < minute:
		if not reachable_at(person, at):
			return false
		at += step
	return true


## Where `person` is now and what's next, for the request log: "by the
## fountain in town until 2 PM, then at the bakery". Empty for someone
## without a schedule (they're always where they always are).
static func whereabouts(person: CharacterDef) -> String:
	if person.schedule == null and Festivals.hosted_by(person.id) == null:
		return ""
	var now := stop_now(person)
	var text := describe(person, now)
	var plan := todays_plan(person)
	if plan == null or Festivals.hosted_by(person.id) != null:
		return text
	var next_at := plan.next_change_after(GameState.minutes)
	if next_at < 0:
		return text
	var next := stop_at(person, next_at)
	return "%s until %s, then %s" % [text, Clock.format_short(next_at), describe(person, next)]


## A stop in words: its own words, or "at home", "away", or the place's name.
static func describe(person: CharacterDef, stop: ScheduleStop) -> String:
	if stop.words != "":
		return stop.words
	if stop.place == &"":
		return "away"
	if person.schedule != null and stop.place == person.schedule.home:
		return person.schedule.home_words
	var location := LocationManager.find(stop.place)
	if location == null:
		return String(stop.place)
	return ("at %s" if location.outside != &"" else "in %s") % location.display_name


## The outdoor map a place is on: itself for a map, its outside for a
## building, empty for "away".
static func map_of(place: StringName) -> StringName:
	if place == &"":
		return &""
	var location := LocationManager.find(place)
	if location == null:
		return &""
	return location.outside if location.outside != &"" else place


## On the way from map `from` to map `to`, which map comes next: a walk
## along the roads (every LocationDef's exits, taken both ways), shortest
## first. Empty if there's no way, or they're the same.
static func next_map(from: StringName, to: StringName) -> StringName:
	if from == to or from == &"" or to == &"":
		return &""
	var links := _road_links()
	var came_from: Dictionary = {from: &""}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var here: StringName = queue.pop_front()
		if here == to:
			break
		for there: StringName in links.get(here, []):
			if not came_from.has(there):
				came_from[there] = here
				queue.append(there)
	if not came_from.has(to):
		return &""
	var step := to
	while came_from[step] != from:
		step = came_from[step]
	return step


## Every map's neighbours along the roads.
static func _road_links() -> Dictionary:
	var links: Dictionary = {}
	for location in LocationManager.all():
		for exit in location.exits:
			if exit == null:
				continue
			_link(links, location.id, exit.to)
			_link(links, exit.to, location.id)
	return links


static func _link(links: Dictionary, a: StringName, b: StringName) -> void:
	if not links.has(a):
		links[a] = []
	if b not in links[a]:
		links[a].append(b)


static func _home(schedule: ScheduleDef) -> ScheduleStop:
	return _stop(schedule.home, Vector2i.ZERO, "")


static func _away() -> ScheduleStop:
	return _stop(&"", Vector2i.ZERO, "")


static func _stop(place: StringName, cell: Vector2i, words: String) -> ScheduleStop:
	var stop := ScheduleStop.new()
	stop.place = place
	stop.cell = cell
	stop.words = words
	return stop
