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
		and not t.covered
	)


func can_water(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.watered


func can_plant(cell: Vector2i) -> bool:
	var t := tile(cell)
	return t != null and t.tilled and not t.has_crop() and not t.weeds and not t.covered


## can_plant(), and whatever `crop`'s own rules ask of the spot: a
## water-loving crop (watercress) needs water beside it (DECISIONS 047), and
## a tree (CropDef.size, DECISIONS 048) needs every tile of its patch free.
func can_plant_crop(cell: Vector2i, crop: CropDef) -> bool:
	if crop == null:
		return false
	var area := footprint_at(cell, crop.size)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not can_plant(Vector2i(x, y)):
				return false
	return not crop.near_water or is_next_to_water(cell)


## The cell that holds the crop showing at `cell`: `cell` itself, or the
## corner of the giant or tree covering it (DECISIONS 048).
func crop_cell(cell: Vector2i) -> Vector2i:
	var t := tile(cell)
	return t.covered_by if t != null and t.covered else cell


## The tiles a crop `span` tiles square stands on, when its corner (the
## tile holding it) is `cell`: the corner is front-left, and the patch runs
## right and back (up the screen) from there.
static func footprint_at(cell: Vector2i, span: int) -> Rect2i:
	return Rect2i(Vector2i(cell.x, cell.y - span + 1), Vector2i(span, span))


## The tiles the crop held at `cell` stands on (just `cell` for most crops).
func footprint(cell: Vector2i) -> Rect2i:
	var t := tile(cell)
	return footprint_at(cell, t.span() if t != null else 1)


func can_harvest(cell: Vector2i) -> bool:
	var t := tile(crop_cell(cell))
	return t != null and t.is_crop_ready()


## True if there's a crop at `cell` (or covering it) that the trowel can dig
## up: anything but a giant, which is picked, not dug.
func can_dig(cell: Vector2i) -> bool:
	var t := tile(crop_cell(cell))
	return t != null and t.has_crop() and not t.giant


func has_pests(cell: Vector2i) -> bool:
	var t := tile(crop_cell(cell))
	return t != null and t.pests


## Room to put an object down: open grass (tilled or not) with nothing on it.
func can_place(cell: Vector2i) -> bool:
	var t := tile(cell)
	return (
		t != null
		and t.terrain == FarmTile.Terrain.GRASS
		and t.object_id == &""
		and not t.has_crop()
		and not t.weeds
		and not t.covered
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


## True if any of the eight tiles around `cell` is water (the pond).
func is_next_to_water(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile(cell + Vector2i(dx, dy))
			if t != null and t.terrain == FarmTile.Terrain.WATER:
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
	if crop.size > 1 and not can_plant_crop(cell, crop):
		return
	var t := tile(cell)
	t.crop = crop
	t.crop_stage = 0
	t.crop_days = 0
	t.crop_regrowing = false
	_cover(cell)
	EventBus.crop_planted.emit(cell, crop.id)


## Pick a ready crop. Single-harvest crops leave the soil tilled but empty;
## regrowing ones drop back a stage and start again. Returns how many items
## were picked (0 if nothing was ready). `dice` rolls a crop that comes in
## bunches (CropDef.harvest_max); without dice it gives the least.
## Any tile of a giant or a tree picks the whole thing; a giant gives its
## CropDef.giant_harvest and leaves nine tiles of empty soil.
func harvest(cell: Vector2i, dice: RandomNumberGenerator = null) -> int:
	if not can_harvest(cell):
		return 0
	cell = crop_cell(cell)
	var t := tile(cell)
	var crop := t.crop
	if t.giant:
		var giant_amount := maxi(1, crop.giant_harvest)
		_remove_crop(cell)
		EventBus.giant_harvested.emit(cell, crop.id)
		EventBus.crop_harvested.emit(cell, crop.id, giant_amount)
		return giant_amount
	var amount := crop.roll_harvest(dice)
	if crop.regrow_days > 0:
		t.crop_stage = crop.growth_stages - 1
		t.crop_days = 0
		t.crop_regrowing = true
	else:
		_remove_crop(cell)
	EventBus.crop_harvested.emit(cell, crop.id, amount)
	return amount


## The trowel: dig up whatever crop is at `cell` (or the tree covering it),
## ripe or not, and leave the soil empty (DECISIONS 048). How players clear
## a crop they don't want any more: one with aphids, a perennial, a tree in
## the wrong place. A crop dug up as a seed (stage 0, never harvested) is
## announced as such, so GameState can give the seed back. Returns false if
## there was nothing to dig.
func dig_up(cell: Vector2i) -> bool:
	if not can_dig(cell):
		return false
	cell = crop_cell(cell)
	var t := tile(cell)
	var crop_id := t.crop.id
	var was_seed := t.crop_stage == 0 and not t.crop_regrowing
	_remove_crop(cell)
	EventBus.crop_dug_up.emit(cell, crop_id, was_seed)
	return true


## Aphids land on the crop at `cell` (overnight, FarmHazards). Only on a
## crop that's still growing.
func infest(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or t.pests or not t.is_crop_growing():
		return
	t.pests = true
	EventBus.pests_spread.emit(cell)


## Aphids gone from the crop at `cell` (or the tree covering it): sprayed,
## or the season too cold for them. Returns false if there were none.
func clear_pests(cell: Vector2i) -> bool:
	cell = crop_cell(cell)
	if not has_pests(cell):
		return false
	tile(cell).pests = false
	EventBus.pests_cleared.emit(cell)
	return true


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
	if t == null or t.weeds or t.object_id != &"" or t.terrain != FarmTile.Terrain.GRASS \
			or t.covered or t.giant:
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
	_remove_crop(cell)
	crows_landed.append(cell)
	EventBus.crop_died.emit(cell, crop_id, &"crows")


## A storm flattened the tall crop on `cell` (DECISIONS 047): it's gone,
## the soil stays.
func flatten(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null or not t.has_crop():
		return
	var crop_id := t.crop.id
	_remove_crop(cell)
	EventBus.crop_died.emit(cell, crop_id, &"storm")


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
## of growth (unless weeds are choking it or aphids are on it: DECISIONS
## 048), each unwatered one gets a night
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
##   2 after a heatwave (DECISIONS 046);
##   `season_id` is the season the day belonged to: a crop resting in it
##   (garlic in winter, a perennial out of season) neither grows nor thirsts;
##   `weather_id` is the day's weather: a crop that loves it (CropDef.loves_weather)
##   grows twice tonight (DECISIONS 047).
## A hardy crop (needs_water off) grows as though it had been watered.
func advance_day(grow_scale: float = 1.0, die_after_dry_nights: int = 0, thirst_step: int = 1,
		season_id: StringName = &"", weather_id: StringName = &"") -> void:
	crows_landed.clear()
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop():
			if t.is_crop_ready() or (season_id != &"" and t.crop.rests_during(season_id)):
				t.dry_nights = 0
			elif t.watered or not t.crop.needs_water:
				t.dry_nights = 0
				if not t.weeds and not t.pests:
					_grow(cell, t, grow_scale)
					if weather_id != &"" and weather_id in t.crop.loves_weather and not t.is_crop_ready():
						_grow(cell, t, grow_scale)
			else:
				t.dry_nights += maxi(1, thirst_step)
				if die_after_dry_nights > 0 and t.dry_nights >= die_after_dry_nights:
					var crop_id := t.crop.id
					_remove_crop(cell)
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


## Frost (DECISIONS 046): every crop that can't live through `next_season_id`
## (grow in it, or rest through it: DECISIONS 047) dies, a night before the
## season's turn would kill it anyway. Returns how many died.
func frost(next_season_id: StringName) -> int:
	var died := 0
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if t.has_crop() and not t.crop.survives(next_season_id):
			var crop_id := t.crop.id
			_remove_crop(cell)
			died += 1
			EventBus.crop_died.emit(cell, crop_id, &"frost")
	return died


## The season has turned: every crop that can't live in `season_id` dies and
## its tile is left as empty tilled soil. Called by TimeSystem, once, on the
## night a season changes. Returns how many died.
##
## A crop that rests in the new season (DECISIONS 047) goes to sleep instead.
## If it's a regrowing one waiting ripe, that crop is lost: it sleeps as a
## plant waiting to regrow, so next year it starts with a regrow, not a
## harvest that sat out the winter.
func wither_out_of_season(season_id: StringName) -> int:
	var died := 0
	for cell: Vector2i in _tiles:
		var t: FarmTile = _tiles[cell]
		if not t.has_crop():
			continue
		if t.crop.rests_during(season_id):
			if t.crop.regrow_days > 0 and t.is_crop_ready():
				t.crop_stage = t.crop.growth_stages - 1
				t.crop_days = 0
				t.crop_regrowing = true
			continue
		if not t.crop.grows_in(season_id):
			var crop_id := t.crop.id
			_remove_crop(cell)
			died += 1
			EventBus.crop_died.emit(cell, crop_id, &"season")
	return died


## Giants (DECISIONS 048): each 3 × 3 block of one giant-capable crop
## (CropDef.can_go_giant), every tile ripe and clear of weeds and aphids, may
## merge tonight into one giant, with the crop's giant_chance. The block's
## front-left tile keeps the crop as a giant; the other eight are covered by
## it. TimeSystem calls this in the night, after the hazards. Returns the
## corners of the giants that grew (each also announced as giant_grew).
func form_giants(dice: RandomNumberGenerator) -> Array[Vector2i]:
	var grown: Array[Vector2i] = []
	if dice == null:
		return grown
	var corners: Array = _tiles.keys()
	corners.sort()  # a fixed order, so the same dice give the same night
	for corner: Vector2i in corners:
		var crop := _giant_block_crop(corner)
		if crop == null or dice.randf() >= crop.giant_chance:
			continue
		var area := footprint_at(corner, CropDef.GIANT_SIZE)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var other := Vector2i(x, y)
				if other != corner:
					tile(other).clear_crop()
		tile(corner).giant = true
		_cover(corner)
		grown.append(corner)
		EventBus.giant_grew.emit(corner, crop.id)
	return grown


## The crop of the 3 × 3 block whose front-left corner is `corner`, if every
## tile of it holds that same crop, ripe, ordinary-sized, and clear of weeds
## and aphids, and the crop can go giant. Null otherwise.
func _giant_block_crop(corner: Vector2i) -> CropDef:
	var first := tile(corner)
	if first == null or not first.has_crop() or not first.crop.can_go_giant():
		return null
	var area := footprint_at(corner, CropDef.GIANT_SIZE)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := tile(Vector2i(x, y))
			if t == null or t.crop != first.crop or t.giant or t.covered \
					or not t.is_crop_ready() or t.weeds or t.pests:
				return null
	return first.crop


## Take the crop off `cell`, whatever the reason, and free every tile it
## covered (a giant's eight, a tree's three). Every way a crop leaves the
## farm goes through here, so a giant can't leave covered tiles behind.
func _remove_crop(cell: Vector2i) -> void:
	var t := tile(cell)
	if t == null:
		return
	var area := footprint(cell)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var other := tile(Vector2i(x, y))
			if other != null and other.covered and other.covered_by == cell:
				other.covered = false
	t.clear_crop()


## Mark every other tile under the crop held at `cell` as covered by it.
## Only tiles with nothing growing of their own: on a farm loaded from an
## old or edited save, a crop already there keeps its tile.
func _cover(cell: Vector2i) -> void:
	var area := footprint(cell)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var other_cell := Vector2i(x, y)
			var other := tile(other_cell)
			if other_cell == cell or other == null or other.has_crop():
				continue
			other.covered = true
			other.covered_by = cell


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
	# Which tiles a giant or a tree covers isn't saved: it follows from the
	# corners that hold them (DECISIONS 048).
	for cell: Vector2i in farm.cells():
		if farm.tile(cell).span() > 1:
			farm._cover(cell)
	return farm
