class_name WoodsLayout
extends RefCounted
##
## WoodsLayout — the shape of the Woods (DECISIONS 052): clearings joined by
## paths, a stream down the east side with a footbridge, patches of
## undergrowth, and trees everywhere else.
##
## Like the town, the Woods have no state of their own to save, so the map is
## a function from a cell to a ground tile, and the trees are worked out from
## the same rules every time. What's lying about to be foraged changes daily,
## but that's Forage's business; this file only says which cells could hold
## something (forage_cells).
##
## The map, roughly (48 × 32 tiles, about one and a half screens each way):
##
##        trees          [north glade]         trees    ~~
##                             ||                        ~~
##   [west  ]                [   middle   ]               ~~    [east ]
##   [glade ] ============== [  clearing  ] ============= == ===[glade]
##   [###   ]                [         ###]             ~~      [ ### ]
##                                 ||                    ~~
##      [south-west] ==============||                     ~~
##      [ hollow ###]              ||                     ~~
##                               (to town)
##   (= and || paths, ~~ the stream, == over it the footbridge, ### undergrowth;
##    everywhere else is trees, too close together to walk between)
##
## Bigger than the town (40 × 24) so it feels like a place to explore, as
## ROADMAP Stage 14 suggests. The way in is the bottom of the south path, from
## the new bridge at the top of the town's pond path.
##

const SIZE := Vector2i(48, 32)

## The gap in the south edge that leads back over the bridge to the town.
const TOWN_GATE: Array[Vector2i] = [Vector2i(23, 32), Vector2i(24, 32)]

## Where the farmer stands on arriving from the town, in pixels: on the south
## path, just inside the edge.
const ARRIVAL_FROM_TOWN := Vector2(384, 492)

## The paths, each two tiles wide.
const PATHS: Array[Rect2i] = [
	Rect2i(23, 19, 2, 13),  # south: from the town gate up to the middle clearing
	Rect2i(23, 6, 2, 5),    # north: from the middle clearing to the north glade
	Rect2i(10, 14, 7, 2),   # west: to the west glade
	Rect2i(31, 14, 9, 2),   # east: over the footbridge to the east glade
	Rect2i(13, 25, 10, 2),  # south-west: to the hollow
]

## The open glades, where most of the forage turns up.
const CLEARINGS: Array[Rect2i] = [
	Rect2i(17, 11, 14, 8),  # the middle clearing
	Rect2i(19, 2, 10, 4),   # the north glade
	Rect2i(3, 9, 7, 10),    # the west glade
	Rect2i(40, 9, 6, 12),   # the east glade, over the stream
	Rect2i(5, 22, 8, 7),    # the south-west hollow
]

## Thick undergrowth at the edges of the glades: solid, like the farm's
## thicket. Stage 14 session 2's axe can clear it for timber.
const THICKETS: Array[Rect2i] = [
	Rect2i(3, 16, 3, 2),   # the west glade's bottom corner
	Rect2i(28, 16, 2, 2),  # the middle clearing's bottom corner
	Rect2i(43, 18, 3, 2),  # the east glade's bottom
	Rect2i(10, 26, 2, 2),  # the hollow's corner
]

## The stream: two tiles wide, running the whole height of the Woods. For row
## y its left tile is STREAM_X + STREAM_BENDS[y], so it wanders a little.
## Rows 14 and 15 must match: the footbridge crosses there.
const STREAM_X := 35
const STREAM_BENDS: Array[int] = [
	2, 2, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0,
	-1, -1, -1, 0, 0, 1, 1, 2, 2, 2, 1, 1, 0, 0, -1, -1,
]

## The footbridge's cells: the east path where it crosses the stream.
const FOOTBRIDGE := Rect2i(35, 14, 2, 2)

## Trees stand one to a 2 × 2 block, at a spot in the block chosen by its
## position (the same every time), wherever that spot is wild ground. That
## close, their tops overlap into one canopy and the trunks are too close to
## squeeze between: the glades and paths are the way through.
const TREE_SPACING := 2


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of
## the Woods and its border.
static func build() -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = _tile_for(cell)
	for cell in TOWN_GATE:
		tiles[cell] = GroundTiles.path_for(cell)
	return tiles


static func _tile_for(cell: Vector2i) -> Vector2i:
	if not _inside(cell):
		return GroundTiles.CLIFF
	if is_path(cell):
		return GroundTiles.path_for(cell)
	if is_stream(cell):
		return GroundTiles.WATER
	if _in_any(cell, THICKETS):
		return GroundTiles.THICKET
	return GroundTiles.grass_for(cell)


static func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func _in_any(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


## True for a path cell, including the footbridge over the stream.
static func is_path(cell: Vector2i) -> bool:
	return _in_any(cell, PATHS) or FOOTBRIDGE.has_point(cell)


## True for water: the stream (but not under the footbridge).
static func is_stream(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= STREAM_BENDS.size() or FOOTBRIDGE.has_point(cell):
		return false
	var left := STREAM_X + STREAM_BENDS[cell.y]
	return cell.x == left or cell.x == left + 1


## True for ground that's open: a path or a clearing.
static func is_open(cell: Vector2i) -> bool:
	return is_path(cell) or _in_any(cell, CLEARINGS)


## Wild ground, where trees grow: inside the map, not open, not water or
## undergrowth, and not right beside a path (so the paths stay two tiles wide
## to walk along, and the trees' canopies don't hide them).
static func _is_wild(cell: Vector2i) -> bool:
	if not _inside(cell) or is_open(cell) or is_stream(cell) or _in_any(cell, THICKETS):
		return false
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_path(cell + step):
			return false
	return true


## Everything standing in the Woods, by cell, naming an ObjectDef: the trees.
## Worked out the same way every time, so nothing about it needs saving.
static func objects() -> Dictionary:
	var result: Dictionary = {}  # Vector2i -> StringName
	for block_y in range(0, SIZE.y, TREE_SPACING):
		for block_x in range(0, SIZE.x, TREE_SPACING):
			var block := Vector2i(block_x, block_y)
			var cell := block + Vector2i(_pick(block, 1, TREE_SPACING), _pick(block, 2, TREE_SPACING))
			if _is_wild(cell):
				result[cell] = &"tree"
	return result


## Every cell where forage could turn up (DECISIONS 052): the grass of the
## clearings and the grass along the paths' edges. Never a path itself (the
## footbridge would be a strange place for a mushroom), never under a tree.
## Always in the same order, top row first, so the day's dice see the same
## list every time.
static func forage_cells() -> Array[Vector2i]:
	var trees := objects()
	var result: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			if is_path(cell) or is_stream(cell) or _in_any(cell, THICKETS) or trees.has(cell):
				continue
			if _in_any(cell, CLEARINGS) or _beside_path(cell):
				result.append(cell)
	return result


static func _beside_path(cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_path(cell + step) and not FOOTBRIDGE.has_point(cell + step):
			return true
	return false


## A whole number from 0 to count - 1 that is fixed for this cell and salt
## (as GroundTiles does for the grass).
static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return absi(hash([cell, salt, "woods"])) % count
