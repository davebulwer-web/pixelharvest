class_name FarmTile
extends RefCounted
##
## FarmTile — the authoritative state of one cell of the farm.
##
## This is plain data: no nodes, no textures, nothing about how it looks.
## Drawing reads these fields and turns them into tiles — not this file's job.
## Saving is: to_save() and from_save() below turn a tile into plain values a
## save file can hold, and back again.
##

## What the ground fundamentally is. Fixed for the life of the farm, except
## that THICKET (a field not yet bought) becomes GRASS when it's bought.
## BUILDING is ground a building stands on (the farmhouse, Stage 7): drawn as
## grass, in case the picture has gaps at its edges, but never tilled or built on.
## New values go on the end; saves store the name, never the number.
enum Terrain { GRASS, PATH, WATER, CLIFF, THICKET, BUILDING }

var terrain: Terrain = Terrain.GRASS

## Something standing on the cell that blocks tools, e.g. &"tree" or
## &"sprinkler". What the id means is an ObjectDef in data/objects/.
## Empty StringName means nothing is there.
var object_id: StringName = &""

var tilled: bool = false
var watered: bool = false

## The crop growing here, or null. Held as the definition itself; the save
## file holds `crop.id`, and loading looks it up again in ContentDB.
var crop: CropDef = null

## 0 is the planted seed; crop.growth_stages is ready to harvest.
var crop_stage: int = 0

## Watered days spent in the current stage so far.
var crop_days: int = 0

## True once a regrowing crop has been harvested at least once.
var crop_regrowing: bool = false

## Nights in a row the crop here has gone without water (Stage 11, DECISIONS
## 045). Back to 0 on any night it was watered. After HazardRules'
## wilt_after_dry_nights it looks wilted; after die_after_dry_nights it dies
## (on difficulties where thirst kills). A ripe crop is never thirsty: it has
## finished growing and only waits to be picked.
var dry_nights: int = 0

## Weeds have come up here (DECISIONS 045). On a crop's tile they stop it
## growing; on bare soil or grass they stop it being tilled, planted or built
## on. Pulled with E, or cleared with the hoe.
var weeds: bool = false


func has_crop() -> bool:
	return crop != null


func is_crop_ready() -> bool:
	return crop != null and crop.is_ready_stage(crop_stage)


## True if the crop here is showing its thirst: `wilt_after` dry nights or
## more, and not watered yet today. Watering it perks it up at once (the dry
## count itself only resets overnight, when the water has done its work).
func is_wilted(wilt_after: int) -> bool:
	return has_crop() and crop.needs_water and not is_crop_ready() and not watered \
			and wilt_after > 0 and dry_nights >= wilt_after


func clear_crop() -> void:
	crop = null
	crop_stage = 0
	crop_days = 0
	crop_regrowing = false
	dry_nights = 0


# --- Saving ------------------------------------------------------------------
# Only fields that differ from a fresh tile are written. A farm is mostly plain
# grass, so most tiles are saved as nothing more than their position.
#
# Terrain is written by NAME ("WATER"), not by its number in the enum. If the
# enum is ever reordered or grows, numbers in old saves would silently mean a
# different terrain; names can't. (Save version 1 made exactly that mistake —
# see the migration in save_system.gd.)

func to_save() -> Dictionary:
	var data := {}
	if terrain != Terrain.GRASS:
		data["terrain"] = Terrain.find_key(terrain)
	if object_id != &"":
		data["object"] = String(object_id)
	if tilled:
		data["tilled"] = true
	if watered:
		data["watered"] = true
	if crop != null:
		data["crop"] = String(crop.id)
		data["crop_stage"] = crop_stage
		data["crop_days"] = crop_days
		if crop_regrowing:
			data["crop_regrowing"] = true
		if dry_nights > 0:
			data["dry_nights"] = dry_nights
	if weeds:
		data["weeds"] = true
	return data


## Rebuild a tile from what to_save() wrote. Missing fields mean "as a fresh
## tile". A crop whose id the game no longer knows is dropped with a warning
## rather than stopping the load — one lost parsnip beats a lost farm.
static func from_save(data: Dictionary) -> FarmTile:
	var t := FarmTile.new()
	var terrain_name: String = data.get("terrain", "GRASS")
	if Terrain.has(terrain_name):
		t.terrain = Terrain[terrain_name]
	else:
		push_warning("Save has unknown terrain '%s'; treating it as grass" % terrain_name)
	t.object_id = StringName(data.get("object", ""))
	t.tilled = data.get("tilled", false)
	t.watered = data.get("watered", false)
	if data.has("crop"):
		var crop_def := ContentDB.crop(StringName(data["crop"]))
		if crop_def == null:
			push_warning("Save has a crop '%s' the game doesn't know; it's been removed" % data["crop"])
		else:
			t.crop = crop_def
			# JSON stores every number as a float, so turn counts back into ints.
			t.crop_stage = int(data.get("crop_stage", 0))
			t.crop_days = int(data.get("crop_days", 0))
			t.crop_regrowing = data.get("crop_regrowing", false)
			t.dry_nights = int(data.get("dry_nights", 0))
	t.weeds = data.get("weeds", false)
	return t
