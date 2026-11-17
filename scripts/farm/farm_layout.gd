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
## Buildings on the farm (the farmhouse, Stage 7) aren't written here either:
## each is a LocationDef whose door is on the farm, and the ground under its
## picture becomes BUILDING terrain, which no tool can work.
##
## Fields the player can buy (Stage 5) start as thicket. Where they are isn't
## written here: each field's upgrade .tres knows its own area, and this
## overgrows whatever those areas say. Adding a field is one data file.
##
## Since Stage 19 (DECISIONS 060) the farm is 48 × 32. The farm as it was
## (30 × 20, OLD_GROUND) is the top-left corner, at the same cells, so old
## saves still line up; the new ground east and south of it starts
## overgrown with debris (stones, stumps, brambles, nettles, and a few
## trees), which is the first thing there is to spend energy on.
##

const FARM_SIZE := Vector2i(48, 32)

## The farm as it was until Stage 19: the farmhouse, the pond, the fields
## and the path. Everything else inside FARM_SIZE is the new ground.
const OLD_GROUND := Rect2i(0, 0, 30, 20)

## What stands on each tile of the new ground at the start: each kind with
## its chance, rolled once per tile (the same roll every time, from the
## cell). About a third of the new ground has something on it. The kinds
## are ObjectDef ids (data/objects/); a tree there stays for good.
## The save upgrade to version 21 (save_system.gd) has its own frozen copy
## of these numbers, so changing them here only changes new games.
const DEBRIS_ODDS: Array = [
	[&"stones", 0.10],
	[&"nettles", 0.08],
	[&"bramble", 0.08],
	[&"stump", 0.04],
	[&"tree", 0.02],
]
const POND := Rect2i(21, 3, 5, 4)
const PATH_ROW := 12
const PATH_LENGTH := 14

## The end of the path, right beside where the player wakes up. A path cell
## can never be tilled, so the bin can't end up sitting on a crop.
const SHIPPING_BIN := Vector2i(13, 12)

## The old farmer's workbench, under a lean-to against the farmhouse's east
## wall, faced from the path below it (DECISIONS 063). The save upgrade to
## version 23 puts it here too, or as near as it can.
const WORKBENCH := Vector2i(11, 11)

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
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			var cell := Vector2i(x, y)
			if not OLD_GROUND.has_point(cell):
				farm.tile(cell).object_id = debris_for(cell)
	farm.tile(SHIPPING_BIN).object_id = &"shipping_bin"
	farm.tile(WORKBENCH).object_id = &"workbench"
	_place_buildings(farm)
	_overgrow_fields(farm)
	return farm


## Clear the ground under every building whose door is on the farm, and make
## sure the cell in front of its door is path. Anything standing there (a tree
## in the old layout) gives way to the building.
static func _place_buildings(farm: FarmData) -> void:
	for def: LocationDef in GameState.RULES.locations:
		if def.outside != LocationManager.FARM_ID or def.exterior == null:
			continue
		var area := Building.footprint(def)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var t := farm.tile(Vector2i(x, y))
				if t != null:
					t.terrain = FarmTile.Terrain.BUILDING
					t.object_id = &""
		for door in Building.door_cells(def):
			var doorstep := farm.tile(door + Vector2i.DOWN)
			if doorstep != null and doorstep.terrain == FarmTile.Terrain.GRASS:
				doorstep.terrain = FarmTile.Terrain.PATH


## Turn the grass in every buyable field into thicket. Ponds, paths and trees
## inside a field are left alone — they're still there once it's cleared.
static func _overgrow_fields(farm: FarmData) -> void:
	for upgrade in ContentDB.upgrades():
		var area := upgrade.effect.locked_area() if upgrade.effect != null else Rect2i()
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var t := farm.tile(Vector2i(x, y))
				if t != null and t.terrain == FarmTile.Terrain.GRASS:
					t.terrain = FarmTile.Terrain.THICKET


## What stands on `cell` of the new ground at the start: a DEBRIS_ODDS kind,
## or nothing.
static func debris_for(cell: Vector2i) -> StringName:
	var roll := float(absi(hash([cell, 21, "farm_debris"])) % 1000) / 1000.0
	for entry: Array in DEBRIS_ODDS:
		roll -= entry[1]
		if roll < 0.0:
			return entry[0]
	return &""


## The gaps in the cliffs that lead off the farm (the gate at the west end
## of the path, to the Lane): the farm's exits (data/locations/farm.tres,
## DECISIONS 060). They're part of the farm's map, so they're saved with it:
## saves from before Stage 7 have the gate opened by the version 6 upgrade.
static func gate_cells() -> Array[Vector2i]:
	for def: LocationDef in GameState.RULES.locations:
		if def.id == LocationManager.FARM_ID:
			return Exits.gap_cells(def)
	return []


static func _terrain_for(cell: Vector2i) -> FarmTile.Terrain:
	if cell in gate_cells():
		return FarmTile.Terrain.PATH
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
