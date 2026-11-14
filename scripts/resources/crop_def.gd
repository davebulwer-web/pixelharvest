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

## How many visible growth stages before it's ready, not counting the seed.
@export var growth_stages: int = 4

## Days (i.e. sleeps, while watered) spent in each growth stage.
@export var days_per_stage: int = 1

## 0 means harvest once and the tile clears. Above 0, the crop stays and is
## ready again this many days after each harvest (DECISIONS 006).
@export var regrow_days: int = 0

## Gold per item when sold through the shipping bin (Stage 4).
@export var sell_price: int = 0
