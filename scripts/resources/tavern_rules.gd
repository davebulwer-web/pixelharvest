class_name TavernRules
extends Resource
##
## TavernRules — every number and every pattern of words behind Nell's
## tavern, the Wheatsheaf (DECISIONS 068): the chalkboard, the rumours and
## darts night. Kept in data/tavern_rules.tres, named by game_rules.tres.
##
## The tavern's opening hours, its food and how much it pays for what's on
## the chalkboard are its ShopDef's (data/shops/tavern.tres), like any shop.
##
## Nothing in this file may touch an autoload: game_rules.tres loads it
## before the autoloads exist (DECISIONS 021).
##

## --- The chalkboard ---------------------------------------------------------------
## What Nell might chalk up as wanted: each day she picks a few of these
## that are in season (a crop growing this season whose seeds can be had, a
## wild thing growing this season, a fish biting this season). The tavern's
## ShopDef says how much over the bin's price she pays for them.
@export var chalkboard_items: Array[ItemDef] = []

## How many things are wanted each day.
@export var chalkboard_count: int = 3

## How many of each she'll take in a day: small quantities, for her kitchen.
@export var chalkboard_each: int = 5

## --- Darts night ------------------------------------------------------------------
## Which weekday (0 Monday … 6 Sunday) is darts night, and from when.
@export_range(0, 6) var darts_weekday: int = 4
@export var darts_from: int = 1140

## How many darts a go is.
@export var darts_per_go: int = 3

## The board's rings, from the bull outwards, as a share of the board's
## radius, and what a dart in each scores. Outside the last: nothing.
@export var ring_radii: Array[float] = [0.08, 0.2, 0.45, 0.75, 1.0]
@export var ring_points: Array[int] = [50, 25, 15, 10, 5]

## How fast the aim swings across the board, in sweeps a second (one sweep
## is from one edge to the other and back).
@export var aim_sweeps_per_second: float = 0.7

## How far the aim swings past the board's edge, as a share of its radius.
@export var aim_overshoot: float = 1.15

## Tonight's best score among the regulars, to beat for the prize: the same
## all evening (seeded by the date), somewhere between these.
@export var rival_min: int = 55
@export var rival_max: int = 105

## What beating it wins.
@export var darts_prize_gold: int = 120

## Who's said to hold tonight's best score, when nobody with a name is in.
@export var regulars_name: String = "One of the regulars"

## --- Rumours -----------------------------------------------------------------------
## What Nell says when you come to the bar, one a day, by kind. Each has
## {placeholders} the tavern fills in: {items}, {item}, {where}, {fish},
## {hours}, {tides}, {weather}. A kind that has nothing true to say tonight
## (no fish worth telling of) is skipped for the next.
@export var rumour_chalkboard: String = "Tomorrow I'll be after {items} for the kitchen. Bring them in and I'll pay you well."
@export var rumour_forage: String = "Dot says there'll be {item} about {where} tomorrow, if you're quick."
@export var rumour_fish: String = "Talk at the bar tonight's of a big {fish} in {where}. Bites {hours}, they say."
@export var rumour_tides: String = "Tam reckons low water tomorrow's {tides}. Mind you're not caught on the rocks."
@export var rumour_weather: String = "My knee says {weather} tomorrow, and my knee's never wrong."

## The name of each kind of water, for the fish rumour: "the town pond".
@export var water_words: Dictionary[StringName, String] = {}

## The name of each place forage grows, for the forage rumour: "in the Woods".
@export var place_words: Dictionary[StringName, String] = {}

## Plain gossip, for an evening when the rumours above have nothing to say.
@export var gossip: Array[String] = []
