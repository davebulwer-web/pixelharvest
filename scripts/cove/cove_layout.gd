class_name CoveLayout
extends RefCounted
##
## CoveLayout — the shape of the Cove (DECISIONS 064): the harbour, the beach,
## the cliffs and the shore the tide uncovers.
##
## Like the Lane and the Woods, the Cove has no state of its own to save, so
## its map is a function from a cell (and whether the tide is out) to a
## ground tile. What lies on the beach and in the rockpools today is Forage's
## business; this file only says where it could be. Where the Cove's two ways
## out lead is data (cove.tres's exits): the coast road east to the town,
## and the cliff path up to the Lane. The buildings (the lighthouse, Tam's
## fish shed, Rosa's cottage) are LocationDefs with their doors here, built
## by cove.gd; this file keeps the ground under them clear.
##
## The map, roughly (56 × 36 tiles):
##
##     trees        trees     /Rosa's \        trees
##   /\        ___________    |cottage|
##  |  |      | Tam's shed|   |__[ ]__|
##  |  |      |___[ ]_____|=======coast road=================== town
##  |[]|   (tide       ||                          ##########
##  ===========quay=====       grass slope          ## cliff  ======= the Lane
##  ====================                          ||#########   (cliff path)
##  ~~~~~~~~#~~~~~~~~ RR ...........dry beach......||#########
##  ~~~~~~~~#~~~~~~~~ RR ..................strand line.########
##  ~~harbour#~~~~~~~ RR ,,,,,,,,wet sand,,,,,,,,,ooooooooooooooo
##  ~~~~~~~~#~~~~~~~~ RR ,,,,,,,,,,,,,,,,,,,,,,,,,ooo rockpools ooo
##  ~~~~~~~~#~~~~~~~~~~~~~~~~~~~~~~ ,, ~~~~~~~~~~~ooooooooooooooooo
##  ~~~~~~~~~~~~~~~~~~~~~~~~~~~ ,, sand bar ~~~~~~~~~~~~~~~~~~~~~~~
##  ~~~~~~~~~~~~~~~~~~~~~~~ oooooooo islet ~~~~~~~~~~~~~~~~~~~~~~~~
##  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##
##   (~ sea, # the pier, RR the breakwater's rocks, = path and the quay's
##    paving, . dry sand, , wet sand, o rocks with pools)
##
## The shore below the strand line (the wet sand, the rocky shelf under the
## cliffs, the sand bar and its islet) is uncovered only while the tide is out
## (Tides). Then it's walkable and its rockpools are picked over; when the
## tide comes back in it's sea again, and anyone still out on it splashes back
## to the strand line (shore_for).
##

const SIZE := Vector2i(56, 36)

## The coast road: two tiles wide, from the quay's path to the east edge,
## where it leaves for the town (cove.tres).
const ROAD := Rect2i(16, 10, 40, 2)

## Down from the road to the quay.
const QUAY_PATH := Rect2i(16, 12, 2, 2)

## The harbour's quay, paved like the town square, in front of the lighthouse
## and Tam's shed.
const QUAY := Rect2i(0, 14, 20, 6)

## The harbour: always sea, sheltered by the breakwater.
const HARBOUR := Rect2i(0, 20, 18, 16)

## The pier, out from the quay into the harbour (sea fishing comes with
## Tam's handline, Stage 21 session 2).
const PIER := Rect2i(8, 20, 2, 10)

## The breakwater: rocks between the harbour and the beach.
const BREAKWATER := Rect2i(18, 20, 2, 9)

## The dry beach: sand from the breakwater to the cliff path, above the tide.
const BEACH := Rect2i(20, 20, 22, 6)

## The strand line: the beach's bottom two rows, where the sea leaves shells,
## sea glass, weed and (after a storm) driftwood. Ordinary forage spots.
const STRAND_ROWS: Array[int] = [24, 25]

## The cliffs at the east end, and the cliff path through them: up from the
## beach, then east along a ledge to the edge, where it climbs to the Lane
## (cove.tres).
const CLIFFS := Rect2i(44, 12, 12, 14)
const CLIFF_PATH: Array[Rect2i] = [Rect2i(42, 16, 14, 2), Rect2i(42, 18, 2, 8)]

## Uncovered only at low tide: the wet sand below the strand line, the rocky
## shelf under the cliffs, the sand bar and the islet at its end.
const WET_SAND: Array[Rect2i] = [Rect2i(20, 26, 22, 3), Rect2i(28, 29, 2, 3)]
const ROCK_SHELF: Array[Rect2i] = [Rect2i(38, 26, 18, 5), Rect2i(25, 32, 8, 3)]

## Where the harbour's tide board stands, on the quay by the path down.
const TIDE_BOARD := Vector2i(15, 15)

## The buildings' plots (their doors are on their LocationDefs: the
## lighthouse (3, 13), 64 × 128, so x 2–5 rows 6–13; Tam's shed (10, 13),
## 128 × 96, so x 7–14 rows 8–13; Rosa's cottage (26, 9), 128 × 96, so x
## 23–30 rows 4–9), kept clear of trees with a cell to spare.
const PLOTS: Array[Rect2i] = [Rect2i(1, 5, 15, 9), Rect2i(22, 3, 10, 7)]

## Trees stand one to a 3 × 3 block on the grass, as on the Lane.
const TREE_SPACING := 3
const TREE_CHANCE := 0.5


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of
## the Cove and its border, given the gap cells of its exits and its
## buildings' doorways (both drawn as path) and whether the tide is out.
static func build(gap_cells: Array[Vector2i], door_cells: Array[Vector2i], tide_out: bool) -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = tile_for(cell, tide_out)
	for cell in gap_cells + door_cells:
		tiles[cell] = GroundTiles.path_for(cell)
	return tiles


## The ground at `cell`, with the tide out or in. Outside the map: sea below
## the quay's top, cliff above it.
static func tile_for(cell: Vector2i, tide_out: bool) -> Vector2i:
	if not inside(cell):
		return GroundTiles.SEA if cell.y >= HARBOUR.position.y else GroundTiles.CLIFF
	if is_tidal(cell):
		if not tide_out:
			return GroundTiles.SEA
		return GroundTiles.ROCKPOOL if _in_any(cell, ROCK_SHELF) else GroundTiles.WET_SAND
	if PIER.has_point(cell):
		return GroundTiles.PIER
	if BREAKWATER.has_point(cell):
		return GroundTiles.ROCKS
	if is_path(cell):
		return GroundTiles.path_for(cell)
	if CLIFFS.has_point(cell):
		return GroundTiles.CLIFF
	if QUAY.has_point(cell):
		return GroundTiles.PAVING
	if BEACH.has_point(cell):
		return GroundTiles.SAND
	if cell.y >= HARBOUR.position.y:
		return GroundTiles.SEA
	return GroundTiles.grass_for(cell)


static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func _in_any(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


## True for the shore the tide covers and uncovers: the wet sand, the rocky
## shelf, the sand bar and the islet.
static func is_tidal(cell: Vector2i) -> bool:
	return inside(cell) and (_in_any(cell, WET_SAND) or _in_any(cell, ROCK_SHELF))


## True for a path cell: the coast road, the way down to the quay and the
## cliff path.
static func is_path(cell: Vector2i) -> bool:
	return inside(cell) and (ROAD.has_point(cell) or QUAY_PATH.has_point(cell) or _in_any(cell, CLIFF_PATH))


## True for sea at `cell` with the tide out or in: the harbour and the open
## sea always, the tidal shore only while the tide is in. The pier and the
## breakwater are dry.
static func is_sea(cell: Vector2i, tide_out: bool) -> bool:
	return tile_for(cell, tide_out) == GroundTiles.SEA


## Where someone standing on the tidal shore when the tide comes in ends up:
## straight up the beach to the strand line (or the foot of the cliff path,
## from the shelf under the cliffs).
static func shore_for(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, BEACH.position.x, BEACH.end.x - 1), STRAND_ROWS[-1])


## Every cell where the sea leaves something on the beach (DECISIONS 064):
## the strand line, left to right, always in the same order.
static func strand_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in STRAND_ROWS:
		for x in range(BEACH.position.x, BEACH.end.x):
			result.append(Vector2i(x, y))
	return result


## Every cell where something lives in a rockpool: the rocky shelf and the
## islet, uncovered at low tide. Always in the same order.
static func pool_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rect in ROCK_SHELF:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				result.append(Vector2i(x, y))
	return result


## The kind of water at `cell`, for the fishing rod: none yet. Sea fishing
## comes with Tam's handline (Stage 21 session 2); until then nothing bites.
static func water_at(_cell: Vector2i) -> StringName:
	return &""


## Everything standing in the Cove, by cell, naming an ObjectDef: the tide
## board and the trees on the grass. Worked out the same way every time.
static func objects() -> Dictionary:
	var result: Dictionary = {}  # Vector2i -> StringName
	result[TIDE_BOARD] = &"tide_board"
	for block_y in range(0, HARBOUR.position.y, TREE_SPACING):
		for block_x in range(0, SIZE.x, TREE_SPACING):
			var block := Vector2i(block_x, block_y)
			if _roll(block, 3) >= TREE_CHANCE:
				continue
			var cell := block + Vector2i(_pick(block, 1, TREE_SPACING), _pick(block, 2, TREE_SPACING))
			if _is_grass_for_tree(cell):
				result[cell] = &"tree"
	return result


## Grass where a tree may stand: not path, cliff, quay or beach, not on a
## building's plot, not beside a path (so the road isn't hidden under a
## canopy), and not in the row above the beach or the quay.
static func _is_grass_for_tree(cell: Vector2i) -> bool:
	if not inside(cell) or cell.y >= QUAY.position.y - 1:
		return false
	if tile_for(cell, false) == GroundTiles.CLIFF or is_path(cell) or _in_any(cell, PLOTS):
		return false
	if QUAY.grow(1).has_point(cell) or BEACH.grow(1).has_point(cell) or CLIFFS.grow(1).has_point(cell):
		return false
	if (cell - TIDE_BOARD).length_squared() <= 2:
		return false
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_path(cell + step):
			return false
	return true


static func _roll(cell: Vector2i, salt: int) -> float:
	return float(_pick(cell, salt, 1000)) / 1000.0


static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return absi(hash([cell, salt, "cove"])) % count
