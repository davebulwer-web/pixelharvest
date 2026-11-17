class_name LaneLayout
extends RefCounted
##
## LaneLayout — the shape of the Lane (DECISIONS 060): the country lane
## between the farm and the town, with hedgerows along both sides, the
## allotments to the north and a stream with a ford near the farm end.
##
## Like the Woods and the town, the Lane has no state of its own to save, so
## its map is a function from a cell to a ground tile. What's in the hedges
## to pick today is Forage's business; this file only says where it could be
## (forage_cells). Where the Lane's ends lead is data, not code: the exits
## on data/locations/lane.tres (west to the town, east to the farm).
##
## The map, roughly (64 × 24 tiles, about three screens long):
##
##      trees           trees               trees            ~~  trees
##    | fence ---------------------- |                       ~~
##    | [bed] [bed] || [bed] [bed]   |                       ~~
##    | ======== cross path ======== |                       ~~
##    | [bed] [bed] || [bed] [bed]   |                       ~~
##   #######hedge#### ## ##################### ## ###########~~########
##  =====================================the lane========================== farm
##  town                                                     (ford)
##   ###########hedge########## || ######################## ##~~########
##        trees      meadow    ||   (signpost)       trees   ~~   trees
##                             || cliff path south (the Cove, Stage 21)
##
##   (# hedge, = path, ~~ the stream, [bed] the allotments' beds)
##
## The gaps in the hedges are where things will come in later stages: the
## allotments' path (odd jobs, Stage 20), a gate to Pip's family's cottage
## and one to Dot's yard (Stage 19 session 2), and the cliff path down to
## the Cove (Stage 21). Until then the cliff path stops at a signpost.
##

const SIZE := Vector2i(64, 24)

## The lane itself: two tiles wide, the whole length of the map. The exits
## (lane.tres) are the gaps at either end of these rows.
const ROAD_ROWS: Array[int] = [11, 12]

## The hedgerows either side of the lane, and their gaps (x of the left
## cell of each two-wide gap).
const NORTH_HEDGE_ROW := 9
const SOUTH_HEDGE_ROW := 14
const NORTH_GAPS: Array[int] = [16, 40]
const SOUTH_GAPS: Array[int] = [20, 46]

## The allotments: fenced, with eight beds either side of a path up from
## the lane's gap and a cross path through the middle.
const ALLOTMENTS := Rect2i(5, 1, 25, 8)
const ALLOTMENT_BEDS: Array[Rect2i] = [
	Rect2i(7, 3, 4, 2), Rect2i(12, 3, 3, 2), Rect2i(19, 3, 4, 2), Rect2i(24, 3, 4, 2),
	Rect2i(7, 6, 4, 2), Rect2i(12, 6, 3, 2), Rect2i(19, 6, 4, 2), Rect2i(24, 6, 4, 2),
]
const ALLOTMENT_PATHS: Array[Rect2i] = [
	Rect2i(16, 2, 2, 7),  # up from the lane's gap
	Rect2i(6, 5, 23, 1),  # across the middle
]

## The cliff path, south from the lane's gap to the signpost. The Cove
## (Stage 21) will open the way on to the bottom edge.
const CLIFF_PATH := Rect2i(20, 15, 2, 6)
const SIGNPOST := Vector2i(22, 18)

## The stream: two tiles wide, running the whole height of the Lane near the
## farm end, shallow where the lane crosses it (the ford, drawn as path).
const STREAM_X := 54

## Trees stand one to a 3 × 3 block, at a spot in the block chosen by its
## position, where that spot is open meadow: sparser than the Woods, so the
## Lane reads as fields with trees in them, not forest.
const TREE_SPACING := 3
const TREE_CHANCE := 0.55


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of
## the Lane and its border, given the gap cells of its exits (drawn as path).
static func build(gap_cells: Array[Vector2i]) -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = _tile_for(cell)
	for cell in gap_cells:
		tiles[cell] = GroundTiles.path_for(cell)
	return tiles


static func _tile_for(cell: Vector2i) -> Vector2i:
	if not inside(cell):
		return GroundTiles.CLIFF
	if is_path(cell):
		return GroundTiles.path_for(cell)
	if is_stream(cell):
		return GroundTiles.WATER
	if is_hedge(cell):
		return GroundTiles.THICKET
	if _in_any(cell, ALLOTMENT_BEDS):
		return GroundTiles.TILLED
	return GroundTiles.grass_for(cell)


static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func _in_any(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


## True for a path cell: the lane (and the ford, where it crosses the
## stream), the allotments' paths and the cliff path.
static func is_path(cell: Vector2i) -> bool:
	if not inside(cell):
		return false
	return cell.y in ROAD_ROWS or _in_any(cell, ALLOTMENT_PATHS) or CLIFF_PATH.has_point(cell) \
			or _in_gap(cell)


## True for the cells of a gap in either hedge: path, joining the lane to
## whatever is through it.
static func _in_gap(cell: Vector2i) -> bool:
	if cell.y == NORTH_HEDGE_ROW:
		for x in NORTH_GAPS:
			if cell.x == x or cell.x == x + 1:
				return true
	if cell.y == SOUTH_HEDGE_ROW:
		for x in SOUTH_GAPS:
			if cell.x == x or cell.x == x + 1:
				return true
	return false


## True for the stream (but not the ford, where the lane crosses it).
static func is_stream(cell: Vector2i) -> bool:
	return inside(cell) and (cell.x == STREAM_X or cell.x == STREAM_X + 1) and cell.y not in ROAD_ROWS


## True for hedge: the two hedgerows, apart from their gaps and the stream.
static func is_hedge(cell: Vector2i) -> bool:
	if not inside(cell) or is_stream(cell) or _in_gap(cell):
		return false
	return cell.y == NORTH_HEDGE_ROW or cell.y == SOUTH_HEDGE_ROW


## The kind of water at `cell`, for the fishing rod: none yet. The stream
## fishes from a later stage (ROADMAP 13.2); until then the rod says nothing
## bites here.
static func water_at(_cell: Vector2i) -> StringName:
	return &""


## Everything standing on the Lane, by cell, naming an ObjectDef: the
## allotments' fence, the signpost and the trees. Worked out the same way
## every time, so nothing about it needs saving.
static func objects() -> Dictionary:
	var result: Dictionary = {}  # Vector2i -> StringName
	# The allotments' fence: along the top and down both sides.
	for x in range(ALLOTMENTS.position.x, ALLOTMENTS.end.x):
		result[Vector2i(x, ALLOTMENTS.position.y)] = &"fence"
	for y in range(ALLOTMENTS.position.y + 1, ALLOTMENTS.end.y):
		result[Vector2i(ALLOTMENTS.position.x, y)] = &"fence"
		result[Vector2i(ALLOTMENTS.end.x - 1, y)] = &"fence"
	result[SIGNPOST] = &"signpost"
	for block_y in range(0, SIZE.y, TREE_SPACING):
		for block_x in range(0, SIZE.x, TREE_SPACING):
			var block := Vector2i(block_x, block_y)
			if _roll(block, 3) >= TREE_CHANCE:
				continue
			var cell := block + Vector2i(_pick(block, 1, TREE_SPACING), _pick(block, 2, TREE_SPACING))
			if _is_meadow(cell) and not result.has(cell):
				result[cell] = &"tree"
	return result


## Open grass where a tree may stand: inside, not path, hedge, water or the
## allotments, not in the row beside a path or a hedge (so neither is hidden
## under a canopy), and clear of the signpost.
static func _is_meadow(cell: Vector2i) -> bool:
	if not inside(cell) or is_path(cell) or is_stream(cell) or is_hedge(cell):
		return false
	if ALLOTMENTS.grow(1).has_point(cell):
		return false
	if absi(cell.y - NORTH_HEDGE_ROW) <= 1 or absi(cell.y - SOUTH_HEDGE_ROW) <= 1:
		return false
	if (cell - SIGNPOST).length_squared() <= 2:
		return false
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_path(cell + step) or is_stream(cell + step):
			return false
	return true


## Every cell where hedgerow forage could turn up (DECISIONS 060): the grass
## along the lane side of both hedges, so it's picked on the way past. Always
## in the same order, left to right, so the day's dice see the same list.
static func forage_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in SIZE.x:
		for y: int in [NORTH_HEDGE_ROW + 1, SOUTH_HEDGE_ROW - 1]:
			var cell := Vector2i(x, y)
			var hedge := Vector2i(x, NORTH_HEDGE_ROW if y < ROAD_ROWS[0] else SOUTH_HEDGE_ROW)
			if is_hedge(hedge) and not is_path(cell) and not is_stream(cell):
				result.append(cell)
	return result


## A number from 0 to 1 that is fixed for this cell and salt.
static func _roll(cell: Vector2i, salt: int) -> float:
	return float(_pick(cell, salt, 1000)) / 1000.0


## A whole number from 0 to count - 1 that is fixed for this cell and salt
## (as GroundTiles does for the grass).
static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return absi(hash([cell, salt, "lane"])) % count
