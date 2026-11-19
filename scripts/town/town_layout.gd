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
##   ~~~~~~~~~~~~~~~~~~~~~ the river ~~~~~~~~~~~~~~~~~~~~~ [=] ~~~~~~~~~~~~~~
##        trees  (glasshouse) trees  ~~pond~~  ||      /Wren's\
##                                    bank     ||      |cottage|
##   | [ Seeds ] | [General] [Bakery] * [Smith]  ||   ||
##   ==================== road ===================================  -> the Lane
##          fence           #  square  #  ||
##       * * garden * *    #   bench    #  ||  /  the Wheatsheaf  \
##          fence          #  (fountain)#  ||  |   (Nell's tavern) |
##      /town hall\   /mayor's house\       ||  |_______[  ]_______|
##   ======================= Back Street ===========================
##   (* flower bed, | lamp post, # the square's paving)
##
## The town grew to 48 × 32 in Stage 22 (DECISIONS 068) without moving any of
## the old cells: the new ground is east (Wren's cottage by the river, more
## road to the Lane) and south (Back Street, with the town hall, the mayor's
## house and the tavern, reached down Tavern Lane beside the square).
##
## The river along the top and the bridge over it came with the Woods
## (DECISIONS 052): the path up past Brann's carries on beside the pond to
## the bridge. Until the bridge is mended, its two cells are water and only
## the broken stumps show; once it's open, they're path under the bridge's
## picture and the edge beyond opens into the Woods.
##

const SIZE := Vector2i(48, 32)

## The two-tile-wide road along the whole town. Where it leaves the east edge
## for the Lane is town.tres's exits (DECISIONS 060).
const ROAD_ROWS: Array[int] = [13, 14]

## The paved square south of the road, with the fountain in the middle.
const SQUARE := Rect2i(15, 15, 11, 7)

## The path from the road up past the blacksmith to the pond, and on to the
## bridge path (moved a cell east in Stage 23, to make room for the forge).
const POND_PATH := Rect2i(36, 4, 2, 9)

## The pond, by the river. Since Stage 23 (DECISIONS 069) it's two rows
## deep, not four: Brann's forge, at the new size, stands where its south
## bank was, so the bank is now the two rows between the pond and the
## forge's roof, reached from the pond path (where Wren fishes and the
## fishing contest is held).
const POND := Rect2i(31, 2, 6, 2)

## The lane south from the road beside the square, down to Back Street
## (DECISIONS 068), and Back Street itself, along the bottom of the town,
## where the town hall, the mayor's house and the tavern have their doors.
const TAVERN_LANE := Rect2i(27, 15, 2, 14)
const BACK_STREET := Rect2i(6, 29, 36, 2)

## The path from Wren's cottage door (wren_cottage.tres: door cell (43, 9), a
## 96 × 96 picture, so the doorway is cells 43 and 44) down to the road.
const WREN_PATH := Rect2i(43, 10, 2, 3)

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

	# Along the north side of the road. Since Stage 23 (DECISIONS 069) the
	# shops are at the new size (8 cells wide: the seed shop x 3-10, the
	# general store 12-19, the bakery 21-26, the forge 28-35), so there's a
	# one-cell gap between each: a lamp in one, flowers in another, and the
	# one at x 20 left open, the way up to the old glasshouse.
	Vector2i(2, 12): &"lamp_post",
	Vector2i(11, 12): &"lamp_post",
	Vector2i(27, 12): &"flower_bed",
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
	Vector2i(17, 3): &"tree", Vector2i(23, 5): &"tree",
	Vector2i(27, 3): &"tree", Vector2i(39, 8): &"tree",
	Vector2i(1, 9): &"tree", Vector2i(1, 19): &"tree", Vector2i(2, 23): &"tree",
	Vector2i(13, 19): &"tree", Vector2i(33, 17): &"tree",

	# The new ground (DECISIONS 068). Trees on the east side and in the
	# corners, kept off Back Street, Tavern Lane and the buildings' plots
	# (the town hall x 9-16, the mayor's house x 19-26 and the tavern x
	# 30-39, rows 21-28; Wren's cottage x 41-46, rows 4-9).
	Vector2i(40, 3): &"tree", Vector2i(47, 6): &"tree",
	Vector2i(41, 17): &"tree", Vector2i(44, 16): &"tree", Vector2i(47, 18): &"tree",
	Vector2i(42, 21): &"tree", Vector2i(45, 23): &"tree", Vector2i(41, 25): &"tree",
	Vector2i(46, 26): &"tree", Vector2i(44, 29): &"tree", Vector2i(47, 31): &"tree",
	Vector2i(5, 24): &"tree", Vector2i(1, 27): &"tree", Vector2i(3, 30): &"tree",
	Vector2i(0, 31): &"tree",
	# Lamps along Back Street, between the buildings.
	Vector2i(18, 28): &"lamp_post", Vector2i(29, 28): &"lamp_post", Vector2i(41, 28): &"lamp_post",
	# A bench by the tavern door, and flowers by the mayor's.
	Vector2i(37, 31): &"bench", Vector2i(17, 28): &"flower_bed",
}


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of the
## town and its border, given the cells shop doors stand on, the gap cells of
## the town's exits (drawn as path) and whether the bridge to the Woods is
## open. A door cell is path, so the doorstep reads as one with the road.
static func build(door_cells: Array[Vector2i], gap_cells: Array[Vector2i] = [],
		bridge_open: bool = false) -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = _tile_for(cell, door_cells)
	for cell in gap_cells:
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
	if TAVERN_LANE.has_point(cell) or BACK_STREET.has_point(cell) or WREN_PATH.has_point(cell):
		return GroundTiles.path_for(cell)
	return GroundTiles.grass_for(cell)
