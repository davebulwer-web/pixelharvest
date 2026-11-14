class_name Notices
extends RefCounted
##
## Notices — what's pinned on the town's notice board today, in words.
##
## Nothing here is stored: every notice is worked out from the calendar and
## the content when the board is read, so a new crop shows up on the board
## the day it's added to data/crops/, with nothing edited here (rule 3).
## Stage 8 will add notices of its own (market days, requests) by listening
## for the same EventBus.notice_board_read.
##

## How close to the end of a season the board starts warning that crops
## still in the ground will die (DECISIONS 025).
const WARN_DAYS := 3


## Today's notices, one per page of the dialogue box.
static func today() -> Array[String]:
	var notices: Array[String] = []
	notices.append(_calendar())
	notices.append(_in_season())
	notices.append(_coming_up())
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


## "In season now: Parsnip, Potato and Radish. Seeds at Hollis's Seeds."
static func _in_season() -> String:
	var names := _crops_in(GameState.season_id())
	var season := GameState.season_name(GameState.season_id()).to_lower()
	if names.is_empty():
		return "Nothing grows in %s. A good time to plan, and to save up." % season
	var text := "In season now: %s." % _list(names)
	var seed_shop := _seed_shop_name()
	if seed_shop != "":
		text += " Seeds at %s." % seed_shop
	return text


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


## The name of the first shop that sells seeds, or "" if none does.
static func _seed_shop_name() -> String:
	for location in LocationManager.all():
		if location.shop != null and location.shop.sells_seeds:
			return location.shop.display_name
	return ""


## "A", "A and B", "A, B and C".
static func _list(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
