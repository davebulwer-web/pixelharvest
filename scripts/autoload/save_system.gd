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
##
## Where: user://save.json. On Windows that's
##   %APPDATA%\Godot\app_userdata\Pixel Harvest\save.json
## It's plain JSON, so it can be opened in Notepad to see exactly what's kept.
##
## The file always looks like:
##   { "save_version": 8, "game": { ...whatever GameState.to_save() returned... } }
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
const CURRENT_VERSION := 8

## Fields GameState.load_from_save() relies on, and the kind of value each
## must be. Checked before anything is replaced, so a damaged save can't leave
## the game half-loaded.
const REQUIRED_FIELDS: Dictionary = {
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
}

## Saving is switched on by load_or_new_game(), i.e. only when the game was
## launched through the boot scene. Running the farm scene on its own (F6)
## plays a throwaway new game, and sleeping there must not overwrite the real
## save.
var _active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	# A stopgap until Stage 9's title screen has a "New game" button.
	if event.is_action_pressed(&"new_game"):
		start_new_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Called once by the boot scene. Loads the save if there is one; otherwise,
## or if it can't be read, the game carries on as a new game.
func load_or_new_game() -> void:
	_active = true
	if not has_save():
		GameState.new_game()
		return
	var problem := _load()
	if problem != "":
		push_error("Couldn't load the save (%s). Starting a new game; the old file has been kept as %s"
				% [problem, ProjectSettings.globalize_path(SET_ASIDE_PATH)])
		DirAccess.rename_absolute(SAVE_PATH, SET_ASIDE_PATH)
		GameState.new_game()
		return
	print("Loaded save: day %d" % GameState.day)
	EventBus.game_loaded.emit()


## Throw away the game in memory and start again. The save file isn't touched
## until the next night, so quitting before then gets the old game back.
func start_new_game() -> void:
	GameState.new_game()
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
	for entry: Variant in game["inventory"]:
		# A count read from the file is a float (JSON has only one kind of
		# number); one written by an upgrade step may be an int. Either is fine.
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING \
				or typeof(entry.get("count")) not in [TYPE_FLOAT, TYPE_INT]:
			return "the inventory has something that isn't an item id and a count"
	for entry: Variant in game["upgrades"]:
		if typeof(entry) != TYPE_STRING:
			return "the upgrades list has something that isn't an upgrade id"
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
