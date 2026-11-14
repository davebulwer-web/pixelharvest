extends Node
##
## GameState — the player's progress: gold, the calendar, energy, tools, and
## the farm itself.
##
## It's an autoload so it outlives any one scene. When Stage 7 adds the town,
## walking there swaps the scene but not this — the farm, the gold and the day
## all come along. That's the persistence half of the LocationManager seam
## (DECISIONS 004).
##
## Everything that changes here is announced on EventBus, so the HUD, quests
## and anything else can react without holding a reference to GameState.
##
## Stage 3 will serialise exactly what's in this file. Anything not reachable
## from here won't be saved — a useful test of whether state is in the right
## place.
##

const RULES: GameRules = preload("res://data/game_rules.tres")

var gold: int = 0
var day: int = 1
var season: int = 0
var year: int = 1

var energy: float = 0.0
var max_energy: float = 0.0

var tools: Array[ToolDef] = []
var _selected_tool_index: int = 0

var farm: FarmData

## Where the player is. LocationManager changes it; Stage 3 saves it, so a
## loaded game opens in the right place.
var location: StringName = &""


func _ready() -> void:
	new_game()


## Reset everything to the starting state in GameRules.
## Stage 3 adds the other way in: loading a save.
func new_game() -> void:
	gold = RULES.starting_gold
	day = 1
	season = 0
	year = 1
	max_energy = RULES.max_energy
	energy = max_energy
	tools = RULES.starting_tools.duplicate()
	_selected_tool_index = 0
	farm = FarmLayout.build_default()
	location = RULES.starting_location


## Move the calendar on one day and refill energy. Called by TimeSystem as
## part of the overnight sequence — nothing else should call it.
func start_next_day() -> void:
	day += 1
	energy = max_energy
	EventBus.energy_changed.emit(energy, max_energy)
	EventBus.day_started.emit(day, season, year)


## How the current season looks. Seasons beyond the list wrap round, so a
## calendar with more seasons than themes still draws something.
func current_season_theme() -> SeasonTheme:
	if RULES.seasons.is_empty():
		return null
	return RULES.seasons[posmod(season, RULES.seasons.size())]


# --- Energy ------------------------------------------------------------------

## Pay `amount` of energy if there's enough. Returns false and changes nothing
## if there isn't, so an action the player can't afford simply doesn't happen.
## Hitting zero announces energy_exhausted, which TimeSystem turns into the
## end of the day.
func try_spend_energy(amount: float) -> bool:
	if amount > energy:
		return false
	energy -= amount
	EventBus.energy_changed.emit(energy, max_energy)
	if energy <= 0.0:
		EventBus.energy_exhausted.emit()
	return true


# --- Tools -------------------------------------------------------------------

## The tool in the player's hands, or null if they have none.
func selected_tool() -> ToolDef:
	if tools.is_empty():
		return null
	return tools[_selected_tool_index]


## Move along the toolbar by `step` (+1 next, -1 previous), wrapping round.
func cycle_tool(step: int) -> void:
	if tools.is_empty():
		return
	_selected_tool_index = posmod(_selected_tool_index + step, tools.size())
	EventBus.tool_selected.emit(selected_tool().id)
