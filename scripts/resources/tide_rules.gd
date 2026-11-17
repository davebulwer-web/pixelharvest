class_name TideRules
extends Resource
##
## TideRules — the numbers behind the Cove's tides (DECISIONS 064).
##
## The sea goes out and comes in twice a day, a little later each day, like a
## real tide: one full rise and fall takes `period_minutes` (12 hours 25
## minutes), so two of them take 50 minutes longer than a day, and each low
## tide comes 50 minutes later than the day before. Nothing about it is saved
## or rolled: the tide at any moment is worked out from the date and the
## clock (Tides, scripts/cove/tides.gd), so a save, a reload or a walk in and
## out of the Cove can never put it wrong.
##
## While the tide is out (`low_window_minutes` either side of low water) the
## rockpools, the wet sand and the sand bar are uncovered and can be walked
## on and picked over; the rest of the time they're under the sea.
##
## One file, data/tide_rules.tres, which game_rules.tres points at, so
## tuning the tides never means touching code (rule 6).
##
## Must not use the GameState autoload: game_rules.tres preloads this file,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

## One rise and fall of the tide, low water to low water, in game minutes.
## 745 (12 h 25 min) is the real sea's, and makes each day's low tides 50
## minutes later than the day before's.
@export var period_minutes: int = 745

## The first low tide of the game: minutes after midnight on spring day 1 of
## year 1. Every low tide after it is a whole number of periods on.
@export var first_low_minute: int = 620

## How long either side of low water the rockpools and the sand bar are
## uncovered, in game minutes. 90: three hours of low tide, twice a day.
@export var low_window_minutes: int = 90
