class_name FarmTile
extends RefCounted
##
## FarmTile — the authoritative state of one cell of the farm.
##
## This is plain data: no nodes, no textures, nothing about how it looks.
## Saving (Stage 3) will write these fields out and read them back; drawing
## reads them and turns them into tiles. Neither of those is this file's job.
##

## What the ground fundamentally is. Fixed for the life of the farm.
enum Terrain { GRASS, PATH, WATER, CLIFF }

var terrain: Terrain = Terrain.GRASS

## Something standing on the cell that blocks tools, e.g. &"tree".
## Empty StringName means nothing is there.
var object_id: StringName = &""

var tilled: bool = false
var watered: bool = false

## The crop growing here, or null. Held as the definition itself rather than
## its id for now; Stage 3 saves `crop.id` and looks it up again on load.
var crop: CropDef = null

## 0 is the planted seed; crop.growth_stages is ready to harvest.
var crop_stage: int = 0

## Watered days spent in the current stage so far.
var crop_days: int = 0

## True once a regrowing crop has been harvested at least once.
var crop_regrowing: bool = false


func has_crop() -> bool:
	return crop != null


func is_crop_ready() -> bool:
	return crop != null and crop.is_ready_stage(crop_stage)


func clear_crop() -> void:
	crop = null
	crop_stage = 0
	crop_days = 0
	crop_regrowing = false
