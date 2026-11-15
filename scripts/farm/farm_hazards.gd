class_name FarmHazards
extends RefCounted
##
## FarmHazards — what goes wrong on the farm overnight: crows taking crops,
## weeds coming up, bare soil going back to grass (Stage 11, DECISIONS 045),
## and a storm flattening tall crops (Stage 12, DECISIONS 047).
##
## Thirst isn't here: it's part of growing (a crop that wasn't watered gets a
## night thirstier instead of a night older), so it lives with the growing in
## FarmData.advance_day().
##
## Plain functions on a FarmData, like a tool's action: they change the farm
## only through FarmData's own methods, so every change is announced on
## EventBus as usual. TimeSystem runs them in the night, between the growing
## and the sprinklers, and passes in everything they need to know — the rules,
## the difficulty's multiplier, which hazards have started, and the dice — so
## they never look anything up in GameState. That's also what lets a test run
## a night with fixed dice and check exactly what happened.
##
## `multiplier` is DifficultyDef.hazard_multiplier: 1 is Standard, 0 switches
## all of this off, 1.5 is Hard. It makes weeds more likely (and allows more
## in a night), and makes crows come sooner (fewer unguarded crops) and more
## often.
##


## One night's hazards, in order: the storm first (if today was one,
## `flatten_chance` is its WeatherDef.flattens_tall_crops), then crows (so a
## tile they empty can't also sprout weeds the same night), then weeds, then
## bare soil reverting. Returns the cells crows took crops from (also in
## farm.crows_landed).
static func run_night(farm: FarmData, rules: HazardRules, multiplier: float, season_id: StringName,
		weeds_started: bool, crows_started: bool, rng: RandomNumberGenerator,
		flatten_chance: float = 0.0) -> Array[Vector2i]:
	var taken: Array[Vector2i] = []
	if rules == null or multiplier <= 0.0:
		return taken
	if flatten_chance > 0.0:
		flatten_tall_crops(farm, flatten_chance * multiplier, rng)
	if crows_started:
		taken = send_crows(farm, rules, multiplier, rng)
	if weeds_started and rules.weeds_grow_in(season_id):
		sprout_weeds(farm, rules, multiplier, rng)
		revert_bare_soil(farm, rules, multiplier, rng)
	return taken


# --- Crows -------------------------------------------------------------------

## Every crop no scarecrow is guarding. If there are more than the safe
## number, crows may come and take one or two of them.
static func send_crows(farm: FarmData, rules: HazardRules, multiplier: float,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var taken: Array[Vector2i] = []
	var exposed := unguarded_crops(farm)
	var safe := roundi(rules.crow_safe_crops / multiplier)
	if exposed.size() <= safe:
		return taken
	if rng.randf() >= minf(1.0, rules.crow_chance * multiplier):
		return taken
	var count := rng.randi_range(1, maxi(1, rules.crows_most_taken))
	_shuffle(exposed, rng)
	for cell in exposed.slice(0, count):
		farm.lose_to_crows(cell)
		taken.append(cell)
	return taken


## The cells with a crop on them that no guard (an object whose ObjectDef has
## a protects_radius: the scarecrow) is close enough to protect. Sorted, so
## the same farm and the same dice always give the same night.
static func unguarded_crops(farm: FarmData) -> Array[Vector2i]:
	var guards := _guards(farm)
	var exposed: Array[Vector2i] = []
	for cell: Vector2i in farm.cells():
		if farm.tile(cell).has_crop() and not is_guarded(cell, guards):
			exposed.append(cell)
	exposed.sort()
	return exposed


## True if any guard reaches `cell`. Reach is a circle: a scarecrow with a
## radius of 8 protects every tile whose centre is within 8 tiles of its own.
static func is_guarded(cell: Vector2i, guards: Array) -> bool:
	for guard: Array in guards:
		var radius: int = guard[1]
		if Vector2(cell - (guard[0] as Vector2i)).length_squared() <= radius * radius:
			return true
	return false


## [cell, radius] for every object on the farm that keeps crows off.
static func _guards(farm: FarmData) -> Array:
	var guards: Array = []
	for cell: Vector2i in farm.cells():
		var object_id := farm.tile(cell).object_id
		if object_id == &"":
			continue
		var object_def := ContentDB.object(object_id)
		if object_def != null and object_def.protects_radius > 0:
			guards.append([cell, object_def.protects_radius])
	return guards


# --- Storms ------------------------------------------------------------------

## Each tall crop that has come up (CropDef.tall, past the seed) and has no
## shelter close by is flattened with chance `chance`. Returns the cells.
static func flatten_tall_crops(farm: FarmData, chance: float,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var flattened: Array[Vector2i] = []
	var shelters := _shelters(farm)
	var cells: Array = farm.cells()
	cells.sort()
	for cell: Vector2i in cells:
		var t := farm.tile(cell)
		if not t.has_crop() or not t.crop.tall or t.crop_stage < 1 or is_sheltered(cell, shelters):
			continue
		if rng.randf() < chance:
			farm.flatten(cell)
			flattened.append(cell)
	return flattened


## True if a shelter (a fence) is within its reach of `cell`. Reach is a
## square: a fence with shelters_radius 1 shelters the eight tiles round it.
static func is_sheltered(cell: Vector2i, shelters: Array) -> bool:
	for shelter: Array in shelters:
		var gap: Vector2i = (cell - (shelter[0] as Vector2i)).abs()
		if maxi(gap.x, gap.y) <= int(shelter[1]):
			return true
	return false


## [cell, radius] for every object on the farm that shelters crops from storms.
static func _shelters(farm: FarmData) -> Array:
	var shelters: Array = []
	for cell: Vector2i in farm.cells():
		var object_id := farm.tile(cell).object_id
		if object_id == &"":
			continue
		var object_def := ContentDB.object(object_id)
		if object_def != null and object_def.shelters_radius > 0:
			shelters.append([cell, object_def.shelters_radius])
	return shelters


# --- Weeds -------------------------------------------------------------------

## Each tile of tilled soil, and each tile of grass next to a crop, may sprout
## weeds tonight; no more than most_new_weeds of them do.
static func sprout_weeds(farm: FarmData, rules: HazardRules, multiplier: float,
		rng: RandomNumberGenerator) -> void:
	var chosen: Array[Vector2i] = []
	var cells: Array = farm.cells()
	cells.sort()  # dictionary order isn't something to rely on for repeatable dice
	for cell: Vector2i in cells:
		var t := farm.tile(cell)
		if t.weeds or t.object_id != &"" or t.terrain != FarmTile.Terrain.GRASS:
			continue
		var chance := 0.0
		if t.tilled:
			chance = rules.weed_chance_tilled
		elif farm.is_next_to_crop(cell):
			chance = rules.weed_chance_grass
		if chance > 0.0 and rng.randf() < chance * multiplier:
			chosen.append(cell)
	_shuffle(chosen, rng)
	for cell in chosen.slice(0, maxi(0, roundi(rules.most_new_weeds * multiplier))):
		farm.sprout_weeds(cell)


## Bare tilled soil — no crop, no weeds — may go back to grass tonight.
static func revert_bare_soil(farm: FarmData, rules: HazardRules, multiplier: float,
		rng: RandomNumberGenerator) -> void:
	if rules.untill_chance <= 0.0:
		return
	var cells: Array = farm.cells()
	cells.sort()
	for cell: Vector2i in cells:
		var t := farm.tile(cell)
		if t.tilled and not t.has_crop() and not t.weeds and cell not in farm.crows_landed:
			if rng.randf() < rules.untill_chance * multiplier:
				farm.untill(cell)


## Shuffle with our own dice, not the global ones, so a test can fix them.
static func _shuffle(cells: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
