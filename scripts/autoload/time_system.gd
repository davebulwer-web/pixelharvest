extends Node
##
## TimeSystem — decides when a day ends, and runs the overnight sequence.
##
## A day ends in one of two ways (DECISIONS 002, 003): the player chooses to
## sleep, or their energy runs out. Either way the same thing happens, in a
## fixed order:
##
##   1. day_ended is announced — anything that needs to settle up against
##      *today* (the shipping bin, in Stage 4) does it now.
##   2. The farm grows: watered crops advance, soil dries.
##   3. The calendar moves on and energy refills.
##   4. day_started is announced — the farm redraws, the HUD updates.
##
## Keeping that order in one place is the point of this file. Season rollover
## joins step 3 in Stage 6.
##

## Guards against two triggers landing together, e.g. the last point of energy
## spent on the same frame the player presses sleep.
var _ending_day: bool = false


func _ready() -> void:
	# Deferred so the action that spent the last energy finishes first —
	# otherwise the crop you just watered would dry out before it was watered.
	EventBus.energy_exhausted.connect(end_day, CONNECT_DEFERRED)


func end_day() -> void:
	if _ending_day:
		return
	_ending_day = true
	EventBus.day_ended.emit(GameState.day)
	GameState.farm.advance_day()
	GameState.start_next_day()
	_ending_day = false
