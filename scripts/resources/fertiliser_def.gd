class_name FertiliserDef
extends ToolDef
##
## FertiliserDef — a bag of something that goes into tilled soil and stays
## there, making the soil better (DECISIONS 058): growth feed, mulch.
##
## It's a ToolDef, so it sits on the hotbar, is bought by the bag and used up
## a bag a tile (consumed_on_use), with a FertiliseAction doing the work. What
## the fed soil then *does* is the numbers below. A new kind of fertiliser is
## a new .tres with different numbers, no code (rule 3).
##
## The soil keeps it until the soil goes back to grass (bare soil left empty:
## FarmHazards) or something is put down on it. Harvesting doesn't use it up,
## so a bed fed once feeds every crop sown in it. One fertiliser to a tile.
##

## A crop sown in this soil starts this many stages ahead: it comes up at
## once, skipping the bare seed, and is ripe that much sooner. Never past the
## stage before ripe. Feeding soil that already holds a seed just sown moves
## that seed on at once. 0 for none.
@export_range(0, 3) var skips_stages: int = 0

## Watered soil stays wet this many nights longer before it dries: one can of
## water lasts two nights with 1. 0 for none.
@export_range(0, 3) var keeps_wet_nights: int = 0

## Laid over the soil to show it's been fed: a 16 × 16 picture, mostly
## see-through, drawn under the crops.
@export var soil_look: Texture2D
