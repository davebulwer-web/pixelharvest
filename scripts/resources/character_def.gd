class_name CharacterDef
extends Resource
##
## CharacterDef — someone who lives in the world and can be talked to: the
## mayor, the angler by the pond, and (from Stage 8) the quest characters.
##
## Shopkeepers are not CharacterDefs: they stand behind a counter and come
## with their shop (ShopDef). Everyone else is one of these, so a new
## townsperson is a .tres in data/characters/ and a picture — the town builds
## an Npc for every character whose `location` is the town, and nothing in
## the town's code names anyone (DECISIONS 029).
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var id: StringName
@export var display_name: String

## A 56×56 frame standing on the same baseline as the farmer and the
## shopkeepers (Npc.SPRITE_OFFSET).
@export var sprite: Texture2D

## The location they're found in (&"town").
@export var location: StringName = &"town"

## Where they stand, by cell on that location's map. With more than one,
## they're at a different spot each day (day 1 the first, day 2 the next, and
## round again), so the town changes a little from morning to morning.
@export var spots: Array[Vector2i] = []

## What they say when spoken to: one line a day, the same all day, a new one
## tomorrow — the same rule as the shopkeepers' greetings.
@export var lines: Array[String] = []

## Not in the world until this is earned (DECISIONS 044): Mabel arrives on
## spring day 5. Until then they aren't built, and have nothing to ask. Null:
## here from the start.
@export var requires_unlock: UnlockDef


## Where they stand on `day`.
func spot_on(day: int) -> Vector2i:
	if spots.is_empty():
		return Vector2i.ZERO
	return spots[posmod(day - 1, spots.size())]


## What they say on `day`.
func line_on(day: int) -> String:
	if lines.is_empty():
		return ""
	return lines[posmod(day - 1, lines.size())]
