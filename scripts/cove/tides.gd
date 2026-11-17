class_name Tides
extends RefCounted
##
## Tides — when the sea at the Cove is out (DECISIONS 064).
##
## The tide is a pure function of the date and the clock, like market day
## (DECISIONS 037) and the day's forage (DECISIONS 052): nothing about it is
## saved or rolled. Low water comes every `period_minutes` (TideRules: 12
## hours 25 minutes), counting from the first low tide of the game, so two
## low tides a day, each day's 50 minutes later than the day before's. For
## `low_window_minutes` either side of low water the tide is out: the
## rockpools, the wet sand and the sand bar are uncovered.
##
## Times here are "game minutes since the game began": day_number 1 at
## midnight is 0. A day's own minutes (GameState.minutes) run past 1440 after
## midnight (the game's day ends at 2 AM), which this counts on naturally:
## 1:00 AM after day 3 is day 3's minute 1500, the same moment as day 4's 60.
##
## The Cove scene asks is_out() as the clock moves and floods or uncovers
## the shore; the notice board, the morning summary and the Cove's tide
## board ask for the day's low tides in words.
##

const MINUTES_PER_DAY := 1440


static func _rules() -> TideRules:
	return GameState.RULES.tides


## Minutes since the game began, for `minute` of day `day_number`.
static func moment(day_number: int, minute: int) -> int:
	return (day_number - 1) * MINUTES_PER_DAY + minute


## The moment of the low water nearest `at` (before or after it).
static func nearest_low(at: int) -> int:
	var rules := _rules()
	if rules == null or rules.period_minutes <= 0:
		return 0
	var periods := roundi(float(at - rules.first_low_minute) / rules.period_minutes)
	return rules.first_low_minute + periods * rules.period_minutes


## True if the tide is out at moment `at`: within the low window of a low
## water. With no tide rules, never.
static func is_out_at(at: int) -> bool:
	var rules := _rules()
	if rules == null or rules.period_minutes <= 0:
		return false
	return absi(at - nearest_low(at)) <= rules.low_window_minutes


## True if the tide is out now.
static func is_out() -> bool:
	return is_out_at(moment(GameState.day_number(), GameState.minutes))


## The low tides in the waking day `day_number` (from the day's start to its
## end, 6 AM to 2 AM), as that day's minutes (past 1440 after midnight), in
## order. One or two of them.
static func lows_on(day_number: int) -> Array[int]:
	var result: Array[int] = []
	var rules := _rules()
	if rules == null or rules.period_minutes <= 0:
		return result
	var start := moment(day_number, GameState.RULES.day_start_minutes)
	var end := moment(day_number, GameState.RULES.day_end_minutes)
	var low := nearest_low(start)
	if low < start:
		low += rules.period_minutes
	while low <= end:
		result.append(low - moment(day_number, 0))
		low += rules.period_minutes
	return result


## When the tide is out now, the minute (of today) it comes back in; when
## it's in, the minute today's next low tide uncovers the rockpools, or -1 if
## there's none before the day ends. Today's minutes, as GameState.minutes.
static func next_turn() -> int:
	var rules := _rules()
	if rules == null or rules.period_minutes <= 0:
		return -1
	var day_zero := moment(GameState.day_number(), 0)
	var now := day_zero + GameState.minutes
	var low := nearest_low(now)
	if is_out_at(now):
		return low + rules.low_window_minutes - day_zero
	if low < now:
		low += rules.period_minutes
	var uncovers := low - rules.low_window_minutes
	if uncovers - day_zero > GameState.RULES.day_end_minutes:
		return -1
	return uncovers - day_zero


## "Low tide at the Cove today: 10:20 AM and 10:45 PM. The rockpools and the
## sand bar are uncovered for an hour and a half either side." — for the
## notice board and the morning summary. "" with no tides.
static func today_text() -> String:
	return day_text(GameState.day_number())


## today_text() for day `day_number`. `short`: only "Low tide at the Cove:
## 10:20 AM and 10:45 PM.", for the morning summary.
static func day_text(day_number: int, short: bool = false) -> String:
	var lows := lows_on(day_number)
	if lows.is_empty():
		return ""
	var times: Array[String] = []
	for low in lows:
		times.append(Clock.format(low))
	if short:
		return "Low tide at the Cove: %s." % " and ".join(times)
	return "Low tide at the Cove today: %s. The rockpools and the sand bar are uncovered for %s either side." \
			% [" and ".join(times), _span(_rules().low_window_minutes)]


## What the tide is doing now, for walking into the Cove or reading its tide
## board: "The tide's out until 11:50 AM." / "The tide's in. The rockpools
## uncover at 8:50 PM." / "The tide's in, and won't be out again before
## morning." "" with no tides.
static func now_text() -> String:
	if _rules() == null:
		return ""
	var turn := next_turn()
	if is_out():
		return "The tide's out until %s." % Clock.format(turn)
	if turn < 0:
		return "The tide's in, and won't be out again before morning."
	return "The tide's in. The rockpools uncover at %s." % Clock.format(turn)


## "an hour and a half", "2 hours", "45 minutes".
static func _span(minutes: int) -> String:
	if minutes == 90:
		return "an hour and a half"
	if minutes == 60:
		return "an hour"
	if minutes % 60 == 0:
		return "%d hours" % (minutes / 60)
	if minutes < 60:
		return "%d minutes" % minutes
	return "%d hours %d minutes" % [minutes / 60, minutes % 60]
