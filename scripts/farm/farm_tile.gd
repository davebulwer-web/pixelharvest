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

## Planting fills these in (next session).
var crop_id: StringName = &""
var crop_stage: int = 0
