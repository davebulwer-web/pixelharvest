class_name TownLayout
extends RefCounted
##
## TownLayout — the shape of the town: where the road runs, the pond, the trees
## and the way back to the farm.
##
## The town has no FarmData: nothing in it changes, so its map is just a
## function from a cell to a ground tile (rule 1 is about the farm's *state*,
## and the town has none). Where the shops stand is not here either: each
## shop's LocationDef says where its door is, and town.gd builds from those.
## As with FarmLayout, this is the placeholder layout; only this file changes
## when the town gets a designed map.
##

const SIZE := Vector2i(40, 24)

## The two-tile-wide road along the whole town, and where it leaves the east
## edge for the farm.
const ROAD_ROWS: Array[int] = [13, 14]
const FARM_GATE: Array[Vector2i] = [Vector2i(40, 13), Vector2i(40, 14)]

const POND := Rect2i(31, 2, 6, 4)

## Where the farmer stands on arriving from the farm: in the middle of the
## road, in pixels (the road is rows 13 and 14).
const ARRIVAL_FROM_FARM := Vector2(616, 228)

const TREE_CELLS: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(5, 6), Vector2i(3, 9), Vector2i(12, 4), Vector2i(14, 8),
	Vector2i(22, 3), Vector2i(25, 7), Vector2i(37, 9), Vector2i(38, 6),
	Vector2i(36, 19), Vector2i(30, 20), Vector2i(24, 18), Vector2i(18, 20),
	Vector2i(10, 19), Vector2i(5, 17), Vector2i(2, 21), Vector2i(13, 16),
	Vector2i(27, 16), Vector2i(34, 22), Vector2i(8, 22), Vector2i(21, 22),
]


## The ground tile (an atlas coordinate, see GroundTiles) for every cell of the
## town and its border, given the cells shop doors stand on. A door cell is
## path, so the doorstep reads as one with the road.
static func build(door_cells: Array[Vector2i]) -> Dictionary:
	var tiles: Dictionary = {}
	for y in range(-1, SIZE.y + 1):
		for x in range(-1, SIZE.x + 1):
			var cell := Vector2i(x, y)
			tiles[cell] = _tile_for(cell, door_cells)
	for cell in FARM_GATE:
		tiles[cell] = GroundTiles.PATH
	return tiles


static func _tile_for(cell: Vector2i, door_cells: Array[Vector2i]) -> Vector2i:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return GroundTiles.CLIFF
	if POND.has_point(cell):
		return GroundTiles.WATER
	if cell.y in ROAD_ROWS or cell in door_cells:
		return GroundTiles.PATH
	return GroundTiles.grass_for(cell)
