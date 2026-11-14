class_name FarmData
extends RefCounted
##
## FarmData — the single source of truth for every tile on the farm (rule 1).
##
## The TileMapLayer you see is a *picture* of this. Nothing in the game ever
## asks the tilemap "is this tile tilled?" — it asks FarmData. That's what will
## let Stage 3 save the farm without touching any node, and Stage 6 repaint
## the whole farm for a new season without losing a single crop.
##
## Every change goes through a method here, and every method announces what it
## did on EventBus. The farm scene listens and redraws just the cell that
## changed. FarmData doesn't know or care that anything is drawing it.
##
## It's a RefCounted, not a Node, so it can live in GameState and survive
## scene changes (going to town in Stage 7 doesn't throw the farm away).
##

## Size of the playable area in cells. The border of cliffs sits outside it.
var size: Vector2i

## Vector2i -> FarmTile. Includes the cliff border.
var _tiles: Dictionary = {}


func _init(farm_size: Vector2i) -> void:
	size = farm_size


## Every cell this farm knows about, border included.
func cells() -> Array:
	return _tiles.keys()


func has_cell(cell: Vector2i) -> bool:
	return _tiles.has(cell)


## The tile at `cell`, or null if it's off the farm entirely.
func tile(cell: Vector2i) -> FarmTile:
	return _tiles.get(cell)


## Used only while building a farm (FarmLayout, and in Stage 3, loading a save).
func set_tile(cell: Vector2i, farm_tile: FarmTile) -> void:
	_tiles[cell] = farm_tile


# --- Queries -----------------------------------------------------------------
# These answer "would this work?" without changing anything. Tools call them
# before charging energy.

func can_till(cell: Vector2i) -> bool:
	var t := tile(cell)
	return (
		t != null
		and t.terrain == FarmTile.Terrain.GRASS
		and t.object_id == &""
		and not t.tilled
	)


func can_water(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.watered


# --- Changes -----------------------------------------------------------------
# Each one checks its own precondition, so a caller that forgets to ask first
# can't corrupt the farm — it just gets a no-op.

func till(cell: Vector2i) -> void:
	if not can_till(cell):
		return
	tile(cell).tilled = true
	EventBus.tile_tilled.emit(cell)


func water(cell: Vector2i) -> void:
	if not can_water(cell):
		return
	tile(cell).watered = true
	EventBus.tile_watered.emit(cell)
