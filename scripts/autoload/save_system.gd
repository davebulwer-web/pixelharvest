extends Node
##
## SaveSystem — writes the game to disk, reads it back, and upgrades old saves.
##
## What gets saved is GameState's business (GameState.to_save). This file owns
## everything else: where the file lives, when it's written, what happens if
## it's damaged, and how a save from an older version of the game is brought
## up to date (rule 4, DECISIONS 022).
##
## When:
##   - Saving happens once a day, at the end of the overnight sequence, when
##     TimeSystem calls save_game(). Quitting mid-day loses that day's work, as
##     in most farming games. That's deliberate: a save is always a clean
##     morning, never half an action.
##   - Loading happens once, at launch, from the boot scene.
##   - With no save (or one that can't be read), the boot scene asks which
##     difficulty to play at before the new game starts (DECISIONS 040).
##
## Where: user://save.json. On Windows that's
##   %APPDATA%\Godot\app_userdata\Pixel Harvest\save.json
## It's plain JSON, so it can be opened in Notepad to see exactly what's kept.
##
## The file always looks like:
##   { "save_version": 16, "game": { ...whatever GameState.to_save() returned... } }
##

const SAVE_PATH := "user://save.json"

## Where a save that couldn't be loaded is moved to, so it's never silently
## overwritten. Only the most recent one is kept.
const SET_ASIDE_PATH := "user://save.unreadable.json"

## The version this build of the game writes. Bump it whenever the shape of
## the saved data changes, and add a step to _upgrade() that converts the
## previous version into the new one.
##
## History:
##   1 — first format. Saved the selected tool as a toolbar position, and
##       terrain as a number. Both break if the lists are ever reordered.
##   2 — selected tool saved by id; terrain saved by name.
##   3 — the tool list becomes an inventory of items with counts (seeds are no
##       longer unlimited), and the farm gains a shipping bin.
##   4 — upgrades bought are saved by id; maximum energy is no longer saved,
##       because it's worked out from the upgrades.
##   5 — `day` means the day of the season (1 to days_per_season), not a
##       count of days since the game began.
##   6 — the town: the cliff at the west end of the farm's path opens into a
##       gate (two farm tiles change from CLIFF to PATH). No new fields.
##   7 — the farmhouse: the cells it stands on become BUILDING terrain, and
##       whatever was on them is cleared (sprinklers go back in the bag).
##   8 — requests (quests): which have been taken and finished, and a count
##       for each. Older games have taken none.
##   9 — the difficulty chosen at new game, by id. Older games were all
##       played at what is now "standard".
##  10 — unlocks: what has opened up so far, by name (DECISIONS 043). Older
##       games had everything open, so they're given every unlock there was.
##  11 — hazards (DECISIONS 045): a farm tile can have weeds ("weeds") and a
##       crop a count of nights without water ("dry_nights"). Both are left
##       out when they're nothing, so older tiles already read correctly.
##  12 — weather (DECISIONS 046): today's ("weather") and tomorrow's
##       forecast ("forecast"), by id.
##  13 — crops with rules, session 2 (DECISIONS 048): a crop can have aphids
##       ("pests") and be a giant ("giant"), both left out when false; and
##       every farmer has a trowel, so older games are given one.
##  14 — repeatable requests (DECISIONS 050): a request may have a day it's
##       due by ("due") and run out ("expired"); orders made from patterns
##       (Rosa's, the board's) keep what they were made of ("order"); and
##       "orders_done" counts the orders handed in. Older games have none.
##  15 — the axe and timber (DECISIONS 053): the Woods' undergrowth chopped
##       this season ("cleared": location id -> list of [x, y]). Older games
##       have chopped none. Sprinklers now wait for Brann's line, so older
##       games, which could always buy them, are given its two unlocks.
##  16 — fishing (DECISIONS 054): the fish log ("fish_log": fish id ->
##       {"caught", "biggest"}). Older games have caught nothing.
##  17 — cooking (DECISIONS 056): the recipes known ("recipes": recipe id ->
##       times cooked). Older games know none, except those taught by
##       requests they had already finished (Mabel's leek pies, Wren's river
##       fish), which are given to them.
##  18 — the greenhouse and bees (DECISIONS 057): the greenhouse's plot
##       ("greenhouse", tiles like the farm's), and a hive's honey in the
##       making on its farm tile ("made_days", "made_ready", left out when
##       0). The old greenhouse now stands on the farm, so the cells it
##       stands on become BUILDING terrain and whatever was on them is given
##       back (crops as their seeds, sprinklers and decorations as
##       themselves).
##  19 — fertilisers and late tools (DECISIONS 058): fed soil on a farm or
##       greenhouse tile ("fertiliser": the bag's id, and "kept_wet": nights
##       mulch has kept it wet; both left out when there's none). Ivy's
##       autumn basket now also gives mulch, so an older game that has
##       finished it is given the mulch and Marlow's mulch on sale.
const CURRENT_VERSION := 19

## Fields GameState.load_from_save() relies on, and the kind of value each
## must be. Checked before anything is replaced, so a damaged save can't leave
## the game half-loaded.
const REQUIRED_FIELDS: Dictionary = {
	"difficulty": TYPE_STRING,
	"gold": TYPE_FLOAT,
	"day": TYPE_FLOAT,
	"season": TYPE_FLOAT,
	"year": TYPE_FLOAT,
	"energy": TYPE_FLOAT,
	"upgrades": TYPE_ARRAY,
	"inventory": TYPE_ARRAY,
	"selected_tool": TYPE_STRING,
	"location": TYPE_STRING,
	"farm": TYPE_DICTIONARY,
	"quests": TYPE_DICTIONARY,
	"unlocks": TYPE_ARRAY,
	"weather": TYPE_STRING,
	"forecast": TYPE_STRING,
	"cleared": TYPE_DICTIONARY,
	"fish_log": TYPE_DICTIONARY,
	"recipes": TYPE_DICTIONARY,
	"greenhouse": TYPE_DICTIONARY,
}

## Saving is switched on by load_or_new_game(), i.e. only when the game was
## launched through the boot scene. Running the farm scene on its own (F6)
## plays a throwaway new game, and sleeping there must not overwrite the real
## save.
var _active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	# A stopgap until Stage 9's title screen has a "New game" button. Nothing
	# here runs while the game is paused (in a shop, a conversation, or this
	# menu itself), so Ctrl+N only works out in the world.
	if event.is_action_pressed(&"new_game"):
		get_viewport().set_input_as_handled()
		ask_for_new_game()


## Show the difficulty menu over the game; picking one starts a new game at
## it, and Esc goes back to the game in hand untouched (DECISIONS 040).
func ask_for_new_game() -> void:
	var menu := DifficultyMenu.new()
	menu.can_cancel = true
	menu.chosen.connect(start_new_game)
	get_tree().root.add_child(menu)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Called once by the boot scene. Loads the save if there is one and returns
## true. Otherwise, or if it can't be read, GameState is left as a fresh new
## game at the default difficulty and it returns false: the boot scene then
## asks which difficulty to play at.
func load_or_new_game() -> bool:
	_active = true
	if not has_save():
		GameState.new_game()
		return false
	var problem := _load()
	if problem != "":
		push_error("Couldn't load the save (%s). Starting a new game; the old file has been kept as %s"
				% [problem, ProjectSettings.globalize_path(SET_ASIDE_PATH)])
		DirAccess.rename_absolute(SAVE_PATH, SET_ASIDE_PATH)
		GameState.new_game()
		return false
	print("Loaded save: day %d, %s" % [GameState.day, GameState.difficulty.display_name])
	EventBus.game_loaded.emit()
	return true


## Throw away the game in memory and start again at `difficulty`. The save
## file isn't touched until the next night, so quitting before then gets the
## old game back.
func start_new_game(difficulty: DifficultyDef = null) -> void:
	GameState.new_game(difficulty)
	LocationManager.go_to(GameState.location)


## Write the game to disk. Called by TimeSystem at the end of each night.
##
## Written to a temporary file first and then renamed over the real one, so a
## crash or power cut halfway through writing leaves the previous save intact
## rather than a half-written one.
func save_game() -> void:
	if not _active:
		return
	var data := {"save_version": CURRENT_VERSION, "game": GameState.to_save()}
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write the save: %s" % error_string(FileAccess.get_open_error()))
		return
	# Keys kept in the order written (sort_keys false), so the file opens with
	# save_version, gold and day at the top and the long list of tiles last.
	file.store_string(JSON.stringify(data, "\t", false))
	file.close()
	var error := DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if error != OK:
		push_error("Couldn't replace the save file: %s" % error_string(error))
		return
	EventBus.game_saved.emit()


## Read, upgrade, check and apply the save. Returns "" on success, otherwise
## what went wrong — in which case the game in memory is unchanged.
func _load() -> String:
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text == "":
		return "the file is empty or can't be opened"
	var json := JSON.new()
	if json.parse(text) != OK:
		return "not valid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("save_version")) != TYPE_FLOAT:
		return "no save_version, so it isn't a Pixel Harvest save"

	var version := int(data["save_version"])
	if version > CURRENT_VERSION:
		# Never try to read the future: guessing could quietly lose progress.
		return "it was made by a newer version of the game (save version %d, this game reads up to %d)" % [
			version, CURRENT_VERSION]
	var problem := _upgrade(data)
	if problem != "":
		return problem
	if typeof(data.get("game")) != TYPE_DICTIONARY:
		return "it has no game data"
	problem = _check_fields(data["game"])
	if problem != "":
		return problem

	GameState.load_from_save(data["game"])
	return ""


func _check_fields(game: Dictionary) -> String:
	for field: String in REQUIRED_FIELDS:
		if typeof(game.get(field)) != REQUIRED_FIELDS[field]:
			return "the '%s' field is missing or the wrong kind of value" % field
	var farm: Dictionary = game["farm"]
	if typeof(farm.get("tiles")) != TYPE_ARRAY or typeof(farm.get("width")) != TYPE_FLOAT \
			or typeof(farm.get("height")) != TYPE_FLOAT:
		return "the farm is incomplete"
	var greenhouse: Dictionary = game["greenhouse"]
	if typeof(greenhouse.get("tiles")) != TYPE_ARRAY or typeof(greenhouse.get("width")) != TYPE_FLOAT \
			or typeof(greenhouse.get("height")) != TYPE_FLOAT:
		return "the greenhouse is incomplete"
	for entry: Variant in greenhouse["tiles"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("x")) != TYPE_FLOAT \
				or typeof(entry.get("y")) != TYPE_FLOAT:
			return "a greenhouse tile has no position"
	for entry: Variant in game["inventory"]:
		# A count read from the file is a float (JSON has only one kind of
		# number); one written by an upgrade step may be an int. Either is fine.
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING \
				or typeof(entry.get("count")) not in [TYPE_FLOAT, TYPE_INT]:
			return "the inventory has something that isn't an item id and a count"
	for entry: Variant in game["upgrades"]:
		if typeof(entry) != TYPE_STRING:
			return "the upgrades list has something that isn't an upgrade id"
	for entry: Variant in game["unlocks"]:
		if typeof(entry) != TYPE_STRING:
			return "the unlocks list has something that isn't an unlock name"
	for entry: Variant in farm["tiles"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("x")) != TYPE_FLOAT \
				or typeof(entry.get("y")) != TYPE_FLOAT:
			return "a farm tile has no position"
	return ""


# --- Upgrading old saves -----------------------------------------------------
#
# Every save passes through here, even one already at the current version
# (rule 4). Each step converts exactly one version into the next, so a very
# old save simply walks up the chain: 1 -> 2 -> 3 -> ...
#
# Two rules for writing a step:
#   - It works on the plain dictionary from the file, never on game objects,
#     because the game objects only know the CURRENT format.
#   - It must not depend on anything that can change later. If it needs to
#     know what version N meant by something, that knowledge is written into
#     the step itself (see V1_TERRAIN), not looked up from today's code.

func _upgrade(data: Dictionary) -> String:
	var version := int(data["save_version"])
	while version < CURRENT_VERSION:
		if typeof(data.get("game")) != TYPE_DICTIONARY:
			return "it has no game data"
		match version:
			1:
				_upgrade_1_to_2(data["game"])
			2:
				_upgrade_2_to_3(data["game"])
			3:
				_upgrade_3_to_4(data["game"])
			4:
				_upgrade_4_to_5(data["game"])
			5:
				_upgrade_5_to_6(data["game"])
			6:
				_upgrade_6_to_7(data["game"])
			7:
				_upgrade_7_to_8(data["game"])
			8:
				_upgrade_8_to_9(data["game"])
			9:
				_upgrade_9_to_10(data["game"])
			10:
				_upgrade_10_to_11(data["game"])
			11:
				_upgrade_11_to_12(data["game"])
			12:
				_upgrade_12_to_13(data["game"])
			13:
				_upgrade_13_to_14(data["game"])
			14:
				_upgrade_14_to_15(data["game"])
			15:
				_upgrade_15_to_16(data["game"])
			16:
				_upgrade_16_to_17(data["game"])
			17:
				_upgrade_17_to_18(data["game"])
			18:
				_upgrade_18_to_19(data["game"])
			_:
				return "there's no way to upgrade a version %d save" % version
		version += 1
		data["save_version"] = version
		print("Upgraded save to version %d" % version)
	return ""


## Terrain as save version 1 numbered it. Frozen here on purpose: if the
## Terrain enum in farm_tile.gd is ever reordered, version 1 saves must still
## be read with the numbering they were written with.
const V1_TERRAIN: Array[String] = ["GRASS", "PATH", "WATER", "CLIFF"]


## Version 1 -> 2: the selected tool by id instead of toolbar position, and
## terrain by name instead of number.
func _upgrade_1_to_2(game: Dictionary) -> void:
	var tools: Array = game.get("tools", [])
	var index := int(game.get("selected_tool_index", 0))
	game["selected_tool"] = tools[index] if index >= 0 and index < tools.size() else ""
	game.erase("selected_tool_index")

	var farm: Dictionary = game.get("farm", {})
	for entry: Dictionary in farm.get("tiles", []):
		if entry.has("terrain"):
			var number := int(entry["terrain"])
			entry["terrain"] = V1_TERRAIN[number] if number >= 0 and number < V1_TERRAIN.size() else "GRASS"


## Version 2 -> 3: tools become an inventory, and the farm gets a shipping bin.
##
## Version 2 had a list of tool ids and unlimited seeds. Each tool becomes one
## of that item; seeds become a counted stack. The number of seeds, and the
## cell the bin goes on, are written here rather than read from game_rules or
## FarmLayout, so this step means the same thing however those change later.
const V2_SEED_GRANT: Dictionary = {"parsnip_seeds": 10}
const V3_SHIPPING_BIN := Vector2i(13, 12)


func _upgrade_2_to_3(game: Dictionary) -> void:
	var inventory: Array = []
	for tool_id: Variant in game.get("tools", []):
		inventory.append({"id": tool_id, "count": V2_SEED_GRANT.get(tool_id, 1)})
	game["inventory"] = inventory
	game.erase("tools")

	# The bin's cell is the end of the path, which can never be tilled or
	# planted, so in any version 2 farm it's free. If it somehow isn't, the
	# farm is left alone rather than something being overwritten.
	var farm: Dictionary = game.get("farm", {})
	for entry: Dictionary in farm.get("tiles", []):
		if int(entry.get("x", -999)) == V3_SHIPPING_BIN.x and int(entry.get("y", -999)) == V3_SHIPPING_BIN.y:
			if entry.has("object") or entry.has("crop") or entry.get("tilled", false):
				push_warning("No room for the shipping bin at %s; this farm won't have one" % V3_SHIPPING_BIN)
			else:
				entry["object"] = "shipping_bin"
			return


## Version 3 -> 4: upgrades arrive. A version 3 game had bought none.
##
## max_energy is dropped: from now on it's worked out from the upgrades, and
## with none it's the starting amount. The farm is left exactly as it was —
## a farm from before Stage 5 has no thicket, so all its land stays open and
## the fields simply aren't offered in the shop (DECISIONS 024).
func _upgrade_3_to_4(game: Dictionary) -> void:
	game["upgrades"] = []
	game.erase("max_energy")


## Version 4 -> 5: seasons arrive, and `day` becomes the day of the season.
##
## Before Stage 6 the calendar never left spring, and `day` just counted up.
## A version 4 game still within the first season's days keeps its date. One
## that had gone past it restarts at day 1 of spring, rather than being moved
## on to summer: its crops were planted with no idea seasons existed, so it
## gets a whole spring before the first season change. The season length is
## frozen here (V5_SEASON_DAYS), not read from game_rules.tres, so this step
## means the same thing however the rules change later.
const V5_SEASON_DAYS := 28


func _upgrade_4_to_5(game: Dictionary) -> void:
	# Written as floats, like every number read from JSON, so the field check
	# that follows sees the same kind of value whether or not a step ran.
	var day := int(game.get("day", 1))
	if day < 1 or day > V5_SEASON_DAYS:
		game["day"] = 1.0
	game["season"] = 0.0


## Version 5 -> 6: the town. The farm gets a gate in its western cliff, the
## way out to the town. The map is saved, so an old farm has to be told: two
## border tiles change from CLIFF to PATH. The cells are frozen here
## (V6_TOWN_GATE), not read from FarmLayout, so this step means the same thing
## however the layout changes later. Nothing else about the farm is touched.
const V6_TOWN_GATE: Array[Vector2i] = [Vector2i(-1, 12), Vector2i(-1, 13)]


func _upgrade_5_to_6(game: Dictionary) -> void:
	var farm: Dictionary = game.get("farm", {})
	for entry: Dictionary in farm.get("tiles", []):
		var cell := Vector2i(int(entry.get("x", -999)), int(entry.get("y", -999)))
		if cell in V6_TOWN_GATE:
			entry["terrain"] = "PATH"


## Version 6 -> 7: the farmhouse. It stands north of the path, on cells an old
## farm may have tilled, planted or put sprinklers on. Those cells become
## BUILDING terrain and are cleared: a crop there is lost (the house was built
## on it), a sprinkler goes back into the bag, and a tree is felled. The cells,
## and which object gives back which item, are frozen here (not read from the
## farmhouse's .tres or ContentDB), so this step means the same thing however
## the house or the items change later. The player wakes up in the farmhouse.
const V7_FARMHOUSE := Rect2i(6, 8, 5, 4)
const V7_OBJECT_ITEMS: Dictionary = {"sprinkler": "sprinkler", "big_sprinkler": "big_sprinkler"}


func _upgrade_6_to_7(game: Dictionary) -> void:
	var farm: Dictionary = game.get("farm", {})
	var tiles: Array = farm.get("tiles", [])
	var returned: Array[String] = []
	for entry: Dictionary in tiles:
		var cell := Vector2i(int(entry.get("x", -999)), int(entry.get("y", -999)))
		if not V7_FARMHOUSE.has_point(cell):
			continue
		var object_id: String = entry.get("object", "")
		if V7_OBJECT_ITEMS.has(object_id):
			returned.append(V7_OBJECT_ITEMS[object_id])
		for key in ["object", "tilled", "watered", "crop", "crop_stage", "crop_days", "crop_regrowing"]:
			entry.erase(key)
		entry["terrain"] = "BUILDING"
	var inventory: Array = game.get("inventory", [])
	for item_id in returned:
		var found := false
		for stack: Variant in inventory:
			if typeof(stack) == TYPE_DICTIONARY and stack.get("id", "") == item_id:
				stack["count"] = float(int(stack.get("count", 0)) + 1)
				found = true
				break
		if not found:
			inventory.append({"id": item_id, "count": 1.0})
	game["inventory"] = inventory
	game["location"] = "farmhouse"


## Version 7 -> 8: requests arrive (DECISIONS 038). A version 7 game had taken
## none, so its log starts empty and the townsfolk ask as if for the first time.
func _upgrade_7_to_8(game: Dictionary) -> void:
	game["quests"] = {}


## Version 8 -> 9: difficulty arrives (DECISIONS 040). Every older game was
## played with the prices, energy and growing that are now "standard", so it
## carries on at that. The id is frozen here, not read from game_rules.tres,
## so this step means the same thing however the default changes later.
const V9_DIFFICULTY := "standard"


func _upgrade_8_to_9(game: Dictionary) -> void:
	game["difficulty"] = V9_DIFFICULTY


## Version 9 -> 10: unlocks arrive (DECISIONS 043). Before them every seed,
## upgrade and shop was open from day 1, so an older game is given every
## unlock that existed when they arrived: nobody loses something they had.
## The list is frozen here (V10_UNLOCKS), not read from data/unlocks/, so this
## step means the same thing however many unlocks are added later; ones that
## come after it are earned in the usual way.
##
## The mayor's new opener (bring the first five parsnips) is ticked off as
## done for a game that has already started his welcome request, so he
## doesn't go back a step.
##
## Stage 10 session 2 (DECISIONS 044) added three more unlocks for things a
## version 9 game also had from day 1 (Mabel, the great tools, the north
## field), so they join the list. Version 10 itself didn't change shape, so
## no new save version: a version 10 game earns them in the usual way. Brann's
## request, whose whole point is opening those, is ticked off as done for an
## old game, as the mayor's opener is.
const V10_UNLOCKS: Array[String] = ["hollis_spring", "forge_open", "hollis_summer", "hollis_autumn",
		"mabel_arrives", "great_tools", "north_field_deed"]
const V10_OPENER := "mayor_first_pull"
const V10_AFTER_OPENER := "mayor_first_sale"
const V10_ALREADY_DONE := "blacksmith_prove_it"


func _upgrade_9_to_10(game: Dictionary) -> void:
	game["unlocks"] = V10_UNLOCKS.duplicate()
	var quests: Variant = game.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return
	if quests.has(V10_AFTER_OPENER) and not quests.has(V10_OPENER):
		quests[V10_OPENER] = {"state": "done", "progress": 0.0}
	if not quests.has(V10_ALREADY_DONE):
		quests[V10_ALREADY_DONE] = {"state": "done", "progress": 0.0}


## Version 10 -> 11: hazards arrive (DECISIONS 045). The new tile fields are
## only written when they aren't nothing, and an older tile has neither, so a
## version 10 farm already means "no weeds anywhere, and every crop freshly
## watered as far as thirst goes": no crop is put at risk by the upgrade.
## Nothing to change; the step is here so every version has one (rule 4).
##
## The weeds and the crows wait for unlocks the calendar opens (spring days 6
## and 15). An older game already past those days gets them on load, with the
## other dates it has passed (GameState.open_due_unlocks), and they start that
## night.
func _upgrade_10_to_11(_game: Dictionary) -> void:
	pass


## Version 11 -> 12: weather arrives (DECISIONS 046). An older game's days
## were all fine weather, so today is "sunny" (written here, not looked up,
## so this step means the same thing whatever data/weather/ holds later).
## Tomorrow's is left blank: nobody forecast it, so it's drawn on load from
## the season's odds, as any night would.
func _upgrade_11_to_12(game: Dictionary) -> void:
	game["weather"] = "sunny"
	game["forecast"] = ""


## Version 12 -> 13: aphids, giants and the trowel (DECISIONS 048). The new
## tile fields are only written when true, so an older farm already reads as
## "no aphids, no giants". The trowel is part of the starting kit now, so an
## older game gets one, put just after the watering can on the hotbar (where
## a new game has it), or first if there's no can. Its id is written here,
## not read from game_rules.tres, so this step means the same thing however
## the starting kit changes later.
const V13_TROWEL := "trowel"
const V13_AFTER := "watering_can"


func _upgrade_12_to_13(game: Dictionary) -> void:
	var inventory: Variant = game.get("inventory")
	if typeof(inventory) != TYPE_ARRAY:
		return
	for entry: Variant in inventory:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == V13_TROWEL:
			return
	var at := 0
	for i in inventory.size():
		if typeof(inventory[i]) == TYPE_DICTIONARY and inventory[i].get("id") == V13_AFTER:
			at = i + 1
	inventory.insert(at, {"id": V13_TROWEL, "count": 1})


## Version 13 -> 14: deadlines and orders (DECISIONS 050). An older game's
## requests had no deadlines, so its entries already read correctly; it has
## handed in no orders yet.
func _upgrade_13_to_14(game: Dictionary) -> void:
	game["orders_done"] = 0


## Version 14 -> 15: the axe and timber (DECISIONS 053). An older game has
## chopped nothing in the Woods. Sprinklers and big sprinklers used to be on
## Brann's shelves from the day the forge opened; now Brann's sprinkler line
## (timber and gold) opens them. An older game is given both unlocks and has
## both of Brann's requests ticked off, as version 10 did for his first
## (V10_ALREADY_DONE): nobody loses something they could buy. The names are
## written here, not looked up, so this step means the same thing later.
const V15_UNLOCKS: Array[String] = ["sprinkler_design", "better_pipes"]
const V15_ALREADY_DONE: Array[String] = ["blacksmith_sprinklers", "blacksmith_pipes"]


func _upgrade_14_to_15(game: Dictionary) -> void:
	game["cleared"] = {}
	var unlocks: Variant = game.get("unlocks")
	if typeof(unlocks) == TYPE_ARRAY:
		for id in V15_UNLOCKS:
			if not unlocks.has(id):
				unlocks.append(id)
	var quests: Variant = game.get("quests")
	if typeof(quests) == TYPE_DICTIONARY:
		for id in V15_ALREADY_DONE:
			if not quests.has(id):
				quests[id] = {"state": "done", "progress": 0.0}


## Version 15 -> 16: fishing (DECISIONS 054). An older game has caught no
## fish. Nothing else changes: the rod comes from Wren's first request, which
## an older game simply hasn't been asked yet.
func _upgrade_15_to_16(game: Dictionary) -> void:
	game["fish_log"] = {}


## Version 16 -> 17: cooking (DECISIONS 056). Requests finished before
## recipes existed now teach some; an older game that has already finished
## one is given what it now teaches. Written here, not looked up, so this step
## means the same thing later.
const V17_TAUGHT_BY_DONE: Dictionary = {
	"baker_leek_pies": ["bubble_and_squeak", "fish_pie", "leek_and_potato_soup", "mushrooms_on_toast",
			"pumpkin_soup", "winter_stew"],
	"wren_river_fish": ["grilled_fish"],
}


func _upgrade_16_to_17(game: Dictionary) -> void:
	var recipes := {}
	var quests: Variant = game.get("quests")
	if typeof(quests) == TYPE_DICTIONARY:
		for quest_id: String in V17_TAUGHT_BY_DONE:
			var entry: Variant = quests.get(quest_id)
			if typeof(entry) == TYPE_DICTIONARY and entry.get("state") == "done":
				for recipe_id: String in V17_TAUGHT_BY_DONE[quest_id]:
					recipes[recipe_id] = 0
	game["recipes"] = recipes


## Version 17 -> 18: the greenhouse and bees (DECISIONS 057).
##
## The greenhouse's plot is new: an empty one, every tile dug over, as a new
## game has. It's written out here, not built by GreenhouseLayout, so this
## step means the same thing however the room changes later.
##
## The farm's old greenhouse now stands west of the farmhouse, on cells that
## an older game could have farmed. As version 7 did for the farmhouse, those
## cells become BUILDING terrain and are cleared, but nothing is lost: a crop
## goes back in the bag as its seeds (a tree as its sapling), and a sprinkler
## or a decoration as itself. A crop of several tiles (the apple tree, a
## giant) that reaches into it from outside goes too. Trees and weeds just go.
const V18_PLOT := Rect2i(1, 3, 8, 6)
const V18_GREENHOUSE := Rect2i(0, 9, 5, 3)
## What each placeable object was picked up as when version 18 arrived.
const V18_OBJECT_ITEMS: Dictionary = {
	"sprinkler": "sprinkler", "big_sprinkler": "big_sprinkler", "garden_fence": "garden_fence",
	"garden_flower_bed": "garden_flower_bed", "garden_lamp": "garden_lamp", "hay_bale": "hay_bale",
	"scarecrow": "scarecrow", "sundial": "sundial",
}
## Seeds are the crop's id and "_seeds", except for the crops listed here.
const V18_CROP_SEEDS: Dictionary = {"apple_tree": "apple_sapling"}
## How many tiles square a crop stands on, when it isn't one (giants are 3).
const V18_CROP_SPANS: Dictionary = {"apple_tree": 2}


func _upgrade_17_to_18(game: Dictionary) -> void:
	var plot_tiles: Array = []
	for y in range(V18_PLOT.position.y, V18_PLOT.end.y):
		for x in range(V18_PLOT.position.x, V18_PLOT.end.x):
			plot_tiles.append({"x": float(x), "y": float(y), "tilled": true})
	# Numbers as floats, as they'd be read back from the file.
	game["greenhouse"] = {"width": float(V18_PLOT.size.x), "height": float(V18_PLOT.size.y), "tiles": plot_tiles}

	var farm: Dictionary = game.get("farm", {})
	var returned: Array[String] = []
	for entry: Variant in farm.get("tiles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var cell := Vector2i(int(entry.get("x", -999)), int(entry.get("y", -999)))
		var inside := V18_GREENHOUSE.has_point(cell)
		var crop_id: String = entry.get("crop", "")
		if crop_id != "":
			# A crop's tile is the front-left corner of what it stands on.
			var span: int = 3 if entry.get("giant", false) else int(V18_CROP_SPANS.get(crop_id, 1))
			var area := Rect2i(cell.x, cell.y - span + 1, span, span)
			if area.intersects(V18_GREENHOUSE):
				returned.append(V18_CROP_SEEDS.get(crop_id, crop_id + "_seeds"))
				for key in ["crop", "crop_stage", "crop_days", "crop_regrowing", "dry_nights", "pests", "giant"]:
					entry.erase(key)
		if not inside:
			continue
		var object_id: String = entry.get("object", "")
		if V18_OBJECT_ITEMS.has(object_id):
			returned.append(V18_OBJECT_ITEMS[object_id])
		for key in ["object", "tilled", "watered", "weeds", "made_days", "made_ready"]:
			entry.erase(key)
		entry["terrain"] = "BUILDING"
	var inventory: Variant = game.get("inventory")
	if typeof(inventory) != TYPE_ARRAY:
		return
	for item_id in returned:
		var found := false
		for stack: Variant in inventory:
			if typeof(stack) == TYPE_DICTIONARY and stack.get("id", "") == item_id:
				stack["count"] = float(int(stack.get("count", 0)) + 1)
				found = true
				break
		if not found:
			inventory.append({"id": item_id, "count": 1.0})


## Version 18 -> 19: fertilisers and late tools (DECISIONS 058). No soil is
## fed yet in an older game, so the tiles need nothing. Ivy's autumn basket
## now gives a bag of mulch and puts it on Marlow's shelf: an older game
## that has already handed the basket in is given both. Written out here,
## not looked up in the request, so this step means the same thing later.
const V19_DONE_GIVES: Dictionary = {
	"ivy_autumn_set": {"unlocks": ["mulch_on_sale"], "items": {"mulch": 10}},
}


func _upgrade_18_to_19(game: Dictionary) -> void:
	var quests: Variant = game.get("quests")
	if typeof(quests) != TYPE_DICTIONARY:
		return
	for quest_id: String in V19_DONE_GIVES:
		var entry: Variant = quests.get(quest_id)
		if typeof(entry) != TYPE_DICTIONARY or entry.get("state") != "done":
			continue
		var gives: Dictionary = V19_DONE_GIVES[quest_id]
		var unlocks: Variant = game.get("unlocks")
		if typeof(unlocks) == TYPE_ARRAY:
			for unlock_id: String in gives["unlocks"]:
				if unlock_id not in unlocks:
					unlocks.append(unlock_id)
		var inventory: Variant = game.get("inventory")
		if typeof(inventory) != TYPE_ARRAY:
			continue
		for item_id: String in gives["items"]:
			var count: int = gives["items"][item_id]
			var found := false
			for stack: Variant in inventory:
				if typeof(stack) == TYPE_DICTIONARY and stack.get("id", "") == item_id:
					stack["count"] = float(int(stack.get("count", 0)) + count)
					found = true
					break
			if not found:
				inventory.append({"id": item_id, "count": float(count)})
