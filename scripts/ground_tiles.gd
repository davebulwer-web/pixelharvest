class_name GroundTiles
extends RefCounted
##
## GroundTiles — where each kind of ground sits in the seasonal ground tilesets
## (assets/tilesets/ground_<season>.png). Every season shares this layout
## (DECISIONS 021, 026, 031, 032), so the farm and the town draw with the same
## numbers.
##
## Row 0 holds one tile per kind of ground. Row 1 holds the grass "details":
## the plain grass tile with something small drawn in its middle (a tuft, a
## flower, a pebble...). The middle only, never the edges, so a detail tile
## still joins its neighbours without a seam. Row 2 does the same for the dirt
## path, and row 3 holds the paving of the town square.
##
## art/build_ground.py makes rows 1 to 3 from the sources in art/ground_sources/.
##
## Since Stage 23 (DECISIONS 072) each season's ground tileset has a second
## picture source, the EDGES (assets/tilesets/edges_<season>.png, made by
## art/build_ground_edges.py): the soft edges GroundEdges draws where two kinds
## of ground meet. Its layout is described at EDGE_GROUNDS below.
##

const SOURCE_ID := 0
const GRASS := Vector2i(0, 0)
const GRASS_ALT := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const TILLED := Vector2i(3, 0)
const TILLED_WET := Vector2i(4, 0)
const WATER := Vector2i(5, 0)
const CLIFF := Vector2i(7, 0)
const THICKET := Vector2i(8, 0)
const PAVING := Vector2i(0, 3)

## The Cove's ground (DECISIONS 064), in row 3 after the paving: dry sand,
## wet sand and the rocky shelf with its pools (both uncovered only at low
## tide), the sea, the pier's planks and rocks. The sea and the rocks are
## solid, like the pond and the cliffs. Real art since Stage 23 (DECISIONS 070):
## Pixellab terrain tiles, kept in art/ground_sources/cove/.
const SAND := Vector2i(1, 3)
const WET_SAND := Vector2i(2, 3)
const ROCKPOOL := Vector2i(3, 3)
const SEA := Vector2i(4, 3)
const PIER := Vector2i(5, 3)
const ROCKS := Vector2i(6, 3)

## How many detail tiles row 1 holds, left to right from column 0. Every
## season's ground image must have this many.
const GRASS_DETAIL_COUNT := 8
const GRASS_DETAIL_ROW := 1
const PATH_DETAIL_COUNT := 4
const PATH_DETAIL_ROW := 2

## Roughly how much of the grass uses the flowery tile, and how much shows a
## detail. Purely cosmetic: which grass tile a cell shows is a drawing
## decision, not a fact about the world, so it is never saved.
const GRASS_VARIATION := 0.15
const GRASS_DETAIL_CHANCE := 0.09
const PATH_DETAIL_CHANCE := 0.12

## Godot can draw any atlas tile mirrored or turned without a second copy in
## the image: these flags go in set_cell()'s alternative_tile argument.
## Eight ways to lay a square tile down (as is, mirrored, turned...).
const _ALL_TRANSFORMS: Array[int] = [
	0,
	TileSetAtlasSource.TRANSFORM_FLIP_H,
	TileSetAtlasSource.TRANSFORM_FLIP_V,
	TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
			| TileSetAtlasSource.TRANSFORM_FLIP_V,
]


## Which grass tile `cell` shows: plain, flowery, or one of the details.
## hash() gives the same answer for the same cell every run, so the pattern is
## stable without storing anything. Different salts keep the three choices
## independent of each other.
static func grass_for(cell: Vector2i) -> Vector2i:
	if _roll(cell, 1) < GRASS_DETAIL_CHANCE:
		return Vector2i(_pick(cell, 2, GRASS_DETAIL_COUNT), GRASS_DETAIL_ROW)
	if _roll(cell, 3) < GRASS_VARIATION:
		return GRASS_ALT
	return GRASS


## Plain path or one of the path details (a pebble, a twig, a leaf...) for
## `cell`, chosen the same way as grass_for().
static func path_for(cell: Vector2i) -> Vector2i:
	if _roll(cell, 6) < PATH_DETAIL_CHANCE:
		return Vector2i(_pick(cell, 7, PATH_DETAIL_COUNT), PATH_DETAIL_ROW)
	return PATH


## How to lay down the tile `coords` at `cell` (0 = as drawn). Grass and path
## are turned and mirrored at random, which hides the repeat of a single 16 px
## tile — without it they show a lattice. The hedge (thicket) is laid as drawn
## since its calm picture (DECISIONS 087): it is lit from the top, and its
## plain tile has to meet its edge pictures exactly. A detail
## is only mirrored left-right, so tufts and flowers still grow upwards.
## Everything else is drawn as is: the paving's stones only line up one way
## round, and the pond and cliffs look wrong turned. Sand and the rockpools are
## turned like grass. The sea is only mirrored (Stage 23): its wave crests run
## left to right, so turning it would stand them on end.
static func transform_for(cell: Vector2i, coords: Vector2i) -> int:
	if coords in [GRASS, GRASS_ALT, PATH, SAND, WET_SAND, ROCKPOOL]:
		return _ALL_TRANSFORMS[_pick(cell, 4, _ALL_TRANSFORMS.size())]
	if coords == SEA:
		# The first four ways in the list: as is and the three mirrorings.
		return _ALL_TRANSFORMS[_pick(cell, 4, 4)]
	if coords.y == GRASS_DETAIL_ROW or coords.y == PATH_DETAIL_ROW:
		return TileSetAtlasSource.TRANSFORM_FLIP_H if _pick(cell, 5, 2) == 1 else 0
	return 0


## Draw ground tile `coords` at `cell` on `layer`, turned as transform_for says.
## Every outdoor map draws through this, so they look alike. If the layer has
## soft edges (GroundEdges), they're told, and redraw round the cell.
static func draw(layer: TileMapLayer, cell: Vector2i, coords: Vector2i) -> void:
	layer.set_cell(cell, SOURCE_ID, coords, transform_for(cell, coords))
	var edges := GroundEdges.of(layer)
	if edges != null:
		edges.mark(cell)


# --- Soft edges (DECISIONS 072) ------------------------------------------------

## The second picture source in every season's ground tileset: the edges.
const EDGE_SOURCE_ID := 1

## The kinds of ground that get soft edges, LOWEST FIRST. Each is drawn over
## anything lower with a ragged or rounded edge, so grass (high) spills over
## the path, and the path over the sand. The cliffs and the pier aren't here:
## they keep square edges (edge_ground() gives -1).
enum EdgeGround { SEA, WATER, WET_SAND, ROCKPOOL, SAND, PATH, PAVING, TILLED, TILLED_WET, GRASS, ROCKS, THICKET }

## The plain tile of each EdgeGround, in the same order.
const EDGE_GROUNDS: Array[Vector2i] = [
	SEA, WATER, WET_SAND, ROCKPOOL, SAND, PATH, PAVING, TILLED, TILLED_WET, GRASS, ROCKS, THICKET,
]

## The edge pictures' layout: one row per EdgeGround and variant (row =
## ground * EDGE_VARIANTS + variant), sixteen columns, one per MASK: which of
## the picture tile's four corners the ground covers (1 top-left, 2 top-right,
## 4 bottom-left, 8 bottom-right, added up). Column 0 (covers nothing) and 15
## (covers everything: the plain tile is used instead) are left empty. Two
## variants of each, so a long straight edge doesn't repeat every tile.
const EDGE_VARIANTS := 2

## After the edges, one row of scatter: small things on a clear background,
## drawn along the joins (GroundEdges). Columns 0-5 grow on grass (tufts,
## flowers), 6-7 are stones.
const SCATTER_ROW := 24
const SCATTER_GREEN := 6
const SCATTER_COUNT := 8

## Grass over pond water has rows of its own (session 5, DECISIONS 073): a
## sandy, stony bank instead of the lip grass shows over a path. Two variants.
const BANK_ROW := 25

## The foam on the sea's edge (DECISIONS 073): one picture per mask (which
## corners are NOT sea), on its own layer under everything that sits on the
## sea. Row 27 holds the first frame; the tileset animates each one through
## the three rows below it, so the foam runs up the shore and back.
const FOAM_ROW := 27


## Which EdgeGround the ground tile `coords` is, or -1 for ground that keeps
## square edges (the cliff, the pier, anything unknown).
static func edge_ground(coords: Vector2i) -> int:
	if coords == GRASS_ALT or coords.y == GRASS_DETAIL_ROW:
		return EdgeGround.GRASS
	if coords.y == PATH_DETAIL_ROW:
		return EdgeGround.PATH
	return EDGE_GROUNDS.find(coords)


## The plain tile drawn whole for `ground` at `corner` (GroundEdges' bottom
## layer): grass and path vary as they do on the grid.
static func edge_fill(ground: int, corner: Vector2i) -> Vector2i:
	if ground == EdgeGround.GRASS:
		return grass_for(corner)
	if ground == EdgeGround.PATH:
		return path_for(corner)
	return EDGE_GROUNDS[ground]


## The edge picture of `ground` covering the corners in `mask`, drawn over
## `lowest`, the lowest ground at that corner. Grass over pond water gets a
## bank; everything else has one set, whatever it lies over.
static func edge_tile(ground: int, mask: int, corner: Vector2i, lowest: int = -1) -> Vector2i:
	var variant := pick(corner, 9, EDGE_VARIANTS)
	if ground == EdgeGround.GRASS and lowest == EdgeGround.WATER:
		return Vector2i(mask, BANK_ROW + variant)
	return Vector2i(mask, ground * EDGE_VARIANTS + variant)


## The foam picture for a corner where the sea meets something; `mask` is the
## corners that are NOT sea.
static func foam_tile(mask: int) -> Vector2i:
	return Vector2i(mask, FOAM_ROW)


## TEST (DECISIONS 078): the cliffs drawn as raised ground, one picture per
## mix of open sides, in a row of the edge pictures after the foam's. Only the
## calm test's tilesets have this row; without it a cliff is the plain CLIFF
## tile, square, as before. `open_sides` adds 1 if the cell to the north is
## not cliff, 2 east, 4 south, 8 west.
const CLIFF_ROW := 31


## The cliff picture for a cliff cell with these open sides. A cliff two
## cells or more from top to bottom has a face two tiles high: the cell just
## above the foot (`above_face`) shows the face's upper half, from the next
## row, whose columns are chosen the same way.
static func cliff_tile(open_sides: int, above_face: bool = false) -> Vector2i:
	return Vector2i(open_sides, CLIFF_ROW + 1 if above_face else CLIFF_ROW)


## TEST (DECISIONS 080): the harbour's pictures, after the cliffs' rows, only
## in the harbour test's tilesets. The pier's deck, one picture per mix of
## open sides (as the cliffs), and what stands in the sea just south of the
## harbour's edges (FRONT_ROW: animated, four frames down): the quay wall, the
## pier's posts and the breakwater's foot.
const PIER_ROW := 33
const FRONT_ROW := 34
enum Front { QUAY, QUAY_LADDER, QUAY_LEFT, QUAY_RIGHT, POSTS_LEFT, POSTS_MID, POSTS_RIGHT, POSTS_SINGLE, BREAKWATER, BREAKWATER_END }


static func pier_tile(open_sides: int) -> Vector2i:
	return Vector2i(open_sides, PIER_ROW)


static func front_tile(front: Front) -> Vector2i:
	return Vector2i(front, FRONT_ROW)


## A scatter piece for a join between the grounds `kinds` at `corner`, or
## (-1, -1) for a join that takes none (water's edge, the tilled beds, the
## sea). Grass joins get tufts, flowers or a stone; sandy and stony joins a
## stone.
static func scatter_for(kinds: Array, corner: Vector2i) -> Vector2i:
	for kind: int in kinds:
		if kind in [EdgeGround.TILLED, EdgeGround.TILLED_WET, EdgeGround.SEA, EdgeGround.WATER]:
			return Vector2i(-1, -1)
	if EdgeGround.GRASS in kinds:
		return Vector2i(pick(corner, 10, SCATTER_COUNT), SCATTER_ROW)
	return Vector2i(SCATTER_GREEN + pick(corner, 10, SCATTER_COUNT - SCATTER_GREEN), SCATTER_ROW)


## A number from 0 to 1 that is fixed for this cell and salt.
static func roll(cell: Vector2i, salt: int) -> float:
	return float(pick(cell, salt, 1000)) / 1000.0


## A whole number from 0 to count - 1 that is fixed for this cell and salt.
static func pick(cell: Vector2i, salt: int, count: int) -> int:
	return absi(hash([cell, salt])) % count


static func _roll(cell: Vector2i, salt: int) -> float:
	return roll(cell, salt)


static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return pick(cell, salt, count)
