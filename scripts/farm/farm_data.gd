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

## Where crows took a crop last night (DECISIONS 045), so the farm can show
## a crow standing there in the morning until the player scares it off. Only
## for the picture: it isn't saved (a reloaded morning has no crows to see),
## and it's emptied at the start of every night.
var crows_landed: Array[Vector2i] = []


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
		and not t.weeds
	)


func can_water(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.watered


func can_plant(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.has_crop() and not t.weeds


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
		and not t.weeds
	)


func has_weeds(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.weeds


## True if a crop grows on any of the four tiles beside `cell`. Weeds come up
## in the grass next to crops as well as in the soil (DECISIONS 045).
func is_next_to_crop(cell: Vector2i) -> bool:
	for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var t := tile(cell + step)
		if t != null and t.has_crop():
			return true
	return false


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


## Weeds come up on `cell` (overnight, FarmHazards). Only on open ground:
## grass or soil with nothing standing on it.
func sprout_weeds(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or t.weeds or t.object_id != &"" or t.terrain != FarmTile.Terrain.GRASS:
		return
	t.weeds = true
	EventBus.weeds_sprouted.emit(cell)


## Weeds pulled up (E) or hoed out. Returns false if there were none. What
## the player gets for it (fibre) is GameState's business, on weeds_pulled.
func pull_weeds(cell: Vector2i) -> bool:
	if not has_weeds(cell):
		return false
	tile(cell).weeds = false
	EventBus.weeds_pulled.emit(cell)
	return true


## Bare tilled soil goes back to grass (overnight, FarmHazards): a seed bed
## left empty doesn't stay a seed bed for ever.
func untill(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or not t.tilled or t.has_crop():
		return
	t.tilled = false
	t.watered = false
	EventBus.tile_cleared.emit(cell)


## A crow took the crop on `cell` in the night: it's gone, the soil stays.
func lose_to_crows(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or not t.has_crop():
		return
	var crop_id := t.crop.id
	t.clear_crop()
	crows_landed.append(cell)
	EventBus.crop_died.emit(cell, crop_id, &"crows")


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

## The first part of the night on the farm: each watered crop gets one day
## of growth (unless weeds are choking it), each unwatered one gets a night
## thirstier, and then all the soil dries out.
##
## TimeSystem then runs the night's hazards (crows, weeds: FarmHazards) and
## last of all run_sprinklers(), so the player wakes to wet soil around every
## sprinkler and those crops grow the following night without being touched.
##
## Called by TimeSystem once per day. It deliberately knows nothing about
## *when* days end — only what a day's passing does to the farm. The settings
## are passed in so the farm's data never has to look up the game's:
##   `grow_scale` is the difficulty's grow_time_multiplier (DECISIONS 040);
##   `die_after_dry_nights` is how many nights in a row without water kill a
##   crop (DECISIONS 045), or 0 if thirst never kills (Relaxed);
##   `thirst_step` is how many nights' thirst an unwatered crop gains: 1, or
##   2 after a heatwave (DECISIONS 046).
func advance_day(grow_scale: float = 1.0, die_after_dry_nights: int = 0, thirst_step: int = 1) -> void:
	crows_landed.clear()
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop():
			if t.is_crop_ready():
				t.dry_nights = 0
			elif t.watered:
				t.dry_nights = 0
				if not t.weeds:
					_grow(cell, t, grow_scale)
			else:
				t.dry_nights += maxi(1, thirst_step)
				if die_after_dry_nights > 0 and t.dry_nights >= die_after_dry_nights:
					var crop_id := t.crop.id
					t.clear_crop()
					EventBus.crop_died.emit(cell, crop_id, &"thirst")
		t.watered = false


## Any object with water_offsets waters those tiles. water() only wets tilled
## soil, so a sprinkler next to grass or a path simply does nothing there.
## The last thing every night (TimeSystem).
func run_sprinklers() -> void:
	for cell: Vector2i in _tiles:
		var object_id: StringName = _tiles[cell].object_id
		if object_id == &"":
			continue
		var object_def := ContentDB.object(object_id)
		if object_def == null:
			continue
		for offset in object_def.water_offsets:
			water(cell + offset)


## Rain (DECISIONS 046): every tile of tilled soil is watered, as if by the
## can. TimeSystem calls it in the night, once a rainy day has begun, so the
## morning's soil is wet and every crop grows tonight. Returns how many
## tiles it watered.
func rain() -> int:
	var watered := 0
	for cell: Vector2i in _tiles:
		if can_water(cell):
			water(cell)
			watered += 1
	return watered


## Frost (DECISIONS 046): every crop that can't grow in `next_season_id`
## dies, a night before the season's turn would kill it anyway. Returns how
## many died.
func frost(next_season_id: StringName) -> int:
	var died := 0
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop() and not t.crop.grows_in(next_season_id):
			var crop_id := t.crop.id
			t.clear_crop()
			died += 1
			EventBus.crop_died.emit(cell, crop_id, &"frost")
	return died


## The season has turned: every crop that can't grow in `season_id` dies and
## its tile is left as empty tilled soil. Called by TimeSystem, once, on the
## night a season changes. Returns how many died.
func wither_out_of_season(season_id: StringName) -> int:
	var died := 0
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop() and not t.crop.grows_in(season_id):
			var crop_id := t.crop.id
			t.clear_crop()
			died += 1
			EventBus.crop_died.emit(cell, crop_id, &"season")
	return died


func _grow(cell: Vector2i, t: FarmTile, grow_scale: float) -> void:
	t.crop_days += 1
	if t.crop_days < t.crop.days_to_grow_from(t.crop_stage, t.crop_regrowing, grow_scale):
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
