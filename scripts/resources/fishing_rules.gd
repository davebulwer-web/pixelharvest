class_name FishingRules
extends Resource
##
## FishingRules — the numbers behind fishing (DECISIONS 054): how long a
## float sits before something bites, how long you have to strike, and how
## the reel bar behaves for each step of a fish's fight.
##
## One file, data/fishing_rules.tres, which game_rules.tres points at, so
## tuning fishing never means touching code (rule 6). How much sooner the
## rod's better tier gets a bite is here too (`rod_tier_wait_multipliers`);
## what differs between fish is on each FishDef.
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

## Seasons when all the water is frozen (winter's tiles draw every pond,
## river and stream as ice). Then the rod's first Space on the ice cuts a
## hole, and the next casts through it (DECISIONS 055). The ice closes
## over every hole in the night.
@export var frozen_seasons: Array[StringName] = [&"winter"]

## Fishing through the ice is slow: the wait is this many times as long.
## (Wren's "ice and patience".)
@export var ice_wait_multiplier: float = 1.5

## Lures (DECISIONS 055): kept in the bag, never used up. Any of these that
## works in today's season shortens the wait by its own multiplier, and
## the bait stays in its tin.
@export var lures: Array[LureDef] = []

## The rod's id, and how much sooner it gets a bite at each tier the
## player owns: tier 1 (the fine rod, from Wren) first. Tier 0 waits the
## plain time. (The tier itself is a ToolTier on the rod's .tres, given by
## the fine_rod upgrade, as the wide hoe is.)
@export var rod_tool: StringName = &"fishing_rod"
@export var rod_tier_wait_multipliers: Array[float] = [0.6]


## Value number `fight` (1 to 5) of `values`, or its last if it's short.
static func for_fight(values: Array, fight: int) -> Variant:
	if values.is_empty():
		return null
	return values[clampi(fight, 1, values.size()) - 1]


## How much sooner the rod gets a bite at `tier`: 1.0 at tier 0.
func rod_wait_multiplier(tier: int) -> float:
	if tier <= 0 or rod_tier_wait_multipliers.is_empty():
		return 1.0
	return rod_tier_wait_multipliers[mini(tier, rod_tier_wait_multipliers.size()) - 1]
