extends Node
##
## TimeSystem — decides when a day ends, and runs the overnight sequence.
##
## A day ends in one of two ways (DECISIONS 002, 003): the player chooses to
## sleep, or their energy runs out. Either way the same thing happens, in a
## fixed order:
##
##   1. day_ended is announced — anything that needs to settle up against
##      *today* does it now. Economy sells the shipping bin here.
##   2. The farm grows: watered crops advance, soil dries, sprinklers water.
##   3. The calendar moves on and energy refills.
##   4. If that started a new season: crops that can't grow in it die, and
##      season_changed is announced — the farm repaints itself for the season.
##   5. day_started is announced — the farm redraws, the HUD updates.
##   6. The game is saved. Last, so the save is the finished morning: crops
##      grown, energy full. Loading it puts you exactly at the start of a day.
##
## Keeping that order in one place is the point of this file. One consequence
## worth knowing: an out-of-season crop still in the ground on the last night
## of the season dies, even if that night's growth (step 2) would have ripened
## it. Anything ready has to be picked before sleeping on the last day.
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
	var season_turned := GameState.advance_calendar()
	EventBus.energy_changed.emit(GameState.energy, GameState.max_energy)
	if season_turned:
		GameState.farm.wither_out_of_season(GameState.season_id())
		EventBus.season_changed.emit(GameState.season)
	EventBus.day_started.emit(GameState.day, GameState.season, GameState.year)
	SaveSystem.save_game()
	_ending_day = false
