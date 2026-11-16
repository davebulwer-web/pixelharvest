class_name TownLayout
extends RefCounted
##
## TownLayout — the shape of the town: the road, the square, the pond, and
## where every tree, lamp and flower bed stands.
##
## The town has no FarmData: nothing in it changes, so its map is just a
## function from a cell to a ground tile (rule 1 is about the farm's *state*,
## and the town has none). Two things are deliberately NOT here: where the
## shops stand (each shop's LocationDef says where its door is) and where the
## townsfolk stand (each CharacterDef says). town.gd builds from those, so
## adding a shop or a person never edits this file.
##
## The map, roughly (each character is about two cells):
##
##   ~~~~~~~~~~~~~~~~~~~~~ the river ~~~~~~~~~~~~~~~~~~~~~ [=] bridge to the Woods
##        trees  (glasshouse) trees  ~~pond~~ ||
##                                    ~~~~~~~~ ||  angler
##    *  [Seeds]  *  |  * [General] *   * [Smith] * ||  path to the pond
##   ==================== road ==========================  -> farm
##          fence           #  square  #
##       * * garden * *    #   bench    #
##          fence          #  (fountain)#  mayor
##                         #   bench    #
##   (* flower bed, | lamp post, # the square's paving)
##
## The river along the top and the bridge over it came with the Woods
## (DECISIONS 052): the path up past Brann's carries on beside the pond to
## the bridge. Until the bridge is mended, its two cells are water and only
## the broken stumps show; once it's open, they're path under the bridge's
## picture and the edge beyond opens into the Woods.
##

const SIZE := Vector2i(40, 24)

## The two-tile-wide road along the whole town, and where it leaves the east
## edge for the farm.
const ROAD_ROWS: Array[int] = [13, 14]
const FARM_GATE: Array[Vector2i] = [Vector2i(40, 13), Vector2i(40, 14)]

## The paved square south of the road, with the fountain in the middle.
const SQUARE := Rect2i(15, 15, 11, 7)

## The path from the road up past the blacksmith to the pond.
const POND_PATH := Rect2i(35, 6, 2, 7)

const POND := Rect2i(31, 2, 6, 4)

## The river along the top of the town, which feeds the pond (DECISIONS 052).
const RIVER_ROWS: Array[int] = [0, 1]

## From the pond path, on up the east side of the pond to the river.
const BRIDGE_PATH := Rect2i(37, 2, 2, 6)

## The bridge's cells over the river, and the gap in the north edge beyond it
## that leads into the Woods. The bridge is open once the Woods are.
const BRIDGE := Rect2i(37, 0, 2, 2)
const WOODS_GATE: Array[Vector2i] = [Vector2i(37, -1), Vector2i(38, -1)]

## Where the farmer stands on coming back from the Woods: at the town end of
## the bridge, in pixels.
const ARRIVAL_FROM_WOODS := Vector2(608, 44)

## Where the farmer stands on arriving from the farm: in the middle of the
## road, in pixels (the road is rows 13 and 14).
const ARRIVAL_FROM_FARM := Vector2(616, 228)

## Everything standing in the town, by the cell it stands on, naming an
## ObjectDef in data/objects/. The object's picture sits on the bottom of its
## cell, centred; wide ones (the fountain is three cells) spread either side.
const OBJECTS: Dictionary = {
	# The square: fountain in the middle, a bench either side of it, the
	# notice board by the road where you can't miss it, flowers in the corners.
	Vector2i(20, 18): &"fountain",
	Vector2i(17, 18): &"bench",
	Vector2i(23, 18): &"bench",
	Vector2i(18, 15): &"notice_board",
	Vector2i(15, 21): &"flower_bed",
	Vector2i(25, 21): &"flower_bed",
	Vector2i(15, 15): &"lamp_post",
	Vector2i(25, 15): &"lamp_post",

	# Along the north side of the road: a flower bed each side of every shop
	# front, and lamps between the shops.
	Vector2i(5, 12): &"flower_bed",
	Vector2i(11, 12): &"flower_bed",
	Vector2i(17, 12): &"flower_bed",
	Vector2i(23, 12): &"flower_bed",
	Vector2i(28, 12): &"flower_bed",
	Vector2i(34, 12): &"flower_bed",
	Vector2i(2, 12): &"lamp_post",
	Vector2i(14, 12): &"lamp_post",
	Vector2i(26, 12): &"lamp_post",
	Vector2i(38, 12): &"lamp_post",

	# The garden west of the square: a fence along the top and bottom, flower
	# beds between. Its ends are open, so it can be walked through.
	Vector2i(4, 17): &"fence", Vector2i(5, 17): &"fence", Vector2i(6, 17): &"fence",
	Vector2i(7, 17): &"fence", Vector2i(8, 17): &"fence", Vector2i(9, 17): &"fence",
	Vector2i(10, 17): &"fence",
	Vector2i(5, 19): &"flower_bed", Vector2i(6, 19): &"flower_bed",
	Vector2i(8, 19): &"flower_bed", Vector2i(9, 19): &"flower_bed",
	Vector2i(4, 21): &"fence", Vector2i(5, 21): &"fence", Vector2i(6, 21): &"fence",
	Vector2i(7, 21): &"fence", Vector2i(8, 21): &"fence", Vector2i(9, 21): &"fence",
	Vector2i(10, 21): &"fence",

	# Behind the general store: the old
	# glasshouse, broken for years, where Ivy is found from autumn (DECISIONS 049).
	Vector2i(20, 5): &"ruined_glasshouse",

	# Trees: a band along the top, clumps round the south and east edges, kept
	# off the road, the square and the paths.
	Vector2i(2, 3): &"tree", Vector2i(6, 5): &"tree", Vector2i(10, 3): &"tree",
	Vector2i(14, 6): &"tree", Vector2i(17, 3): &"tree", Vector2i(23, 5): &"tree",
	Vector2i(27, 3): &"tree", Vector2i(28, 7): &"tree", Vector2i(39, 8): &"tree",
	Vector2i(1, 9): &"tree", Vector2i(1, 19): &"tree", Vector2i(2, 23): &"tree",
	Vector2i(12, 23): &"tree", Vector2i(13, 19): &"tree", Vector2i(28, 18): &"tree",
	Vector2i(30, 22): &"tree", Vector2i(33, 17): &"tree", Vector2i(36, 20): &"tree",
	Vector2i(38, 23): &"tree", Vector2i(27, 23): &"tree",
}


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of the
## town and its border, given the cells shop doors stand on and whether the
## bridge to the Woods is open. A door cell is path, so the doorstep reads as
## one with the road.
static func build(door_cells: Array[Vector2i], bridge_open: bool = false) -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = _tile_for(cell, door_cells)
	for cell in FARM_GATE:
		tiles[cell] = GroundTiles.path_for(cell)
	if bridge_open:
		for y in range(BRIDGE.position.y, BRIDGE.end.y):
			for x in range(BRIDGE.position.x, BRIDGE.end.x):
				tiles[Vector2i(x, y)] = GroundTiles.PATH
		for cell in WOODS_GATE:
			tiles[cell] = GroundTiles.PATH
	return tiles


## The kind of water at `cell`, for the fishing rod (DECISIONS 054): &"pond",
## &"river", or &"" for dry land. The bridge's cells are river while it's
## broken and dry once it's mended (`bridge_open`).
static func water_at(cell: Vector2i, bridge_open: bool) -> StringName:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return &""
	if POND.has_point(cell):
		return &"pond"
	if cell.y in RIVER_ROWS:
		return &"" if bridge_open and BRIDGE.has_point(cell) else &"river"
	return &""


static func _tile_for(cell: Vector2i, door_cells: Array[Vector2i]) -> Vector2i:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return GroundTiles.CLIFF
	if POND.has_point(cell) or cell.y in RIVER_ROWS:
		return GroundTiles.WATER
	if cell.y in ROAD_ROWS or cell in door_cells:
		return GroundTiles.path_for(cell)
	if SQUARE.has_point(cell):
		return GroundTiles.PAVING
	if POND_PATH.has_point(cell) or BRIDGE_PATH.has_point(cell):
		return GroundTiles.path_for(cell)
	return GroundTiles.grass_for(cell)
