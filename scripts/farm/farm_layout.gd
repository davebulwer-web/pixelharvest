class_name FarmLayout
extends RefCounted
##
## FarmLayout — builds the starting farm for a new game.
##
## This is what main.gd used to do with set_cell calls in Stage 1. The same
## layout now produces *data* (a FarmData) instead of painting tiles directly;
## the farm scene then draws whatever FarmData holds.
##
## The layout itself is placeholder and will be replaced when the farm gets a
## designed map. Only this file will change when it does.
##

const FARM_SIZE := Vector2i(30, 20)
const POND := Rect2i(21, 3, 5, 4)
const PATH_ROW := 12
const PATH_LENGTH := 14

## The end of the path, right beside where the player wakes up. A path cell
## can never be tilled, so the bin can't end up sitting on a crop.
const SHIPPING_BIN := Vector2i(13, 12)

const TREE_CELLS: Array[Vector2i] = [
	Vector2i(4, 4), Vector2i(7, 3), Vector2i(5, 8),
	Vector2i(19, 6), Vector2i(23, 10), Vector2i(26, 14),
	Vector2i(10, 16), Vector2i(16, 15), Vector2i(12, 11),
]


static func build_default() -> FarmData:
	var farm := FarmData.new(FARM_SIZE)
	# One cell of border beyond the farm, so the player meets a wall rather
	# than the edge of the world.
	for y in range(-1, FARM_SIZE.y + 1):
		for x in range(-1, FARM_SIZE.x + 1):
			var cell := Vector2i(x, y)
			var t := FarmTile.new()
			t.terrain = _terrain_for(cell)
			farm.set_tile(cell, t)
	for cell in TREE_CELLS:
		farm.tile(cell).object_id = &"tree"
	farm.tile(SHIPPING_BIN).object_id = &"shipping_bin"
	return farm


static func _terrain_for(cell: Vector2i) -> FarmTile.Terrain:
	var outside := (
		cell.x < 0 or cell.y < 0
		or cell.x >= FARM_SIZE.x or cell.y >= FARM_SIZE.y
	)
	if outside:
		return FarmTile.Terrain.CLIFF
	if POND.has_point(cell):
		return FarmTile.Terrain.WATER
	if cell.y == PATH_ROW and cell.x < PATH_LENGTH:
		return FarmTile.Terrain.PATH
	return FarmTile.Terrain.GRASS
