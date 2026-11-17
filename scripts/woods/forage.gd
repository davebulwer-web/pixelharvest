class_name Forage
extends RefCounted
##
## Forage — what's growing wild where today (DECISIONS 052).
##
## A place with foraging (its LocationDef has forage_per_day above 0) offers
## a list of spots on its map where something could be: the Woods' clearings
## and path edges. Each morning `forage_per_day` of those spots get something,
## picked by weight among the ForageDefs in season there in today's weather.
##
## Nothing about it is saved. The dice are seeded by the place and the date,
## so the same spots hold the same things however often the player walks in
## and out, and loading the morning's save gives the same morning (the game
## only saves overnight). What has been picked today is GameState's
## (is_foraged), and is forgotten overnight: by morning it has all grown back
## somewhere else.
##
## The map scene asks spots_today() as it opens and puts a ForageSpot on each.
##
## A place by the sea (the Cove, DECISIONS 064) has a second set of spots,
## the rockpools and the sand bar, which only the low tide uncovers: asked for
## with `low_tide`, they get `low_tide_forage_per_day` things from the forage
## that lives there (ForageDef.at_low_tide), with dice of their own. The
## ordinary spots never get that forage, so the Woods and the Lane are as they
## were.
##


## Today's forage in `location`, among `candidates` (the cells its map
## offers, always in the same order): cell -> ForageDef, leaving out what's
## been picked already today (unless `include_picked`: the fallen logs keep
## off every spot today's forage was on, picked or not). Empty for a place
## with no foraging.
static func spots_today(location: LocationDef, candidates: Array[Vector2i],
		include_picked: bool = false, low_tide: bool = false) -> Dictionary:
	var result: Dictionary = {}  # Vector2i -> ForageDef
	if location == null or candidates.is_empty():
		return result
	var count := location.low_tide_forage_per_day if low_tide else location.forage_per_day
	if count <= 0:
		return result
	var weather_id: StringName = GameState.weather.id if GameState.weather != null else &""
	var kinds: Array[ForageDef] = []
	kinds.assign(ContentDB.forage_growing(location.id, GameState.season_id(), weather_id)
			.filter(func(f: ForageDef) -> bool: return f.at_low_tide == low_tide))
	if kinds.is_empty():
		return result
	var total_weight := 0
	for kind: ForageDef in kinds:
		total_weight += kind.weight
	var dice := RandomNumberGenerator.new()
	# The ordinary spots keep the seed they've always had, so the Woods and
	# the Lane lay out exactly as before.
	var salt := "pools/" if low_tide else ""
	dice.seed = hash("forage/%s/%s%d" % [location.id, salt, GameState.day_number()])
	# Shuffle just enough of the list to take the first `count`.
	var pool := candidates.duplicate()
	for i in mini(count, pool.size()):
		var j := dice.randi_range(i, pool.size() - 1)
		var cell: Vector2i = pool[j]
		pool[j] = pool[i]
		pool[i] = cell
		var kind := _pick(kinds, total_weight, dice)
		if include_picked or not GameState.is_foraged(location.id, cell):
			result[cell] = kind
	return result


## One of `kinds`, chosen by weight.
static func _pick(kinds: Array[ForageDef], total_weight: int, dice: RandomNumberGenerator) -> ForageDef:
	var roll := dice.randi_range(1, total_weight)
	for kind in kinds:
		roll -= kind.weight
		if roll <= 0:
			return kind
	return kinds[-1]
