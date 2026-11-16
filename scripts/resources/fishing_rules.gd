class_name FishingRules
extends Resource
##
## FishingRules — the numbers behind fishing (DECISIONS 054): how long a
## float sits before something bites, how long you have to strike, and how
## the reel bar behaves for each step of a fish's fight.
##
## One file, data/fishing_rules.tres, which game_rules.tres points at, so
## tuning fishing never means touching code (rule 6). What differs between
## rods (a better rod gets a bite sooner) is on the rod's own .tres
## (FishAction); what differs between fish is on each FishDef.
##
## How a cast goes (scripts/autoload/fishing.gd):
##   1. Space with the rod, facing water: the float lands and you wait.
##   2. Something bites: the float bobs under and a "!" shows. Space within
##      `strike_seconds` hooks it; too slow and it's gone.
##   3. The reel bar: a marker swings from end to end. Space while it's over
##      the green zone is a good pull; anywhere else, the line goes slack.
##      Enough good pulls and the fish is landed; too many slack ones and it
##      gets away. E reels in and gives up at any point.
## It's about timing, not speed: the marker swings at a steady pace, and
## the zone is wide for small fish.
##
## Must not use the GameState autoload: game_rules.tres preloads this file,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

## Seconds the float sits before a bite: somewhere between these two.
@export var wait_min_seconds: float = 2.5
@export var wait_max_seconds: float = 7.0

## Bait on the hook (any of these items in the bag, the first one found is
## used up by the cast) multiplies the wait: 0.5 is a bite twice as soon.
@export var bait: Array[ItemDef] = []
@export var bait_wait_multiplier: float = 0.5

## Seconds to strike once the float bobs under. Generous on purpose.
@export var strike_seconds: float = 1.2

## For each step of a fish's fight (FishDef.fight, 1 to 5), in order:
## seconds for the marker to cross the bar once,
@export var sweep_seconds: Array[float] = [1.6, 1.4, 1.2, 1.0, 0.85]
## how much of the bar the green zone covers (0.4 is two fifths),
@export var zone_widths: Array[float] = [0.4, 0.34, 0.28, 0.23, 0.19]
## and how many good pulls land it.
@export var pulls_needed: Array[int] = [1, 2, 2, 3, 3]

## Slack pulls it takes before the fish gets away (the next one loses it).
@export var slack_allowed: int = 2

## Seconds a hooked fish waits for a pull before it slips the hook.
@export var reel_patience_seconds: float = 8.0

## Seasons when all the water is frozen and nothing can be cast into it
## (winter's tiles draw every pond, river and stream as ice). The ice hole
## comes in Stage 15 session 2.
@export var frozen_seasons: Array[StringName] = [&"winter"]


## Value number `fight` (1 to 5) of `values`, or its last if it's short.
static func for_fight(values: Array, fight: int) -> Variant:
	if values.is_empty():
		return null
	return values[clampi(fight, 1, values.size()) - 1]
