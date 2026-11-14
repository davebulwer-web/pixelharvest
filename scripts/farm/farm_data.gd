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


func can_plant(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.has_crop()


func can_harvest(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.is_crop_ready()


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


func plant(cell: Vector2i, crop: CropDef) -> void:
	if not can_plant(cell):
		return
	var t := tile(cell)
	t.crop = crop
	t.crop_stage = 0
	t.crop_days = 0
	t.crop_regrowing = false
	EventBus.crop_planted.emit(cell, crop.id)


## Pick a ready crop. Single-harvest crops leave the soil tilled but empty;
## regrowing ones drop back a stage and start again. Returns how many items
## were picked (0 if nothing was ready).
func harvest(cell: Vector2i) -> int:
	if not can_harvest(cell):
		return 0
	var t := tile(cell)
	var crop := t.crop
	var amount := crop.harvest_amount
	if crop.regrow_days > 0:
		t.crop_stage = crop.growth_stages - 1
		t.crop_days = 0
		t.crop_regrowing = true
	else:
		t.clear_crop()
	EventBus.crop_harvested.emit(cell, crop.id, amount)
	return amount


# --- Overnight ---------------------------------------------------------------

## Everything that happens to the farm while the player sleeps: each watered
## crop gets one day of growth, then all the soil dries out.
##
## Called by TimeSystem once per day. It deliberately knows nothing about
## *when* days end — only what a day's passing does to the farm.
func advance_day() -> void:
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop() and t.watered and not t.is_crop_ready():
			_grow(cell, t)
		t.watered = false


func _grow(cell: Vector2i, t: FarmTile) -> void:
	t.crop_days += 1
	if t.crop_days < t.crop.days_to_grow_from(t.crop_stage, t.crop_regrowing):
		return
	t.crop_stage += 1
	t.crop_days = 0
	EventBus.crop_grew.emit(cell, t.crop_stage)
