extends Node
##
## GameState — the player's progress: gold, the calendar, energy, the bag of
## items, the upgrades bought, and the farm itself.
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

## How hard this game is (DECISIONS 040): chosen at new game, saved, and never
## changed after. Economy, the player's tools and the farm's growing read its
## multipliers; it's never null.
var difficulty: DifficultyDef

var gold: int = 0

## The calendar. `day` is the day of the season, 1 to RULES.days_per_season;
## `season` is an index into RULES.seasons; `year` counts up from 1.
var day: int = 1
var season: int = 0
var year: int = 1

## The time of day, in minutes after midnight (6 AM is 360). Past midnight
## it keeps counting (1 AM is 1500), because it's still the same day until
## the player sleeps. TimeSystem moves it on; it's never saved, because the
## game only saves at dawn (DECISIONS 035).
var minutes: int = 0

var energy: float = 0.0

## Today's maximum: the starting amount in game_rules.tres plus whatever the
## energy upgrades add. Worked out from those two, never saved (DECISIONS 024).
var max_energy: float = 0.0

## Every upgrade bought, in the order bought. Owning one is the only thing
## stored about it; tool tiers and maximum energy are worked out from this
## list whenever they're needed.
var upgrades: Array[UpgradeDef] = []

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

## The townsfolk's requests taken on and finished (DECISIONS 038). The
## requests themselves are data; this is only where the player has got to.
var quests: QuestLog

## What has opened up so far (DECISIONS 043), by UnlockDef id, in the order
## earned. Only the names are kept; what each one opens is in the content
## that points at it (requires_unlock), so it can change freely.
var unlocks: Array[StringName] = []

## Where the player is. LocationManager changes it; it's saved, so a loaded
## game opens in the right place.
var location: StringName = &""

## Today's weather and tomorrow's (DECISIONS 046), both saved. Tomorrow's is
## chosen a day ahead so it can be forecast, and the forecast is never wrong:
## tonight it simply becomes today's. Either can be null if a season has no
## weather odds at all; everything that asks copes with that (no weather).
var weather: WeatherDef
var forecast: WeatherDef

## The weather's own dice, so a test can set its seed and know what comes.
var weather_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Pulled weeds give fibre, whether pulled by hand or hoed out.
	EventBus.weeds_pulled.connect(_on_weeds_pulled)
	weather_rng.randomize()
	# Always start from a valid new game, so the farm scene can be run on its
	# own with F6. When the game is launched properly, the boot scene then asks
	# SaveSystem to replace this with the saved game, if there is one.
	new_game()


## Reset everything to the starting state in GameRules, played at
## `chosen_difficulty` (the default one if none is given: running a scene on
## its own with F6, or a test). The other way in is load_from_save().
func new_game(chosen_difficulty: DifficultyDef = null) -> void:
	difficulty = chosen_difficulty if chosen_difficulty != null else RULES.standard_difficulty()
	gold = difficulty.starting_gold(RULES.starting_gold)
	day = 1
	season = 0
	year = 1
	minutes = RULES.day_start_minutes
	upgrades = []
	max_energy = _work_out_max_energy()
	energy = max_energy
	inventory = Inventory.new(true)
	_give_starting_kit()
	shipping_bin = Inventory.new()
	_selected_tool_id = &""
	_selected_slot = 0
	farm = FarmLayout.build_default()
	quests = QuestLog.new()
	unlocks = []
	# Anything the calendar opens on day 1 is there from the start.
	open_due_unlocks()
	location = RULES.starting_location
	start_weather()
	EventBus.new_game_started.emit()


func _give_starting_kit() -> void:
	for item: ItemDef in RULES.starting_inventory:
		inventory.add(item, RULES.starting_inventory[item])


# --- The calendar ------------------------------------------------------------

## Move the calendar on one day and refill energy. After the last day of a
## season comes day 1 of the next; after the last season, a new year. Returns
## true if the season turned, so TimeSystem knows to run the season change.
## Called by TimeSystem as part of the overnight sequence — nothing else
## should call it. It announces nothing: TimeSystem announces the new day
## once everything overnight is done.
func advance_calendar() -> bool:
	energy = max_energy
	minutes = RULES.day_start_minutes
	day += 1
	if day <= RULES.days_per_season:
		return false
	day = 1
	season += 1
	if season >= RULES.seasons.size():
		season = 0
		year += 1
	return true


## The current season, or null if game_rules.tres lists none.
func current_season_theme() -> SeasonTheme:
	if RULES.seasons.is_empty():
		return null
	return RULES.seasons[posmod(season, RULES.seasons.size())]


## The current season's id (&"spring"), which is what crops are checked against.
func season_id() -> StringName:
	var theme := current_season_theme()
	return theme.id if theme != null else &""


## The display name of the season with id `id`, e.g. "Summer". Unknown ids
## come back as they are, so a typo in a crop file is visible, not hidden.
func season_name(id: StringName) -> String:
	for theme in RULES.seasons:
		if theme.id == id:
			return theme.display_name
	return String(id)


## "Spring and autumn", "Summer", "all year": the seasons in `ids`, in words,
## for the shop and the hotbar.
func describe_seasons(ids: Array[StringName]) -> String:
	if ids.is_empty():
		return "all year"
	var names: Array[String] = []
	for id in ids:
		names.append(season_name(id).to_lower())
	var text := names[0]
	if names.size() > 1:
		text = ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
	return text.left(1).to_upper() + text.substr(1)


## How many days the game has been going, counting today: spring day 1 of
## year 1 is day 1, and it counts straight on through seasons and years.
## Calendar events (market day) are worked out from this (DECISIONS 037).
func day_number() -> int:
	return ((year - 1) * maxi(1, RULES.seasons.size()) + season) * RULES.days_per_season + day


## The season id on `number` (a day_number), today's or another day's.
func season_id_on(number: int) -> StringName:
	if RULES.seasons.is_empty() or RULES.days_per_season < 1:
		return &""
	var season_index := posmod(floori((number - 1) / float(RULES.days_per_season)), RULES.seasons.size())
	return RULES.seasons[season_index].id


## The calendar events on today, from ContentDB. Nothing about them is saved:
## they follow from the date.
func events_today() -> Array[CalendarEvent]:
	return events_on(day_number())


## The calendar events on day `number` (a day_number): the ones whose dates
## fall on it and whose unlock, if they wait for one, is earned (DECISIONS
## 044). For a day ahead or behind it uses today's unlocks, since nobody can
## know what will be earned by then.
func events_on(number: int) -> Array[CalendarEvent]:
	return ContentDB.events_on(number, season_id_on(number)).filter(
			func(e: CalendarEvent) -> bool: return has_unlock(e.requires_unlock))


## How many days until `event` next happens: 0 if it's today, -1 if it
## doesn't come round within a year, or is still waiting for its unlock.
func days_until(event: CalendarEvent) -> int:
	if not has_unlock(event.requires_unlock):
		return -1
	var today := day_number()
	var year_length := RULES.days_per_season * maxi(1, RULES.seasons.size())
	for ahead in year_length + 1:
		if event.happens_on(today + ahead, season_id_on(today + ahead)):
			return ahead
	return -1


# --- The clock ---------------------------------------------------------------

## Move the clock on by `step` minutes and announce the new time. Called by
## TimeSystem as the day goes by; it doesn't end the day itself.
func advance_clock(step: int) -> void:
	minutes += step
	EventBus.time_changed.emit(minutes)


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


## The starting maximum plus every energy upgrade owned.
func _work_out_max_energy() -> float:
	var total := RULES.max_energy
	for upgrade in upgrades:
		if upgrade.effect != null:
			total += upgrade.effect.max_energy_bonus()
	return total


# --- Upgrades ----------------------------------------------------------------
# Economy decides what's on offer and takes the gold; this keeps the list and
# applies the result.

func has_upgrade(upgrade: UpgradeDef) -> bool:
	return upgrade in upgrades


## Add a bought upgrade. A bigger energy maximum is topped up straight away,
## so buying one mid-afternoon is felt the same day.
func add_upgrade(upgrade: UpgradeDef) -> void:
	if has_upgrade(upgrade):
		return
	upgrades.append(upgrade)
	var old_max := max_energy
	max_energy = _work_out_max_energy()
	if max_energy != old_max:
		energy += max_energy - old_max
		EventBus.energy_changed.emit(energy, max_energy)
	if upgrade.effect != null:
		upgrade.effect.on_bought(upgrade)


## The tier of `tool` the player owns: the best any upgrade gives, and never
## more than the tool actually has.
func tool_tier(tool: ToolDef) -> int:
	var best := 0
	for upgrade in upgrades:
		if upgrade.effect != null:
			best = maxi(best, upgrade.effect.tool_tier(tool.id))
	return mini(best, tool.max_tier())


## What the player calls this tool now, e.g. "Wide hoe" once upgraded.
func tool_name(tool: ToolDef) -> String:
	return tool.name_at(tool_tier(tool))


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


# --- Unlocks (DECISIONS 043) -------------------------------------------------
# Requests and the calendar open things up; shops, doors and townsfolk ask
# has_unlock() before offering anything that waits for one.

## True if `unlock_def` has been earned. Null means "nothing to wait for", so
## content with no requires_unlock can pass its field straight in.
func has_unlock(unlock_def: UnlockDef) -> bool:
	return unlock_def == null or unlock_def.id in unlocks


## Earn `unlock_def`. Announces unlocked the first time; earning it again does
## nothing, so a request and the calendar can both give the same one.
func unlock(unlock_def: UnlockDef) -> void:
	if unlock_def == null or unlock_def.id in unlocks:
		return
	unlocks.append(unlock_def.id)
	EventBus.unlocked.emit(unlock_def.id)


## Earn every unlock the calendar has reached by today. TimeSystem calls this
## overnight, once the date has moved on; a new game calls it for day 1.
func open_due_unlocks() -> void:
	for each in ContentDB.unlocks():
		if each.opens_by_date() and each.on_day <= day_number():
			unlock(each)


# --- Hazards (DECISIONS 045) -------------------------------------------------
# The rules are in data/hazard_rules.tres (RULES.hazards); the difficulty
# decides how hard they press. These answer the questions the farm, the
# summary and the night ask, so none of them has to combine the two.

## How many nights in a row without water a crop survives before it dies
## tonight, or 0 if thirst never kills at this difficulty.
func thirst_deadline() -> int:
	var rules := RULES.hazards
	if rules == null or not difficulty.thirst_kills:
		return 0
	return rules.die_after_dry_nights


## How many dry nights before a crop looks wilted (0: never).
func wilt_after() -> int:
	return RULES.hazards.wilt_after_dry_nights if RULES.hazards != null else 0


## The crops wilting on the farm now: unwatered for wilt_after() nights and
## not watered yet today. With thirst_deadline(), they die tonight unless
## watered (the morning summary warns).
func wilted_crops() -> Array[Vector2i]:
	var wilted: Array[Vector2i] = []
	var after := wilt_after()
	for cell: Vector2i in farm.cells():
		if farm.tile(cell).is_wilted(after):
			wilted.append(cell)
	return wilted


## E on a tile with weeds: pull them up by hand, for a little energy (scaled
## by the difficulty, like a tool). Returns false if there were none, or not
## enough energy left.
func pull_weeds(cell: Vector2i) -> bool:
	if not farm.has_weeds(cell):
		return false
	var cost := (RULES.hazards.pull_weeds_energy if RULES.hazards != null else 0.0) \
			* difficulty.energy_cost_multiplier
	if not try_spend_energy(cost):
		EventBus.message_posted.emit("Too tired to pull weeds")
		return false
	return farm.pull_weeds(cell)


func _on_weeds_pulled(_cell: Vector2i) -> void:
	if RULES.hazards != null and RULES.hazards.weed_item != null:
		inventory.add(RULES.hazards.weed_item)


# --- Weather (DECISIONS 046) -------------------------------------------------
# What each kind of weather does is in data/weather/ (WeatherDef); the odds
# are on each season (SeasonTheme.weather_odds). This keeps today's and
# tomorrow's, and moves them on each night.

## The season on day `number` (a day_number), or null if there are none.
func season_theme_on(number: int) -> SeasonTheme:
	if RULES.seasons.is_empty() or RULES.days_per_season < 1:
		return null
	return RULES.seasons[posmod(floori((number - 1) / float(RULES.days_per_season)), RULES.seasons.size())]


## The weather for day `number`, freshly drawn from its season's odds (or
## fixed by its date). Null if that season has no weather.
func roll_weather(number: int) -> WeatherDef:
	var theme := season_theme_on(number)
	if theme == null:
		return null
	return theme.weather_on(posmod(number - 1, RULES.days_per_season) + 1, weather_rng)


## A new game: today's weather and tomorrow's from scratch. (Spring's day 1
## is fixed sunny, so a first morning is never a wet one.)
func start_weather() -> void:
	weather = roll_weather(day_number())
	forecast = roll_weather(day_number() + 1)
	EventBus.weather_changed.emit(weather_id())


## Overnight, once the calendar has moved on (TimeSystem): yesterday's
## forecast becomes today's weather, and tomorrow's is chosen.
func advance_weather() -> void:
	weather = forecast if forecast != null else roll_weather(day_number())
	forecast = roll_weather(day_number() + 1)
	EventBus.weather_changed.emit(weather_id())


## Today's weather's id, or &"" for none.
func weather_id() -> StringName:
	return weather.id if weather != null else &""


## How many nights' thirst an unwatered crop gains tonight: 2 in a heatwave.
func thirst_per_dry_night() -> int:
	return weather.thirst_per_dry_night if weather != null else 1


## The season after this one's id: what frost checks crops against.
func next_season_id() -> StringName:
	return season_id_on(day_number() + RULES.days_per_season - day + 1)


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


## E on a placed object (a sprinkler, a decoration): take it back into the bag. Returns
## false for things that can't be picked up, like trees and the bin.
func pick_up_object(cell: Vector2i) -> bool:
	var t := farm.tile(cell)
	if t == null or t.object_id == &"":
		return false
	var object_def := ContentDB.object(t.object_id)
	if object_def == null or object_def.item == null:
		return false
	farm.remove_object(cell)
	inventory.add(object_def.item)
	return true


# --- Saving ------------------------------------------------------------------
# GameState says WHAT is saved; SaveSystem decides where, when, and how old
# saves are upgraded. Items and crops are saved as their ids and looked up
# again in ContentDB, because a save file can only hold plain values.
#
# There's no player position: the game saves at the start of a day, and every
# day starts with the player at the spawn point.
#
# Requests (quests) are saved by id with how far each has got (save version
# 8); what each one asks is in data/quests/, not in the save.
#
# Unlocks are saved as a list of names (save version 10).
#
# Today's weather and tomorrow's forecast are saved by id (save version 12).
#
# The difficulty is saved by id (save version 9); its multipliers are read
# from data/difficulties/ on load, so retuning Hard reaches existing games.
#
# Upgrades are saved as a list of ids (save version 4). Maximum energy isn't
# saved at all: it's worked out from the upgrades on load, so a rebalanced
# energy upgrade reaches existing games too.

func to_save() -> Dictionary:
	var selected := selected_tool()
	return {
		"difficulty": String(difficulty.id),
		"gold": gold,
		"day": day,
		"season": season,
		"year": year,
		"energy": energy,
		"upgrades": upgrades.map(func(u: UpgradeDef) -> String: return String(u.id)),
		"inventory": inventory.to_save(),
		"selected_tool": String(selected.id) if selected != null else "",
		"location": String(location),
		"farm": farm.to_save(),
		"quests": quests.to_save(),
		"unlocks": unlocks.map(func(id: StringName) -> String: return String(id)),
		"weather": String(weather_id()),
		"forecast": String(forecast.id) if forecast != null else "",
	}


## Replace the current game with a saved one. `data` has already been upgraded
## to the current save version and checked by SaveSystem, so every field is
## there. What can still be wrong is content that has since left the game: an
## item nobody defines any more is dropped, and if that leaves the player with
## nothing to use at all, the starting kit is handed out again.
func load_from_save(data: Dictionary) -> void:
	difficulty = RULES.find_difficulty(StringName(data["difficulty"]))
	if difficulty == null:
		push_warning("Save is at a difficulty '%s' the game doesn't know; playing it at %s"
				% [data["difficulty"], RULES.standard_difficulty().display_name])
		difficulty = RULES.standard_difficulty()

	# JSON keeps every number as a float, hence the int() calls.
	gold = int(data["gold"])
	# Kept inside the calendar, in case game_rules.tres has been changed since
	# the save was made (fewer seasons, or shorter ones). A day past the end of
	# the season becomes its last day, so the season turns tonight.
	day = clampi(int(data["day"]), 1, maxi(1, RULES.days_per_season))
	season = posmod(int(data["season"]), maxi(1, RULES.seasons.size()))
	year = maxi(1, int(data["year"]))
	# Saves are made at dawn, so a loaded game always starts the day afresh.
	minutes = RULES.day_start_minutes

	upgrades = []
	for id: Variant in data["upgrades"]:
		var upgrade := ContentDB.upgrade(StringName(id))
		if upgrade == null:
			push_warning("Save has an upgrade '%s' the game doesn't know; it's been removed" % id)
		elif not has_upgrade(upgrade):
			upgrades.append(upgrade)
	max_energy = _work_out_max_energy()
	energy = minf(float(data["energy"]), max_energy)

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
	quests = QuestLog.from_save(data["quests"])

	# Unlocks are kept by name even if no UnlockDef has it any more: it does
	# nothing then, and it's there again if the file comes back.
	unlocks = []
	for id: Variant in data["unlocks"]:
		if StringName(id) not in unlocks:
			unlocks.append(StringName(id))
	# Anything the calendar has opened since (a new unlock added to the game
	# with a date already past) is caught up quietly.
	open_due_unlocks()

	# Weather by id (save version 12). A kind no longer in the game, or a
	# forecast not made yet (an upgraded older save), is drawn afresh.
	weather = ContentDB.weather(StringName(data["weather"]))
	if weather == null:
		weather = roll_weather(day_number())
	forecast = ContentDB.weather(StringName(data["forecast"]))
	if forecast == null:
		forecast = roll_weather(day_number() + 1)
	EventBus.weather_changed.emit(weather_id())
