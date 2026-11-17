extends Node
##
## GameState — the player's progress: gold, the calendar, energy, the bag of
## items, the upgrades bought, and the farm itself (and the greenhouse's plot).
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

## The plot inside the farm's greenhouse (DECISIONS 057): a second FarmData,
## under glass, saved with the game. It's there from the start, empty and dug
## over, but the greenhouse's door stays shut until Ivy's request mends it.
## plot_here() says which of the two the player is standing in.
var greenhouse: FarmData

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

## The harvest's dice: how many a bunch gives, and whether a crop gives its
## seeds back (DECISIONS 047). Its own, so a test can fix them.
var harvest_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Pulled weeds give fibre, whether pulled by hand or hoed out.
	EventBus.weeds_pulled.connect(_on_weeds_pulled)
	# A seed dug up before it came up goes back in the bag (DECISIONS 048).
	EventBus.crop_dug_up.connect(_on_crop_dug_up)
	# Whatever the axe chops gives timber (DECISIONS 053).
	EventBus.wood_chopped.connect(_on_wood_chopped)
	# Debris cleared from the farm gives stone, timber or fibre (DECISIONS 060).
	EventBus.debris_cleared.connect(_on_debris_cleared)
	# The sickle cut a ripe crop: pick it as E would (DECISIONS 058).
	EventBus.crop_cut.connect(func(cell: Vector2i) -> void: harvest(cell))
	weather_rng.randomize()
	harvest_rng.randomize()
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
	greenhouse = GreenhouseLayout.build_default()
	quests = QuestLog.new()
	unlocks = []
	_foraged_today.clear()
	cleared = {}
	fish_log = {}
	recipes = {}
	festival_log = []
	finds = {}
	finds_on_day = 0
	finds_today = 0
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
	# Some recipes are known as soon as their unlock is (DECISIONS 063).
	for recipe in ContentDB.recipes():
		if recipe.taught_by_unlock == unlock_def:
			learn_recipe(recipe)


## Earn every unlock the calendar has reached by today, if what it `needs`
## is earned too (DECISIONS 052). TimeSystem calls this overnight, once the
## date has moved on; a new game calls it for day 1.
func open_due_unlocks() -> void:
	for each in ContentDB.unlocks():
		if each.opens_by_date() and each.on_day <= day_number() and has_unlock(each.needs):
			unlock(each)


# --- Foraging (DECISIONS 052) -------------------------------------------------
# What grows where today is Forage's (scripts/woods/forage.gd), worked out from
# the date. All that's kept here is what has been picked today, so a mushroom
# picked in the Woods stays picked after a trip back to town. Not saved: the
# game saves overnight, and by morning everything has grown back.

## Spots picked today, as "location@x,y", and the day_number they're for.
var _foraged_today: Dictionary = {}
var _foraged_on_day: int = 0


## True if the forage at `cell` in `location_id` has been picked today.
func is_foraged(location_id: StringName, cell: Vector2i) -> bool:
	return _foraged_on_day == day_number() and _foraged_today.has(_forage_key(location_id, cell))


## Pick up `what` from `cell` in `location_id`: into the bag, and remembered
## for the rest of the day. Free: foraging costs time, not energy.
func forage(location_id: StringName, cell: Vector2i, what: ForageDef) -> void:
	if what == null or is_foraged(location_id, cell):
		return
	if _foraged_on_day != day_number():
		_foraged_today.clear()
		_foraged_on_day = day_number()
	_foraged_today[_forage_key(location_id, cell)] = true
	inventory.add(what)
	EventBus.foraged.emit(what.id, location_id)
	EventBus.message_posted.emit("Found: %s" % what.display_name)


## "woods@12,7" for forage; "log:woods@12,7" for a fallen log (DECISIONS 053).
func _forage_key(location_id: StringName, cell: Vector2i, kind: String = "") -> String:
	var prefix := kind + ":" if kind != "" else ""
	return "%s%s@%d,%d" % [prefix, location_id, cell.x, cell.y]


# --- Chopping (DECISIONS 053) --------------------------------------------------
# The farm's thicket is farm terrain, saved with the farm. Away from the farm
# (the Woods) the map itself has no state, so what has been chopped there is
# kept here: the undergrowth cleared this season (saved, save version 15),
# and the fallen logs chopped today (not saved: they're worked out from the
# date, like forage, and by morning there are new ones).

## Undergrowth cleared this season: location id -> Array of cells. Emptied
## when the season turns (regrow_undergrowth, called by TimeSystem).
var cleared: Dictionary = {}


## True if the undergrowth at `cell` in `location_id` has been chopped down
## this season.
func is_cleared(location_id: StringName, cell: Vector2i) -> bool:
	return cleared.has(location_id) and cleared[location_id].has(cell)


## Remember that the undergrowth at `cell` in `location_id` is chopped down.
func clear_undergrowth(location_id: StringName, cell: Vector2i) -> void:
	if not cleared.has(location_id):
		cleared[location_id] = []
	if not cleared[location_id].has(cell):
		cleared[location_id].append(cell)


## The season has turned: everything chopped in the Woods has grown back.
func regrow_undergrowth() -> void:
	cleared = {}


## True if the fallen log at `cell` in `location_id` has been chopped today.
func is_log_chopped(location_id: StringName, cell: Vector2i) -> bool:
	return _foraged_on_day == day_number() and _foraged_today.has(_forage_key(location_id, cell, "log"))


## Remember for the rest of today that the log at `cell` is chopped. It
## shares forage's list of things taken today (as "log:woods@x,y"), so both
## are forgotten overnight together.
func chop_log(location_id: StringName, cell: Vector2i) -> void:
	if _foraged_on_day != day_number():
		_foraged_today.clear()
		_foraged_on_day = day_number()
	_foraged_today[_forage_key(location_id, cell, "log")] = true


func _on_wood_chopped(_location_id: StringName, _cell: Vector2i, _what: StringName,
		item_id: StringName, amount: int) -> void:
	var item := ContentDB.item(item_id)
	if item == null or amount <= 0:
		return
	inventory.add(item, amount)
	EventBus.message_posted.emit("+%d %s" % [amount, item.display_name.to_lower()])


# --- Fishing (DECISIONS 054) ----------------------------------------------------
# The cast, the bite and the reel are Fishing's (scripts/autoload/fishing.gd).
# A fish landed comes here: into the bag, and into the fish log, which keeps
# how many of each kind have been caught and the biggest (saved, save version
# 16). The log is for records now, and for the almanac, the summer contest
# and Pip's biggest fish later.

## Fish caught, ever: fish id -> {"caught": how many, "biggest": cm}.
var fish_log: Dictionary = {}


## Land `fish`, `size` cm long, from `water` in `location_id` (`through_ice`
## if through a hole in winter's ice): into the bag and the log, and
## announced (fish_caught).
func catch_fish(fish: FishDef, size: int, location_id: StringName, water: StringName,
		through_ice: bool = false) -> void:
	if fish == null:
		return
	var entry: Dictionary = fish_log.get(fish.id, {"caught": 0, "biggest": 0})
	var record: bool = entry["caught"] > 0 and size > entry["biggest"]
	entry["caught"] += 1
	entry["biggest"] = maxi(entry["biggest"], size)
	fish_log[fish.id] = entry
	inventory.add(fish)
	EventBus.fish_caught.emit(fish.id, size, location_id, water, through_ice)
	var text := "Caught %s %s! %d cm" % ["an" if "aeiou".contains(fish.display_name.to_lower().left(1)) else "a",
			fish.display_name.to_lower(), size]
	if entry["caught"] == 1:
		text += ", your first"
	elif record:
		text += ", your biggest yet"
	EventBus.message_posted.emit(text)


## How many of `fish_id` have been caught, ever.
func fish_caught_count(fish_id: StringName) -> int:
	return int(fish_log.get(fish_id, {}).get("caught", 0))


## The biggest `fish_id` caught, in cm, or 0 if none yet.
func biggest_fish(fish_id: StringName) -> int:
	return int(fish_log.get(fish_id, {}).get("biggest", 0))


## {"perch": {"caught": 3, "biggest": 31}}: as it's kept, with plain numbers.
func _fish_log_to_save() -> Dictionary:
	var data := {}
	for id: StringName in fish_log:
		data[String(id)] = {"caught": int(fish_log[id]["caught"]), "biggest": int(fish_log[id]["biggest"])}
	return data


## A fish the game no longer has is dropped with a warning, like an item.
func _fish_log_from_save(data: Variant) -> void:
	fish_log = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	for key: Variant in data:
		var entry: Variant = data[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not (ContentDB.item(StringName(key)) is FishDef):
			push_warning("Save's fish log has a fish '%s' the game doesn't know; it's been removed" % key)
			continue
		fish_log[StringName(key)] = {"caught": int(entry.get("caught", 0)), "biggest": int(entry.get("biggest", 0))}


# --- Festivals (DECISIONS 059) -------------------------------------------------
# What happened at each festival the farmer took part in (saved, save version
# 20): the place they came in a contest and what they entered, or a keepsake
# received. The Festivals service writes it; the year review and the almanac
# (Stage 19) read it. Kept as plain dictionaries, as they're saved.

## One entry per festival taken part in, oldest first:
## {"event": "flower_show", "year": 1, "day": 24, "place": 1,
##  "entry": "tulip", "score": 65}. "place" is 0 for a festival with no
## contest (lantern night's lantern), and "entry" and "score" are left out.
var festival_log: Array[Dictionary] = []


## Write down that the farmer took part in `event_id` today.
func record_festival(event_id: StringName, place: int, entry_id: StringName = &"", score: int = 0) -> void:
	var entry := {"event": String(event_id), "year": year, "day": day_number(), "place": place}
	if entry_id != &"":
		entry["entry"] = String(entry_id)
		entry["score"] = score
	festival_log.append(entry)


## How many times the farmer has come first at `event_id`.
func festival_wins(event_id: StringName) -> int:
	return festival_log.filter(func(e: Dictionary) -> bool:
		return e.get("event", "") == String(event_id) and int(e.get("place", 0)) == 1).size()


func _festival_log_from_save(data: Variant) -> void:
	festival_log = []
	if typeof(data) != TYPE_ARRAY:
		return
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("event")) != TYPE_STRING:
			continue
		var kept := {"event": entry["event"], "year": int(entry.get("year", 1)), "day": int(entry.get("day", 1)),
				"place": int(entry.get("place", 0))}
		if typeof(entry.get("entry")) == TYPE_STRING:
			kept["entry"] = entry["entry"]
			kept["score"] = int(entry.get("score", 0))
		festival_log.append(kept)


# --- Cooking and eating (DECISIONS 056) ---------------------------------------
# Recipes are data (RecipeDef, data/recipes/); dishes are ToolDefs with an
# EatAction (data/dishes/). All that's kept here is which recipes the farmer
# knows, and how many times each has been cooked (saved, save version 17).
# The stove in the farmhouse cooks once the kitchen is open
# (RULES.kitchen_unlock, from Mabel's lessons); a dish on the hotbar is eaten
# with Space, anywhere.
#
# The workbench (DECISIONS 063) works the same way: its plans are RecipeDefs
# made_at &"workbench", known in the same list, and it makes things once it's
# mended (RULES.workbench_unlock, earned by propping its leg on stones).

## Recipes known: recipe id -> times cooked (0: known, not cooked yet).
var recipes: Dictionary = {}


## True if the farmhouse kitchen is open: Mabel has shown the farmer how.
func kitchen_open() -> bool:
	return has_unlock(RULES.kitchen_unlock)


## True if the farm's workbench is mended, so it makes things.
func workbench_open() -> bool:
	return has_unlock(RULES.workbench_unlock)


## True if `place` (RecipeDef.PLACES) can make things today.
func can_make_at(place: StringName) -> bool:
	match place:
		&"stove":
			return kitchen_open()
		&"workbench":
			return workbench_open()
	return false


## Mend the workbench: its missing leg propped up on RULES.workbench_mend_count
## of RULES.workbench_mend_item (stones), taken from the bag. Earns
## RULES.workbench_unlock, which teaches the old farmer's first plans. Returns
## false and takes nothing if it's mended already or the bag is short.
func mend_workbench() -> bool:
	if workbench_open():
		return false
	var item := RULES.workbench_mend_item
	var count := RULES.workbench_mend_count
	if item != null and count > 0:
		if inventory.count(item) < count:
			return false
		inventory.remove(item, count)
	unlock(RULES.workbench_unlock)
	return true


func knows_recipe(recipe_id: StringName) -> bool:
	return recipes.has(recipe_id)


## Learn `recipe` (a request's reward). Announces recipe_learned the first
## time; learning it again does nothing.
func learn_recipe(recipe: RecipeDef) -> void:
	if recipe == null or recipes.has(recipe.id):
		return
	recipes[recipe.id] = 0
	EventBus.recipe_learned.emit(recipe.id)


## The recipes known, by the product's name, for the stove's or the
## workbench's menu: only those made at `place` (RecipeDef.PLACES), or every
## one with &"".
func known_recipes(place: StringName = &"stove") -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	for id: StringName in recipes:
		var recipe := ContentDB.recipe(id)
		if recipe != null and (place == &"" or recipe.made_at == place):
			result.append(recipe)
	result.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool: return a.display_name() < b.display_name())
	return result


## Cook `recipe` once (or make it, at the workbench): take what goes in from
## the bag and put what it makes in. Returns false and changes nothing if
## where it's made isn't open, the recipe isn't known, or something's missing
## (RecipeDef.missing says what).
func cook(recipe: RecipeDef) -> bool:
	if recipe == null or recipe.product() == null or not knows_recipe(recipe.id):
		return false
	if not can_make_at(recipe.made_at) or not recipe.can_cook(inventory):
		return false
	recipe.take_from(inventory)
	var made := recipe.product()
	inventory.add(made, maxi(1, recipe.makes))
	recipes[recipe.id] = int(recipes[recipe.id]) + 1
	if recipe.is_plan():
		EventBus.item_made.emit(recipe.id, made.id, maxi(1, recipe.makes))
	else:
		EventBus.dish_cooked.emit(recipe.id, made.id)
	return true


## How many times `recipe_id` has been cooked, ever.
func times_cooked(recipe_id: StringName) -> int:
	return int(recipes.get(recipe_id, 0))


## Eat one of `dish` (a ToolDef with an EatAction) from the bag: its energy
## comes back, up to today's maximum. Returns false and keeps the dish if the
## farmer is already full, so a helping is never wasted.
func eat(dish: ToolDef) -> bool:
	if dish == null or not dish.action is EatAction:
		return false
	if energy >= max_energy:
		EventBus.message_posted.emit("You're full. Save the %s for later" % dish.display_name.to_lower())
		return false
	if not inventory.remove(dish):
		return false
	var before := energy
	energy = minf(max_energy, energy + (dish.action as EatAction).energy)
	var gained := energy - before
	EventBus.energy_changed.emit(energy, max_energy)
	EventBus.dish_eaten.emit(dish.id, gained)
	EventBus.message_posted.emit("%s: +%d energy" % [dish.display_name, roundi(gained)])
	return true


## {"tomato_soup": 2}: as it's kept, with plain numbers.
func _recipes_to_save() -> Dictionary:
	var data := {}
	for id: StringName in recipes:
		data[String(id)] = int(recipes[id])
	return data


## A recipe the game no longer has is dropped with a warning, like an item.
func _recipes_from_save(data: Variant) -> void:
	recipes = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	for key: Variant in data:
		if ContentDB.recipe(StringName(key)) == null:
			push_warning("Save knows a recipe '%s' the game doesn't have; it's been removed" % key)
			continue
		var cooked: Variant = data[key]
		recipes[StringName(key)] = int(cooked) if typeof(cooked) in [TYPE_INT, TYPE_FLOAT] else 0


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


## The crops wilting on the farm (or another plot: the greenhouse's) now:
## unwatered for wilt_after() nights and not watered yet today. With thirst_deadline(), they die tonight unless
## watered (the morning summary warns).
func wilted_crops(plot: FarmData = null) -> Array[Vector2i]:
	if plot == null:
		plot = farm
	var wilted: Array[Vector2i] = []
	var after := wilt_after()
	for cell: Vector2i in plot.cells():
		if plot.tile(cell).is_wilted(after):
			wilted.append(cell)
	return wilted


## E on a tile with weeds: pull them up by hand, for a little energy (scaled
## by the difficulty, like a tool). Returns false if there were none, or not
## enough energy left.
func pull_weeds(cell: Vector2i) -> bool:
	var plot := plot_here()
	if plot == null or not plot.has_weeds(cell):
		return false
	var cost := (RULES.hazards.pull_weeds_energy if RULES.hazards != null else 0.0) \
			* difficulty.energy_cost_multiplier
	if not try_spend_energy(cost):
		EventBus.message_posted.emit("Too tired to pull weeds")
		return false
	return plot.pull_weeds(cell)


## E on brambles or nettles (DECISIONS 060): pull them up by hand, for the
## debris's hand_energy (scaled by the difficulty, like a tool). Returns
## false if there's nothing here that comes away by hand, or not enough
## energy left.
func clear_by_hand(cell: Vector2i) -> bool:
	var plot := plot_here()
	var debris := plot.debris_at(cell) if plot != null else null
	if debris == null or not debris.clear_by_hand:
		return false
	if not try_spend_energy(debris.hand_energy * difficulty.energy_cost_multiplier):
		EventBus.message_posted.emit("Too tired to clear the %s" % debris.display_name.to_lower())
		return false
	return plot.clear_debris(cell)


## Whatever was cleared gives what its ObjectDef says (stones give stone),
## and now and then something turns up under it (DECISIONS 061).
func _on_debris_cleared(cell: Vector2i, object_id: StringName) -> void:
	var debris := ContentDB.object(object_id)
	if debris != null and debris.clears_to != null and debris.clears_to_amount > 0:
		inventory.add(debris.clears_to, debris.clears_to_amount)
		EventBus.message_posted.emit("+%d %s" % [debris.clears_to_amount, debris.clears_to.display_name.to_lower()])
	_turn_up_find(cell, object_id)


# --- Finds while clearing (DECISIONS 061) ---------------------------------------
# Clearing the farm's new ground now and then turns up something: FindDefs in
# data/finds/. Which one is rolled from the cell and the day, in file order,
# the first to come up winning; at most RULES.finds_per_day a day. What's
# kept is how many times each has turned up (saved, save version 22), and
# how many have turned up today.

## Find id -> how many times it has turned up.
var finds: Dictionary = {}

## The day_number finds_today counts for, and how many have turned up on it.
## Not worth a save field of its own: saves are made at dawn, so a loaded
## game always starts a fresh day's count.
var finds_on_day: int = 0
var finds_today: int = 0


## How many times `find_id` has turned up.
func times_found(find_id: StringName) -> int:
	return int(finds.get(find_id, 0))


## The find that turns up when `debris_id` is cleared from `cell` today, or
## null. Doesn't change anything, so the same clearing always gets the same
## answer.
func find_under(cell: Vector2i, debris_id: StringName) -> FindDef:
	var today := day_number()
	if finds_on_day == today and finds_today >= RULES.finds_per_day:
		return null
	for each in ContentDB.finds():
		if not each.could_turn_up(debris_id, today, season_id(), times_found(each.id)):
			continue
		var roll := float(absi(hash([cell, today, String(each.id), "find"])) % 10000) / 10000.0
		if roll < each.chance:
			return each
	return null


func _turn_up_find(cell: Vector2i, debris_id: StringName) -> void:
	var found := find_under(cell, debris_id)
	if found == null:
		return
	var today := day_number()
	if finds_on_day != today:
		finds_on_day = today
		finds_today = 0
	finds_today += 1
	finds[found.id] = times_found(found.id) + 1
	for item: ItemDef in found.gives:
		inventory.add(item, found.gives[item])
	unlock(found.gives_unlock)
	if found.leaves_object != &"" and farm != null:
		farm.place_object(cell, found.leaves_object)
	EventBus.found_while_clearing.emit(found.id, cell, times_found(found.id))


func _finds_from_save(data: Variant) -> void:
	finds = {}
	finds_on_day = 0
	finds_today = 0
	if typeof(data) != TYPE_DICTIONARY:
		return
	for id: Variant in data:
		var count: Variant = data[id]
		if typeof(id) == TYPE_STRING and typeof(count) in [TYPE_FLOAT, TYPE_INT] and int(count) > 0:
			finds[StringName(id)] = int(count)


func _on_weeds_pulled(_cell: Vector2i) -> void:
	if RULES.hazards != null and RULES.hazards.weed_item != null:
		inventory.add(RULES.hazards.weed_item)


func _on_crop_dug_up(_cell: Vector2i, crop_id: StringName, was_seed: bool) -> void:
	var crop := ContentDB.crop(crop_id)
	if crop == null:
		return
	var seeds := ContentDB.seeds_for(crop) if was_seed else null
	if seeds != null:
		inventory.add(seeds)
		EventBus.message_posted.emit("Dug up the %s seed and put it back in the bag" % crop.display_name)
	else:
		EventBus.message_posted.emit("Dug up the %s" % crop.display_name)


## The crops with aphids on them now (DECISIONS 048), for the morning's news.
func crops_with_pests() -> Array[Vector2i]:
	var infested: Array[Vector2i] = []
	for cell: Vector2i in farm.cells():
		if farm.tile(cell).pests:
			infested.append(cell)
	return infested


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
## Returns false if there was nothing to pick. A crop that comes in bunches
## gives a roll of the dice; one that returns seeds (CropDef.seed_chance)
## sometimes puts a packet in the bag too (DECISIONS 047).
func harvest(cell: Vector2i) -> bool:
	var plot := plot_here()
	if plot == null or not plot.can_harvest(cell):
		return false
	# A giant or a tree is held by its corner tile (DECISIONS 048).
	var crop: CropDef = plot.tile(plot.crop_cell(cell)).crop
	var amount := plot.harvest(cell, harvest_rng)
	inventory.add(crop.produce, amount)
	if crop.seed_chance > 0.0 and harvest_rng.randf() < crop.seed_chance:
		var seeds := ContentDB.seeds_for(crop)
		if seeds != null:
			inventory.add(seeds)
			EventBus.message_posted.emit("%s gave back some seeds" % crop.display_name)
	return true


## E on a placed object (a sprinkler, a decoration): take it back into the bag. Returns
## false for things that can't be picked up, like trees and the bin.
func pick_up_object(cell: Vector2i) -> bool:
	var plot := plot_here()
	var t := plot.tile(cell) if plot != null else null
	if t == null or t.object_id == &"":
		return false
	var object_def := ContentDB.object(t.object_id)
	if object_def == null or object_def.item == null:
		return false
	plot.remove_object(cell)
	inventory.add(object_def.item)
	return true


## E on an object that has made something (a hive with honey in it;
## DECISIONS 057): take it all into the bag. Returns false if there was
## nothing waiting, so E falls through to picking the object up.
func collect_from_object(cell: Vector2i) -> bool:
	var plot := plot_here()
	var t := plot.tile(cell) if plot != null else null
	if t == null or t.object_id == &"" or t.made_ready <= 0:
		return false
	var object_def := ContentDB.object(t.object_id)
	if object_def == null or object_def.makes == null:
		return false
	var object_id := t.object_id
	var amount := plot.empty_object(cell)
	inventory.add(object_def.makes, amount)
	EventBus.object_emptied.emit(cell, object_id, object_def.makes.id, amount)
	EventBus.message_posted.emit("Collected %d %s" % [amount, object_def.makes.display_name.to_lower()])
	return true


# --- Plots: the farm and the greenhouse (DECISIONS 057) -----------------------
# Two places have tiles to farm: the farm, and the plot inside the greenhouse.
# Tools, harvesting and E ask plot_here() which one the player is in, so the
# same hoe, can and seeds work in both, and neither knows about the other.

## The plot of `location_id`: the farm's, the greenhouse's, or null for a
## place with nothing to farm (the town, a shop, the farmhouse).
func plot_at(location_id: StringName) -> FarmData:
	if location_id == LocationManager.FARM_ID:
		return farm
	if location_id == RULES.greenhouse_location and location_id != &"":
		return greenhouse
	return null


## The plot where the player is now, or null.
func plot_here() -> FarmData:
	return plot_at(location)


## Every plot there is, the farm first: what the night's growing goes round.
func plots() -> Array[FarmData]:
	return [farm, greenhouse]


## True if `tool` can be used here today. Seeds out of season can't, except
## under glass, where the season doesn't matter (DECISIONS 057). The player
## asks this before using a tool, and the hotbar to grey one out.
func tool_usable_here(tool: ToolDef) -> bool:
	if tool == null or tool.action == null:
		return true
	var plot := plot_here()
	if plot != null and plot.under_glass:
		return true
	return tool.action.usable_in_season(season_id())


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
# The greenhouse's plot is saved like the farm, tile by tile (save version
# 18), and so is any honey waiting in a hive.
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
		"greenhouse": greenhouse.to_save(),
		"quests": quests.to_save(),
		"orders_done": quests.orders_done,
		"unlocks": unlocks.map(func(id: StringName) -> String: return String(id)),
		"weather": String(weather_id()),
		"forecast": String(forecast.id) if forecast != null else "",
		"cleared": _cleared_to_save(),
		"fish_log": _fish_log_to_save(),
		"recipes": _recipes_to_save(),
		"festivals": festival_log.duplicate(true),
		"finds": _finds_to_save(),
	}


## {"seed_tin": 1}: by id as Strings, which JSON can hold.
func _finds_to_save() -> Dictionary:
	var data := {}
	for id: StringName in finds:
		data[String(id)] = finds[id]
	return data


## {"woods": [[3, 16], [4, 16]]}: plain lists, which JSON can hold.
func _cleared_to_save() -> Dictionary:
	var data := {}
	for location_id: StringName in cleared:
		var cells: Array = []
		for cell: Vector2i in cleared[location_id]:
			cells.append([cell.x, cell.y])
		data[String(location_id)] = cells
	return data


func _cleared_from_save(data: Variant) -> void:
	cleared = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	for location_id: Variant in data:
		var cells: Variant = data[location_id]
		if typeof(cells) != TYPE_ARRAY:
			continue
		for pair: Variant in cells:
			if typeof(pair) == TYPE_ARRAY and pair.size() == 2:
				clear_undergrowth(StringName(location_id), Vector2i(int(pair[0]), int(pair[1])))


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
	# The greenhouse's plot (save version 18), always under glass.
	greenhouse = FarmData.from_save(data["greenhouse"])
	greenhouse.under_glass = true
	quests = QuestLog.from_save(data["quests"])
	# Orders handed in (save version 14, DECISIONS 050): their entries are
	# cleared away each morning, so the count is kept on its own.
	quests.orders_done = int(data.get("orders_done", 0))

	# Unlocks are kept by name even if no UnlockDef has it any more: it does
	# nothing then, and it's there again if the file comes back.
	_foraged_today.clear()
	# Undergrowth chopped in the Woods this season (save version 15).
	_cleared_from_save(data["cleared"])
	# Every fish caught, and the biggest of each (save version 16).
	_fish_log_from_save(data["fish_log"])
	# The recipes known, and how often each has been cooked (save version 17).
	_recipes_from_save(data["recipes"])
	# Festivals taken part in (save version 20).
	_festival_log_from_save(data["festivals"])
	# What has turned up while clearing (save version 22).
	_finds_from_save(data["finds"])
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
