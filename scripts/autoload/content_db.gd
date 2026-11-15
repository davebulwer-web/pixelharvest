extends Node
##
## ContentDB — the catalogue of everything the game contains: every crop and
## every item, found by id, plus the lists the shop needs.
##
## It builds itself by reading the content folders when the game starts, so
## adding a crop is dropping files into data/ — nothing here needs editing
## (rule 3). Then it checks the content hangs together (every crop has
## produce, every packet of seeds plants a real crop, and so on) and reports
## anything wrong in the Output panel, naming the file. A content mistake
## should be a clear message at startup, not a puzzle twenty minutes into
## playing.
##
## Two separate sets of ids: crops (&"parsnip" the plant) and items
## (&"parsnip" the vegetable, &"parsnip_seeds", &"hoe"). An id must be unique
## within its set.
##
## Where things live (DECISIONS 023, 024):
##   data/crops/     CropDef — how a plant grows and looks
##   data/produce/   ItemDef — what a harvest gives you, and its sell price
##   data/tools/     ToolDef — tools, seeds and sprinklers (all things you use)
##   data/objects/   ObjectDef — things standing on the farm: trees, the bin,
##                   sprinklers
##   data/upgrades/  UpgradeDef — bought once: tool tiers, energy, fields
##   data/characters/ CharacterDef — townsfolk you can talk to (not shopkeepers)
##

const CROPS_DIR := "res://data/crops/"
const ITEM_DIRS: Array[String] = ["res://data/tools/", "res://data/produce/"]
const OBJECTS_DIR := "res://data/objects/"
const UPGRADES_DIR := "res://data/upgrades/"
const CHARACTERS_DIR := "res://data/characters/"

## For checking crops name real seasons. Read directly rather than through
## GameState, because ContentDB starts first.
const RULES: GameRules = preload("res://data/game_rules.tres")

var _crops: Dictionary = {}  # StringName -> CropDef
var _items: Dictionary = {}  # StringName -> ItemDef (ToolDef is an ItemDef)
var _objects: Dictionary = {}  # StringName -> ObjectDef
var _upgrades: Dictionary = {}  # StringName -> UpgradeDef
var _characters: Dictionary = {}  # StringName -> CharacterDef


func _ready() -> void:
	_index(CROPS_DIR, _crops)
	for dir in ITEM_DIRS:
		_index(dir, _items)
	_index(OBJECTS_DIR, _objects)
	_index(UPGRADES_DIR, _upgrades)
	_index(CHARACTERS_DIR, _characters)
	_check()
	print("ContentDB: %d crops, %d items, %d objects, %d upgrades, %d characters"
			% [_crops.size(), _items.size(), _objects.size(), _upgrades.size(), _characters.size()])


## The crop with this id, or null if there isn't one (for example, a save from
## before a crop was removed from the game).
func crop(id: StringName) -> CropDef:
	return _crops.get(id)


## Every crop in the game, by name (the notice board lists them).
func crops() -> Array[CropDef]:
	var result: Array[CropDef] = []
	for each: CropDef in _crops.values():
		result.append(each)
	result.sort_custom(func(a: CropDef, b: CropDef) -> bool: return a.display_name < b.display_name)
	return result


## The item with this id — produce, seeds or tool — or null.
func item(id: StringName) -> ItemDef:
	return _items.get(id)


## What a farm object id (FarmTile.object_id) means, or null.
func object(id: StringName) -> ObjectDef:
	return _objects.get(id)


## The townsperson with this id, or null.
func character(id: StringName) -> CharacterDef:
	return _characters.get(id)


## Everyone who lives in `location_id`, by id, so they're always built in the
## same order.
func characters_in(location_id: StringName) -> Array[CharacterDef]:
	var result: Array[CharacterDef] = []
	for each: CharacterDef in _characters.values():
		if each.location == location_id:
			result.append(each)
	result.sort_custom(func(a: CharacterDef, b: CharacterDef) -> bool: return a.id < b.id)
	return result


## The upgrade with this id, or null.
func upgrade(id: StringName) -> UpgradeDef:
	return _upgrades.get(id)


## Every upgrade in the game, owned or not, cheapest first. Which ones are on
## offer right now is Economy's question, because it depends on the game.
func upgrades() -> Array[UpgradeDef]:
	var result: Array[UpgradeDef] = []
	for each: UpgradeDef in _upgrades.values():
		result.append(each)
	result.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool:
		if a.price != b.price:
			return a.price < b.price
		return a.display_name < b.display_name
	)
	return result


## Everything the shop sells, cheapest first. An item is on sale simply by
## having a buy_price, so stocking the shop is a data change.
func shop_stock() -> Array[ItemDef]:
	var stock: Array[ItemDef] = []
	for each: ItemDef in _items.values():
		if each.buy_price > 0:
			stock.append(each)
	stock.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.buy_price != b.buy_price:
			return a.buy_price < b.buy_price
		return a.display_name < b.display_name
	)
	return stock


## Load every .tres in `dir` and file it under its own `id` field.
##
## ResourceLoader.list_directory rather than DirAccess: in an exported game the
## .tres files are converted and renamed, and list_directory reports the names
## as they were in the project, so this works the same in the editor and in a
## Windows build.
func _index(dir: String, into: Dictionary) -> void:
	for file_name: String in ResourceLoader.list_directory(dir):
		if not file_name.ends_with(".tres"):
			continue
		var path := dir + file_name
		var resource := load(path)
		var id: StringName = resource.get(&"id") if resource != null else &""
		if id == &"":
			push_error("ContentDB: '%s' has no id, so nothing can refer to it" % path)
			continue
		if into.has(id):
			# Two files claiming one id would make saves load the wrong thing
			# depending on file order. Say so loudly and keep the first.
			push_error("ContentDB: '%s' reuses the id '%s'" % [path, id])
			continue
		into[id] = resource


# --- Checking the content ----------------------------------------------------
# Nothing here stops the game. Each problem is reported with the file to fix,
# and the game carries on with whatever does work.

func _check() -> void:
	var planted: Dictionary = {}  # crop id -> true, for crops some seeds plant
	var season_ids: Array[StringName] = []
	for theme: SeasonTheme in RULES.seasons:
		if theme == null or theme.id == &"":
			push_error("ContentDB: game_rules.tres has a season with no id")
		elif theme.id in season_ids:
			push_error("ContentDB: game_rules.tres lists the season '%s' twice" % theme.id)
		else:
			season_ids.append(theme.id)
	if RULES.days_per_season < 1:
		push_error("ContentDB: game_rules.tres has days_per_season below 1")
	for each: ItemDef in _items.values():
		var where := each.resource_path
		if each.icon == null:
			push_warning("ContentDB: '%s' has no icon, so it shows as a blank square" % where)
		if each is ToolDef:
			var tool_def := each as ToolDef
			if tool_def.action == null:
				push_error("ContentDB: '%s' has no action, so using it does nothing" % where)
			elif tool_def.action is PlantAction:
				var seed_crop: CropDef = tool_def.action.crop
				if seed_crop == null:
					push_error("ContentDB: '%s' doesn't say which crop it plants" % where)
				elif crop(seed_crop.id) != seed_crop:
					push_error("ContentDB: '%s' plants a crop that isn't in %s" % [where, CROPS_DIR])
				else:
					planted[seed_crop.id] = true
			elif tool_def.action is PlaceObjectAction:
				if object(tool_def.action.object_id) == null:
					push_error("ContentDB: '%s' places an object '%s' that isn't in %s"
							% [where, tool_def.action.object_id, OBJECTS_DIR])
			for tier in tool_def.tiers:
				if tier == null or tier.display_name == "":
					push_error("ContentDB: '%s' has a tier with no name" % where)

	for each: CropDef in _crops.values():
		var where := each.resource_path
		if each.produce == null:
			push_error("ContentDB: '%s' has no produce, so harvesting it gives nothing" % where)
		elif item(each.produce.id) != each.produce:
			push_error("ContentDB: '%s' gives produce that isn't in data/produce/" % where)
		if each.sprite_sheet == null:
			push_warning("ContentDB: '%s' has no sprite_sheet, so it can't be seen" % where)
		elif each.sprite_sheet.get_width() % (each.growth_stages + 1) != 0:
			push_warning("ContentDB: '%s' needs %d frames in its sprite sheet (seed + %d stages)"
					% [where, each.growth_stages + 1, each.growth_stages])
		if not planted.has(each.id):
			push_warning("ContentDB: no seeds plant '%s', so it can never be grown" % each.id)
		for season_id in each.seasons:
			if not season_ids.has(season_id):
				push_error("ContentDB: '%s' grows in a season '%s' that isn't in game_rules.tres"
						% [where, season_id])

	# A season nothing grows in is allowed (a winter rest, say), but it's worth
	# knowing about, in case it's a typo in a crop file.
	for season_id in season_ids:
		if not _crops.values().any(func(c: CropDef) -> bool: return c.grows_in(season_id)):
			push_warning("ContentDB: no crop grows in '%s'" % season_id)

	for each: ObjectDef in _objects.values():
		var where := each.resource_path
		if each.scene == null:
			push_error("ContentDB: '%s' has no scene, so it can't be shown" % where)
		if each.item != null and item(each.item.id) != each.item:
			push_error("ContentDB: '%s' gives back an item that isn't in data/tools/" % where)

	# The bed's location must exist, or nights have nowhere to happen.
	if not RULES.locations.any(func(l: LocationDef) -> bool: return l != null and l.id == RULES.home_location):
		push_error("ContentDB: game_rules.tres home_location '%s' isn't one of its locations"
				% RULES.home_location)

	# Every kind of upgrade should be sold somewhere, or it can never be bought.
	var sold_categories: Array[StringName] = []
	var shop_ids: Array[StringName] = []
	for location in RULES.locations:
		if location == null or location.id == &"":
			push_error("ContentDB: game_rules.tres lists a location with no id")
		elif location.scene_path == "" or not ResourceLoader.exists(location.scene_path):
			push_error("ContentDB: location '%s' has no scene at '%s'" % [location.id, location.scene_path])
		if location.outside != &"":
			if location.exterior == null:
				push_error("ContentDB: '%s' has a door on '%s' but no exterior picture"
						% [location.id, location.outside])
			if not RULES.locations.any(func(l: LocationDef) -> bool: return l.id == location.outside):
				push_error("ContentDB: '%s' has its door on '%s', which isn't a location"
						% [location.id, location.outside])
		if location.shop != null:
			var shop := location.shop
			if shop.id != location.id:
				push_error("ContentDB: shop '%s' sits in location '%s'; the ids must match, because the keeper is found by shop id"
						% [shop.id, location.id])
			if shop.id in shop_ids:
				push_error("ContentDB: two shops use the id '%s'" % shop.id)
			shop_ids.append(shop.id)
			if shop.keeper_sprite == null:
				push_warning("ContentDB: shop '%s' has no keeper_sprite, so the counter is empty" % shop.id)
			if shop.greetings.is_empty():
				push_warning("ContentDB: shop '%s' has no greetings; the menu will open without a word" % shop.id)
			for category in shop.upgrade_categories:
				sold_categories.append(category)

	# Townsfolk and shopkeepers share one set of names on EventBus.npc_talked_to,
	# so a character can't use a shop's id.
	for each: CharacterDef in _characters.values():
		var where := each.resource_path
		if each.id in shop_ids:
			push_error("ContentDB: '%s' uses the id '%s', which is a shop's; talking to one would answer as the other"
					% [where, each.id])
		if not RULES.locations.any(func(l: LocationDef) -> bool: return l.id == each.location):
			push_error("ContentDB: '%s' lives in '%s', which isn't a location in game_rules.tres"
					% [where, each.location])
		if each.spots.is_empty():
			push_error("ContentDB: '%s' has no spots, so there's nowhere to stand" % where)
		if each.sprite == null:
			push_warning("ContentDB: '%s' has no sprite, so they can't be seen" % where)
		if each.lines.is_empty():
			push_warning("ContentDB: '%s' has no lines, so talking to them does nothing" % where)

	for each: UpgradeDef in _upgrades.values():
		var where := each.resource_path
		if each.effect != null and each.effect.category() not in sold_categories:
			push_warning("ContentDB: '%s' is a '%s' upgrade, which no shop sells"
					% [where, each.effect.category()])
		if each.effect == null:
			push_error("ContentDB: '%s' has no effect, so buying it does nothing" % where)
		elif each.effect is ToolTierEffect:
			var tier_effect := each.effect as ToolTierEffect
			if tier_effect.tool == null or item(tier_effect.tool.id) != tier_effect.tool:
				push_error("ContentDB: '%s' upgrades a tool that isn't in data/tools/" % where)
			elif tier_effect.tier < 1 or tier_effect.tier > tier_effect.tool.max_tier():
				push_error("ContentDB: '%s' gives tier %d, but '%s' only has tiers 1 to %d"
						% [where, tier_effect.tier, tier_effect.tool.id, tier_effect.tool.max_tier()])
		if each.requires != null and upgrade(each.requires.id) != each.requires:
			push_error("ContentDB: '%s' requires an upgrade that isn't in %s" % [where, UPGRADES_DIR])
		if each.price <= 0:
			push_warning("ContentDB: '%s' has no price, so it's free" % where)
