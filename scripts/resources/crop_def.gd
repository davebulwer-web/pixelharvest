class_name CropDef
extends Resource
##
## CropDef — everything that distinguishes one crop from another.
##
## Introduced in Stage 2 rather than Stage 4 (DECISIONS 017): the plan said
## "one hardcoded crop", but hardcoding grow times would break rule 6. So the
## first crop is a resource from day one, and Stage 4's job shrinks to adding
## ContentDB and more .tres files.
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

## How many items one harvest gives.
@export var harvest_amount: int = 1

## Gold per item when sold through the shipping bin (Stage 4).
@export var sell_price: int = 0

## One row of equal-width frames: frame 0 is the planted seed, then one frame
## per growth stage, the last being "ready to harvest". So the sheet must have
## growth_stages + 1 frames. Each frame's bottom edge sits on the tile's
## bottom edge, so tall crops simply use taller frames.
@export var sprite_sheet: Texture2D


## True if `stage` is the final, harvestable one.
func is_ready_stage(stage: int) -> bool:
	return stage >= growth_stages


## Watered days needed to leave `stage`. A regrowing crop that has already been
## harvested waits regrow_days for its last step instead of days_per_stage.
func days_to_grow_from(stage: int, regrowing: bool) -> int:
	if regrowing and stage == growth_stages - 1:
		return regrow_days
	return days_per_stage
