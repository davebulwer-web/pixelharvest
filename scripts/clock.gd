class_name Clock
extends RefCounted
##
## Clock — turns the game's time of day into words, and back.
##
## The game keeps time as minutes after midnight (GameState.minutes), which is
## easy to add to and compare. People read "9:30 AM". This is the one place
## that converts, so the HUD, the shops and the notice board all agree.
##
## It touches no autoload, so resources (ShopDef) can use it safely
## (DECISIONS 021: game_rules.tres loads them before the autoloads exist).
##

const MINUTES_PER_DAY := 1440


## "6:00 AM", "12:30 PM", "1:10 AM". Past midnight (1500) wraps round to the
## small hours, because that's what a clock on the wall would show.
static func format(minutes: int) -> String:
	var in_day := posmod(minutes, MINUTES_PER_DAY)
	var hour := in_day / 60
	var minute := in_day % 60
	var suffix := "AM" if hour < 12 else "PM"
	var shown_hour := hour % 12
	if shown_hour == 0:
		shown_hour = 12
	return "%d:%02d %s" % [shown_hour, minute, suffix]


## "9 AM", "5 PM", "9:30 AM": a time without ":00" when it's on the hour,
## for opening hours, which read better short.
static func format_short(minutes: int) -> String:
	var text := format(minutes)
	return text.replace(":00", "")
