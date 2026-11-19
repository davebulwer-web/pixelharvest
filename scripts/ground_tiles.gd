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


## How to lay down the tile `coords` at `cell` (0 = as drawn). Grass, path and
## thicket are turned and mirrored at random, which hides the repeat of a
## single 16 px tile — without it they show a lattice. (The thicket's
## collision box is the whole square, so turning it changes nothing.) A detail
## is only mirrored left-right, so tufts and flowers still grow upwards.
## Everything else is drawn as is: the paving's stones only line up one way
## round, and the pond and cliffs look wrong turned. Sand and the rockpools are
## turned like grass. The sea is only mirrored (Stage 23): its wave crests run
## left to right, so turning it would stand them on end.
static func transform_for(cell: Vector2i, coords: Vector2i) -> int:
	if coords in [GRASS, GRASS_ALT, PATH, THICKET, SAND, WET_SAND, ROCKPOOL]:
		return _ALL_TRANSFORMS[_pick(cell, 4, _ALL_TRANSFORMS.size())]
	if coords == SEA:
		# The first four ways in the list: as is and the three mirrorings.
		return _ALL_TRANSFORMS[_pick(cell, 4, 4)]
	if coords.y == GRASS_DETAIL_ROW or coords.y == PATH_DETAIL_ROW:
		return TileSetAtlasSource.TRANSFORM_FLIP_H if _pick(cell, 5, 2) == 1 else 0
	return 0


## Draw ground tile `coords` at `cell` on `layer`, turned as transform_for says.
## The farm and the town both draw through this, so they look alike.
static func draw(layer: TileMapLayer, cell: Vector2i, coords: Vector2i) -> void:
	layer.set_cell(cell, SOURCE_ID, coords, transform_for(cell, coords))


## A number from 0 to 1 that is fixed for this cell and salt.
static func _roll(cell: Vector2i, salt: int) -> float:
	return float(_pick(cell, salt, 1000)) / 1000.0


## A whole number from 0 to count - 1 that is fixed for this cell and salt.
static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return absi(hash([cell, salt])) % count
