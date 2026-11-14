class_name FarmData
extends RefCounted
##
## FarmData — the single source of truth for every tile on the farm (rule 1).
##
## The TileMapLayer you see is a *picture* of this. Nothing in the game ever
## asks the tilemap "is this tile tilled?" — it asks FarmData. That's what lets
## the save system save the farm without touching any node, and Stage 6 repaint
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


## Used only while building a farm (FarmLayout, and from_save below).
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


## Room to put an object down: open grass (tilled or not) with nothing on it.
func can_place(cell: Vector2i) -> bool:
	var t := tile(cell)
	return (
		t != null
		and t.terrain == FarmTile.Terrain.GRASS
		and t.object_id == &""
		and not t.has_crop()
	)


## True if any cell in `area` has this terrain.
func has_terrain_in(area: Rect2i, terrain: FarmTile.Terrain) -> bool:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := tile(Vector2i(x, y))
			if t != null and t.terrain == terrain:
				return true
	return false


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


## Put an object (a sprinkler) on the tile. Any tilling there is undone:
## the object stands on the ground, not in a seed bed.
func place_object(cell: Vector2i, object_id: StringName) -> void:
	if not can_place(cell):
		return
	var t := tile(cell)
	t.object_id = object_id
	t.tilled = false
	t.watered = false
	EventBus.object_placed.emit(cell, object_id)


func remove_object(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or t.object_id == &"":
		return
	var object_id := t.object_id
	t.object_id = &""
	EventBus.object_removed.emit(cell, object_id)


## A field has been bought: its thicket becomes grass. Water, trees and
## anything else in the area are left as they are. Returns how many cells
## were cleared. Announcing it is the caller's job (PlotEffect), because it
## knows which field this was.
func clear_thicket(area: Rect2i) -> int:
	var cleared := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := tile(Vector2i(x, y))
			if t != null and t.terrain == FarmTile.Terrain.THICKET:
				t.terrain = FarmTile.Terrain.GRASS
				cleared += 1
	return cleared


# --- Overnight ---------------------------------------------------------------

## Everything that happens to the farm while the player sleeps: each watered
## crop gets one day of growth, then all the soil dries out, then sprinklers
## water the ground around them — so the player wakes to wet soil around every
## sprinkler, and those crops grow the following night without being touched.
##
## Called by TimeSystem once per day. It deliberately knows nothing about
## *when* days end — only what a day's passing does to the farm.
func advance_day() -> void:
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop() and t.watered and not t.is_crop_ready():
			_grow(cell, t)
		t.watered = false
	_run_sprinklers()


## Any object with water_offsets waters those tiles. water() only wets tilled
## soil, so a sprinkler next to grass or a path simply does nothing there.
func _run_sprinklers() -> void:
	for cell: Vector2i in _tiles:
		var object_id: StringName = _tiles[cell].object_id
		if object_id == &"":
			continue
		var object_def := ContentDB.object(object_id)
		if object_def == null:
			continue
		for offset in object_def.water_offsets:
			water(cell + offset)


func _grow(cell: Vector2i, t: FarmTile) -> void:
	t.crop_days += 1
	if t.crop_days < t.crop.days_to_grow_from(t.crop_stage, t.crop_regrowing):
		return
	t.crop_stage += 1
	t.crop_days = 0
	EventBus.crop_grew.emit(cell, t.crop_stage)


# --- Saving ------------------------------------------------------------------
# The whole farm is saved, terrain and trees included, not just the changes the
# player made. The save is then the complete truth about this farm: if the
# starting layout is redesigned later, existing farms keep the map they were
# played on instead of having their crops land in a new pond.

func to_save() -> Dictionary:
	var tiles: Array = []
	for cell: Vector2i in _tiles:
		var entry := {"x": cell.x, "y": cell.y}
		entry.merge((_tiles[cell] as FarmTile).to_save())
		tiles.append(entry)
	return {"width": size.x, "height": size.y, "tiles": tiles}


static func from_save(data: Dictionary) -> FarmData:
	var farm := FarmData.new(Vector2i(int(data["width"]), int(data["height"])))
	for entry: Dictionary in data["tiles"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		farm.set_tile(cell, FarmTile.from_save(entry))
	return farm
