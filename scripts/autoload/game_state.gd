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
## The save file is exactly what's in this file (to_save / load_from_save
## below). Anything not reachable from here isn't saved — a useful test of
## whether state is in the right place.
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

## Where the player is. LocationManager changes it; it's saved, so a loaded
## game opens in the right place.
var location: StringName = &""


func _ready() -> void:
	# Always start from a valid new game, so the farm scene can be run on its
	# own with F6. When the game is launched properly, the boot scene then asks
	# SaveSystem to replace this with the saved game, if there is one.
	new_game()


## Reset everything to the starting state in GameRules. The other way in is
## load_from_save().
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


# --- Saving ------------------------------------------------------------------
# GameState says WHAT is saved; SaveSystem decides where, when, and how old
# saves are upgraded. Resources (tools, crops) are saved as their ids and looked
# up again in ContentDB, because a save file can only hold plain values.
#
# There's no player position: the game saves at the start of a day, and every
# day starts with the player at the spawn point.
#
# Inventory and upgrades join this when they exist (Stages 4 and 5), each as a
# new field plus a save-version bump.

func to_save() -> Dictionary:
	var tool_ids: Array = []
	for tool_def in tools:
		tool_ids.append(String(tool_def.id))
	var selected := selected_tool()
	return {
		"gold": gold,
		"day": day,
		"season": season,
		"year": year,
		"energy": energy,
		"max_energy": max_energy,
		"tools": tool_ids,
		"selected_tool": String(selected.id) if selected != null else "",
		"location": String(location),
		"farm": farm.to_save(),
	}


## Replace the current game with a saved one. `data` has already been upgraded
## to the current save version and checked by SaveSystem, so every field is
## there. What can still be wrong is content that has since left the game: a
## tool nobody defines any more is dropped, and if that leaves no tools at all
## the starting kit is handed out again.
func load_from_save(data: Dictionary) -> void:
	# JSON keeps every number as a float, hence the int() calls.
	gold = int(data["gold"])
	day = int(data["day"])
	season = int(data["season"])
	year = int(data["year"])
	energy = float(data["energy"])
	max_energy = float(data["max_energy"])

	tools.clear()
	for tool_id: String in data["tools"]:
		var tool_def := ContentDB.tool(StringName(tool_id))
		if tool_def == null:
			push_warning("Save has a tool '%s' the game doesn't know; it's been removed" % tool_id)
			continue
		tools.append(tool_def)
	if tools.is_empty():
		tools = RULES.starting_tools.duplicate()
	_selected_tool_index = maxi(0, _tool_index(StringName(data["selected_tool"])))

	location = StringName(data["location"])
	if not RULES.locations.any(func(l: LocationDef) -> bool: return l.id == location):
		push_warning("Save is at an unknown location '%s'; starting at the farm" % location)
		location = RULES.starting_location

	farm = FarmData.from_save(data["farm"])


## Position of the tool with `tool_id` on the toolbar, or -1.
func _tool_index(tool_id: StringName) -> int:
	for i in tools.size():
		if tools[i].id == tool_id:
			return i
	return -1
