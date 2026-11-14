extends Node2D
##
## Farm — the Stage 1 walking-skeleton scene.
##
## The ground is painted here in code rather than stored in the scene file.
## That is deliberate and permanent: architecture rule 1 says the TileMapLayer
## is a *view*. In Stage 2 this placeholder generator is replaced by FarmData
## driving the same `set_cell` calls, and nothing else about the scene changes.
##
## Scene structure matters for depth:
##
##   Farm
##   ├── Ground     (TileMapLayer, z_index -1, NOT y-sorted — always underfoot)
##   └── Entities   (y-sorted — player and props sort against each other by
##                   their node origin, which for both sits at their base)
##

const TILE_PX := 16
const SOURCE_ID := 0

# Atlas coordinates into assets/tilesets/ground_placeholder.png
const TILE_GRASS := Vector2i(0, 0)
const TILE_GRASS_ALT := Vector2i(1, 0)
const TILE_PATH := Vector2i(2, 0)
const TILE_WATER := Vector2i(5, 0)
const TILE_CLIFF := Vector2i(7, 0)

const FARM_SIZE := Vector2i(30, 20)
const POND := Rect2i(21, 3, 5, 4)
const PATH_ROW := 12

## Fixed so the placeholder farm looks the same every run — a moving layout
## makes it impossible to tell a code change from a seed change.
const LAYOUT_SEED := 20261114
const GRASS_VARIATION := 0.18

const TREE_CELLS: Array[Vector2i] = [
	Vector2i(4, 4), Vector2i(7, 3), Vector2i(5, 8),
	Vector2i(19, 6), Vector2i(23, 10), Vector2i(26, 14),
	Vector2i(10, 16), Vector2i(16, 15), Vector2i(12, 11),
]

const TREE_SCENE := preload("res://scenes/tree.tscn")

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities


func _ready() -> void:
	_paint_ground()
	_place_trees()

	print("--- Pixel Harvest · Stage 1 ---")
	print("Farm %dx%d tiles, %d trees" % [FARM_SIZE.x, FARM_SIZE.y, TREE_CELLS.size()])
	print("WASD or arrows to move. Walk behind a tree to check Y-sorting,")
	print("and into the pond or the rock border to check collision.")
	print("-------------------------------")


## Where a cell's centre sits in pixels.
func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, cell.y * TILE_PX + TILE_PX / 2.0)


## Where a cell's bottom edge sits — the anchor for anything standing on it.
func cell_base(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, float((cell.y + 1) * TILE_PX))


func _paint_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED

	# One cell of border beyond the farm, so the player meets a wall rather
	# than the edge of the world.
	for y in range(-1, FARM_SIZE.y + 1):
		for x in range(-1, FARM_SIZE.x + 1):
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, SOURCE_ID, _tile_for(cell, rng))


func _tile_for(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var outside := (
		cell.x < 0 or cell.y < 0
		or cell.x >= FARM_SIZE.x or cell.y >= FARM_SIZE.y
	)
	if outside:
		return TILE_CLIFF
	if POND.has_point(cell):
		return TILE_WATER
	if cell.y == PATH_ROW and cell.x < 14:
		return TILE_PATH
	if rng.randf() < GRASS_VARIATION:
		return TILE_GRASS_ALT
	return TILE_GRASS


func _place_trees() -> void:
	for cell in TREE_CELLS:
		var tree := TREE_SCENE.instantiate()
		tree.position = cell_base(cell)
		_entities.add_child(tree)
