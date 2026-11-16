class_name FallenLogs
extends RefCounted
##
## FallenLogs — where the day's fallen logs lie, for the axe (DECISIONS 053).
##
## Worked out like forage (Forage, DECISIONS 052): each morning a place with
## `fallen_logs_per_day` above 0 gets that many logs, on spots its map offers,
## with dice seeded by the place and the date. So the same logs lie in the
## same places however often the player walks in and out, nothing about them
## is saved, and by the next morning there are new ones somewhere else. What
## has been chopped today is GameState's (is_log_chopped).
##
## A log lies across two tiles: the cell given and the one to its right.
## Logs keep off today's forage, and off each other with a tile's gap all
## round, so they never wall anything in.
##


## Today's logs in `location`: the left-hand cell of each, among `candidates`
## (the left-hand cells the map offers, always in the same order), keeping
## off every cell in `avoid` (today's forage). Leaves out logs chopped today.
static func today(location: LocationDef, candidates: Array[Vector2i], avoid: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if location == null or location.fallen_logs_per_day <= 0 or candidates.is_empty():
		return result
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("logs/%s/%d" % [location.id, GameState.day_number()])
	var pool := candidates.duplicate()
	var placed: Array[Vector2i] = []
	# Shuffle the pool as we go, taking the first that fits, until there are
	# enough or none are left.
	for i in pool.size():
		if placed.size() >= location.fallen_logs_per_day:
			break
		var j := dice.randi_range(i, pool.size() - 1)
		var cell: Vector2i = pool[j]
		pool[j] = pool[i]
		pool[i] = cell
		if avoid.has(cell) or avoid.has(cell + Vector2i.RIGHT) or _too_close(cell, placed):
			continue
		placed.append(cell)
	for cell in placed:
		if not GameState.is_log_chopped(location.id, cell):
			result.append(cell)
	return result


## True if a log at `cell` would touch one already placed (a tile's gap all
## round: each log is two tiles wide).
static func _too_close(cell: Vector2i, placed: Array[Vector2i]) -> bool:
	for other in placed:
		if absi(cell.x - other.x) <= 3 and absi(cell.y - other.y) <= 1:
			return true
	return false
