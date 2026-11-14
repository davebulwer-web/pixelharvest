class_name GroundTiles
extends RefCounted
##
## GroundTiles — where each kind of ground sits in the seasonal ground tilesets
## (assets/tilesets/ground_<season>.png). Every season shares this layout
## (DECISIONS 021, 026), so the farm and the town draw with the same numbers.
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

## Roughly how much of the grass uses the variant tile. Purely cosmetic: which
## grass tile a cell shows is a drawing decision, not a fact about the world.
const GRASS_VARIATION := 0.18


## Plain or flowery grass for `cell`. hash() gives the same answer for the same
## cell every run, so the pattern is stable without storing anything.
static func grass_for(cell: Vector2i) -> Vector2i:
	if float(hash(cell) % 1000) / 1000.0 < GRASS_VARIATION:
		return GRASS_ALT
	return GRASS
