extends Node
##
## GameState — the player's progress: gold, the calendar, energy, the bag of
## items, and the farm itself.
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

## Everything the player is carrying: tools, seeds and produce.
var inventory: Inventory

## What's been put in the shipping bin today. Economy sells it overnight, so
## it's always empty by the time the game saves at dawn — which is why it
## isn't in the save file (DECISIONS 023).
var shipping_bin: Inventory

## The hotbar selection, remembered by id so it survives items coming and
## going around it. _selected_slot is the fallback for when the selected item
## itself runs out (the last packet of seeds): the selection then stays in the
## same place on the hotbar rather than jumping back to the start.
var _selected_tool_id: StringName = &""
var _selected_slot: int = 0

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
	inventory = Inventory.new(true)
	_give_starting_kit()
	shipping_bin = Inventory.new()
	_selected_tool_id = &""
	_selected_slot = 0
	farm = FarmLayout.build_default()
	location = RULES.starting_location


func _give_starting_kit() -> void:
	for item: ItemDef in RULES.starting_inventory:
		inventory.add(item, RULES.starting_inventory[item])


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


# --- Gold --------------------------------------------------------------------
# What things cost is Economy's business; GameState only keeps the purse.

func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold += amount
	EventBus.gold_changed.emit(gold, amount)


## Pay `amount` if there's enough. Returns false and changes nothing if not.
func try_spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold, -amount)
	return true


# --- The hotbar --------------------------------------------------------------
# The hotbar is not a separate list: it's every item in the bag that can be
# used on a tile (a ToolDef), in bag order. Buying a new kind of seed puts it
# on the hotbar; planting the last one takes it off.

## The usable items, left to right.
func hotbar() -> Array[ToolDef]:
	var result: Array[ToolDef] = []
	for item in inventory.items():
		if item is ToolDef:
			result.append(item)
	return result


## The tool in the player's hands, or null if they have none.
func selected_tool() -> ToolDef:
	var bar := hotbar()
	if bar.is_empty():
		return null
	for i in bar.size():
		if bar[i].id == _selected_tool_id:
			_selected_slot = i
			return bar[i]
	# The selected item has gone (or nothing was selected yet): take whatever
	# is now in the same place on the hotbar.
	_selected_slot = clampi(_selected_slot, 0, bar.size() - 1)
	_selected_tool_id = bar[_selected_slot].id
	return bar[_selected_slot]


## Move along the hotbar by `step` (+1 next, -1 previous), wrapping round.
func cycle_tool(step: int) -> void:
	var bar := hotbar()
	if bar.is_empty():
		return
	selected_tool()  # brings _selected_slot up to date
	_selected_slot = posmod(_selected_slot + step, bar.size())
	_selected_tool_id = bar[_selected_slot].id
	EventBus.tool_selected.emit(_selected_tool_id)


# --- Harvesting --------------------------------------------------------------

## Pick the crop at `cell` if it's ready, and put the produce in the bag.
## Returns false if there was nothing to pick.
func harvest(cell: Vector2i) -> bool:
	if not farm.can_harvest(cell):
		return false
	var crop: CropDef = farm.tile(cell).crop
	var amount := farm.harvest(cell)
	inventory.add(crop.produce, amount)
	return true


# --- Saving ------------------------------------------------------------------
# GameState says WHAT is saved; SaveSystem decides where, when, and how old
# saves are upgraded. Items and crops are saved as their ids and looked up
# again in ContentDB, because a save file can only hold plain values.
#
# There's no player position: the game saves at the start of a day, and every
# day starts with the player at the spawn point.
#
# Upgrades join this when they exist (Stage 5), as a new field plus a
# save-version bump.

func to_save() -> Dictionary:
	var selected := selected_tool()
	return {
		"gold": gold,
		"day": day,
		"season": season,
		"year": year,
		"energy": energy,
		"max_energy": max_energy,
		"inventory": inventory.to_save(),
		"selected_tool": String(selected.id) if selected != null else "",
		"location": String(location),
		"farm": farm.to_save(),
	}


## Replace the current game with a saved one. `data` has already been upgraded
## to the current save version and checked by SaveSystem, so every field is
## there. What can still be wrong is content that has since left the game: an
## item nobody defines any more is dropped, and if that leaves the player with
## nothing to use at all, the starting kit is handed out again.
func load_from_save(data: Dictionary) -> void:
	# JSON keeps every number as a float, hence the int() calls.
	gold = int(data["gold"])
	day = int(data["day"])
	season = int(data["season"])
	year = int(data["year"])
	energy = float(data["energy"])
	max_energy = float(data["max_energy"])

	inventory = Inventory.from_save(data["inventory"], true)
	if hotbar().is_empty():
		push_warning("Save has nothing on the hotbar; handing out the starting kit")
		_give_starting_kit()
	shipping_bin = Inventory.new()
	_selected_tool_id = StringName(data["selected_tool"])
	_selected_slot = 0

	location = StringName(data["location"])
	if not RULES.locations.any(func(l: LocationDef) -> bool: return l.id == location):
		push_warning("Save is at an unknown location '%s'; starting at the farm" % location)
		location = RULES.starting_location

	farm = FarmData.from_save(data["farm"])
