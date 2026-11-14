class_name CropDef
extends Resource
##
## CropDef — everything that distinguishes one crop from another: how it grows,
## what it looks like, and what harvesting it gives you.
##
## A crop is three small files (DECISIONS 023): this, the produce it yields
## (an ItemDef in data/produce/) and the seeds that plant it (a ToolDef in
## data/tools/). ContentDB checks at startup that the three agree.
##
## Kept deliberately small. Fields get added when a stage needs them, not before.
##

@export var id: StringName
@export var display_name: String

## How many growth stages after the seed. The crop is ready to harvest when
## it reaches the last one.
@export var growth_stages: int = 4

## Watered days needed to move from one stage to the next. A day without
## water is simply a day of no growth — nothing dies of thirst yet.
@export var days_per_stage: int = 1

## 0 means harvest once and the tile clears. Above 0, the crop drops back one
## stage when harvested and is ready again after this many watered days
## (DECISIONS 006).
@export var regrow_days: int = 0

## What one harvest puts in the bag, and how many of it. Its price is on the
## produce item, so the shop, the bin and (Stage 8) the market all read the
## same number.
@export var produce: ItemDef
@export var harvest_amount: int = 1

## One row of equal-width frames: frame 0 is the planted seed, then one frame
## per growth stage, the last being "ready to harvest". So the sheet must have
## growth_stages + 1 frames. Each frame's bottom edge sits on the tile's
## bottom edge, so tall crops simply use taller frames.
@export var sprite_sheet: Texture2D

## The seasons this crop grows in, by SeasonTheme id (&"spring"). It can only
## be planted in one of them, and if the season turns to one it isn't in, it
## dies that night (DECISIONS 025). Leave it empty for a crop that grows all
## year round.
@export var seasons: Array[StringName] = []


## True if this crop can be planted, and keeps growing, in the season `season_id`.
func grows_in(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons


## True if `stage` is the final, harvestable one.
func is_ready_stage(stage: int) -> bool:
	return stage >= growth_stages


## Watered days needed to leave `stage`. A regrowing crop that has already been
## harvested waits regrow_days for its last step instead of days_per_stage.
func days_to_grow_from(stage: int, regrowing: bool) -> int:
	if regrowing and stage == growth_stages - 1:
		return regrow_days
	return days_per_stage


## Total watered days from planting to the first harvest. Handy for the shop
## and for balancing; nothing in the growing code uses it.
func days_to_mature() -> int:
	return growth_stages * days_per_stage
