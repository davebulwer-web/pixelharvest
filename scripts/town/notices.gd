class_name Notices
extends RefCounted
##
## Notices — what's pinned on the town's notice board today, in words.
##
## Nothing here is stored: every notice is worked out from the calendar and
## the content when the board is read, so a new crop shows up on the board
## the day it's added to data/crops/, with nothing edited here (rule 3).
## Calendar events (market day) get a page of their own, worked out the same
## way from data/events/ (DECISIONS 037).
##

## How close to the end of a season the board starts warning that crops
## still in the ground will die (DECISIONS 025).
const WARN_DAYS := 3

## How far ahead the board pins up what the calendar will open (DECISIONS
## 043): "Coming soon: Brann's forge reopens, in 5 days".
const SOON_DAYS := 7


## Today's notices, one per page of the dialogue box.
static func today() -> Array[String]:
	var notices: Array[String] = []
	notices.append(_calendar())
	for event in ContentDB.events():
		var text := _event_notice(event)
		if text != "":
			notices.append(text)
	var requests := _requests()
	if requests != "":
		notices.append(requests)
	var soon := _opening_soon()
	if soon != "":
		notices.append(soon)
	notices.append(_in_season())
	notices.append(_coming_up())
	var hours := _opening_hours()
	if hours != "":
		notices.append(hours)
	return notices


## "Spring, day 5 of 28, year 1. 23 days of spring left." — or, near the end,
## a warning.
static func _calendar() -> String:
	var season := GameState.season_name(GameState.season_id())
	var length := GameState.RULES.days_per_season
	var left := length - GameState.day
	var text := "%s, day %d of %d, year %d. " % [season, GameState.day, length, GameState.year]
	if left == 0:
		return text + "Last day of %s! Anything still growing tonight that can't take %s dies." \
				% [season.to_lower(), _next_season_name().to_lower()]
	if left <= WARN_DAYS:
		return text + "%s ends in %d %s. Crops still growing then that can't take %s will die." \
				% [season, left, "day" if left == 1 else "days", _next_season_name().to_lower()]
	return text + "%d days of %s left." % [left, season.to_lower()]


## "Market day today! Stalls in the square … Open 8 AM – 2 PM." or "Next
## market day: in 3 days, spring day 10." "" if it isn't coming within a year.
static func _event_notice(event: CalendarEvent) -> String:
	var ahead := GameState.days_until(event)
	if ahead < 0:
		return ""
	if ahead == 0:
		var text := "%s today! %s" % [event.display_name, event.description]
		var hours := _event_hours(event)
		if hours != "":
			text += " Open %s." % hours
		return text
	var number := GameState.day_number() + ahead
	var length := GameState.RULES.days_per_season
	var when := "tomorrow" if ahead == 1 else "in %d days" % ahead
	return "Next %s: %s, %s day %d. %s" % [event.display_name.to_lower(), when,
			GameState.season_name(GameState.season_id_on(number)).to_lower(),
			posmod(number - 1, length) + 1, event.description]


## The hours of an event's first stall that keeps hours ("8 AM – 2 PM"), or "".
static func _event_hours(event: CalendarEvent) -> String:
	for stall in event.stalls:
		if stall != null and stall.shop != null and stall.shop.keeps_hours():
			return stall.shop.hours_text()
	return ""


## "In season now: Parsnip, Potato and Radish. Seeds at Hollis's Seeds. Rare
## seeds at Fennel's Seed Cart: Strawberry." Seeds sold only at one place (a
## market stall) are listed with where to find them.
static func _in_season() -> String:
	var season_id := GameState.season_id()
	var season := GameState.season_name(season_id).to_lower()
	var everyday: Array[String] = []
	var special: Dictionary = {}  # where they're sold -> Array of crop names
	for crop in ContentDB.crops():
		if not crop.grows_in(season_id):
			continue
		var seeds := ContentDB.seeds_for(crop)
		# Seeds no shop has in yet (DECISIONS 043) aren't advertised.
		if seeds != null and not GameState.has_unlock(seeds.requires_unlock):
			continue
		if seeds == null or seeds.sold_only_by.is_empty():
			everyday.append(crop.display_name)
			continue
		var where := _shop_names(seeds.sold_only_by)
		if not special.has(where):
			special[where] = [] as Array[String]
		special[where].append(crop.display_name)
	if everyday.is_empty() and special.is_empty():
		return "Nothing grows in %s. A good time to plan, and to save up." % season
	var text := ""
	if not everyday.is_empty():
		text = "In season now: %s." % _list(everyday)
		var seed_shop := _seed_shop_name()
		if seed_shop != "":
			text += " Seeds at %s." % seed_shop
	for where: String in special:
		text += " Rare seeds from %s: %s." % [where, _list(special[where])]
	return text.strip_edges()


## "Fennel's Seed Cart", or "A and B": shop ids in words.
static func _shop_names(shop_ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for id in shop_ids:
		var shop_def := ContentDB.shop(id)
		names.append(shop_def.display_name if shop_def != null else String(id))
	return _list(names)


## "Coming in summer: Green bean and Cabbage."
static func _coming_up() -> String:
	var next_id := _next_season_id()
	var next_name := _next_season_name()
	var names := _crops_in(next_id)
	if names.is_empty():
		return "Nothing grows in %s. Harvest what you can before it comes." % next_name.to_lower()
	return "Coming in %s: %s." % [next_name.to_lower(), _list(names)]


static func _crops_in(season_id: StringName) -> Array[String]:
	var names: Array[String] = []
	for crop in ContentDB.crops():
		if crop.grows_in(season_id):
			names.append(crop.display_name)
	return names


static func _next_season_id() -> StringName:
	var seasons := GameState.RULES.seasons
	if seasons.is_empty():
		return &""
	return seasons[posmod(GameState.season + 1, seasons.size())].id


static func _next_season_name() -> String:
	return GameState.season_name(_next_season_id())


## "Opening hours: Hollis's Seeds 9 AM – 5 PM, …" for every shop that keeps
## hours, in game_rules.tres order (DECISIONS 035). "" if none does.
static func _opening_hours() -> String:
	var parts: Array[String] = []
	for location in LocationManager.all():
		if location.shop != null and location.shop.keeps_hours():
			parts.append("%s %s" % [location.shop.display_name, location.shop.hours_text()])
	if parts.is_empty():
		return ""
	return "Opening hours: %s." % ", ".join(parts)


## The name of the first shop that sells seeds, or "" if none does.
static func _seed_shop_name() -> String:
	for location in LocationManager.all():
		if location.shop != null and location.shop.sells_seeds:
			return location.shop.display_name
	return ""


## "Wanted: a hand for Mabel and Pip. Look for the ! over their heads." —
## everyone with a request to make today (DECISIONS 038), or "" if nobody has.
static func _requests() -> String:
	var names: Array[String] = []
	for id in Quests.givers_with_offers():
		var person := ContentDB.character(id)
		names.append(person.display_name if person != null else String(id))
	if names.is_empty():
		return ""
	return "Wanted: a hand for %s. Look for the ! over %s." % [_list(names),
			"their heads" if names.size() > 1 else "their head"]


## "Coming soon: Brann's forge reopens, in 3 days (spring day 8)." Every
## unlock the calendar opens within SOON_DAYS that isn't open yet, or "".
static func _opening_soon() -> String:
	var parts: Array[String] = []
	var today := GameState.day_number()
	var length := GameState.RULES.days_per_season
	for each in ContentDB.unlocks():
		if not each.opens_by_date() or GameState.has_unlock(each):
			continue
		var ahead := each.on_day - today
		if ahead < 1 or ahead > SOON_DAYS:
			continue
		var when := "tomorrow" if ahead == 1 else "in %d days" % ahead
		parts.append("%s, %s (%s day %d)" % [each.display_name, when,
				GameState.season_name(GameState.season_id_on(each.on_day)).to_lower(),
				posmod(each.on_day - 1, length) + 1])
	if parts.is_empty():
		return ""
	var text := "; ".join(parts)
	return "Coming soon: %s." % (text.left(1).to_upper() + text.substr(1))


## "A", "A and B", "A, B and C".
static func _list(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
