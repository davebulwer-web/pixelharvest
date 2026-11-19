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

## Their face in the dialogue box (Stage 24, DECISIONS 074): a strip of
## square busts, one per mood (neutral, happy, worried), from
## assets/sprites/portraits/. Null: the box shows no portrait.
@export var portrait: Texture2D

## How they walk (Stage 24, DECISIONS 074): animations named like the
## farmer's, idle_<facing> and walk_<facing>, for four facings (down, up,
## left, right) or eight (adding down_left, down_right, up_left, up_right).
## Whatever facings are missing fall back to the nearest of the four. Null:
## the still `sprite`, bobbing as it walks (until their walk cycle is drawn).
@export var walk_frames: SpriteFrames

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

## Someone who buys (or sells) where they stand, outdoors, with no shop to
## walk into (DECISIONS 065): Tam on the quay buys fish and anything from the
## sea. Talking to them is a shop counter's conversation (ShopCounter), with
## their requests first, as a shopkeeper's are, then the counter's menu. The
## counter's greetings are what they say; with none, their `lines`. Its id
## must differ from every character's and shop's. Null: they only talk.
@export var counter: ShopDef

## Where they are through the day, by the clock (DECISIONS 067): a home and
## a plan for each kind of day (ScheduleDef), so they walk between places and
## a request is handed in wherever they are now. Null: they stand on today's
## `spots` in `location` all day, as before Stage 22. `location` still says
## where they belong (a festival's host is checked against it).
@export var schedule: ScheduleDef


## Where they stand on `day` (someone without a schedule).
func spot_on(day: int) -> Vector2i:
	if spots.is_empty():
		return Vector2i.ZERO
	return spots[posmod(day - 1, spots.size())]


## What they say on `day`.
func line_on(day: int) -> String:
	if lines.is_empty():
		return ""
	return lines[posmod(day - 1, lines.size())]
