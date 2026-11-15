class_name HazardRules
extends Resource
##
## HazardRules — the numbers behind the farm's hazards (Stage 11, DECISIONS
## 045): crops going thirsty, weeds coming up, crows taking crops.
##
## One file, data/hazard_rules.tres, which game_rules.tres points at. Each
## hazard is a small overnight rule (FarmData.advance_day for thirst,
## FarmHazards for the rest: weeds, crows, storms, aphids), and every number it uses is here, so tuning a
## hazard never means touching code (rule 6).
##
## The difficulty scales them (DifficultyDef.hazard_multiplier and
## thirst_kills): the numbers here are Standard's.
##
## Weeds and crows don't exist from day 1. Each waits for an unlock that the
## calendar opens (spring day 6 and day 15), so the notice board pins them up
## the week before and the morning summary announces them: the rule from the
## roadmap that every hazard is announced before it bites.
##
## Must not use the GameState autoload: game_rules.tres preloads this file,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

# --- Thirst ------------------------------------------------------------------

## Nights in a row without water before a crop looks wilted. It still grows
## normally the next night it's watered; wilting is the warning.
@export var wilt_after_dry_nights: int = 2

## Nights in a row without water before a crop dies. Only on difficulties
## where thirst kills (not Relaxed). Should be more than wilt_after_dry_nights,
## so there's always a wilted day to notice it in.
@export var die_after_dry_nights: int = 3

# --- Weeds -------------------------------------------------------------------

## Weeds start coming up the night this opens (spring day 6). Null: from day 1.
@export var weeds_start: UnlockDef

## The seasons weeds come up in, by SeasonTheme id. Empty means every season.
@export var weed_seasons: Array[StringName] = []

## Each night, the chance that weeds come up on each tile of tilled soil
## (with or without a crop), and on each tile of grass beside a crop.
@export_range(0.0, 1.0) var weed_chance_tilled: float = 0.05
@export_range(0.0, 1.0) var weed_chance_grass: float = 0.02

## No more than this many new patches of weeds in one night, however big the
## farm, so a large field doesn't wake up to a carpet of them.
@export var most_new_weeds: int = 8

## What pulling up a patch of weeds gives: fibre (Brann will want it).
@export var weed_item: ItemDef

## The energy it costs to pull a patch of weeds by hand with E. The hoe
## costs its own energy instead.
@export var pull_weeds_energy: float = 1.0

## Each night, the chance that a tile of bare tilled soil (no crop, no weeds)
## goes back to grass. 0 keeps tilled soil for ever.
@export_range(0.0, 1.0) var untill_chance: float = 0.05

# --- Crows -------------------------------------------------------------------

## Crows start coming the night this opens (spring day 15). Null: from day 1.
@export var crows_start: UnlockDef

## Crows only come when more than this many crops are out of reach of every
## scarecrow. A small garden is left alone.
@export var crow_safe_crops: int = 16

## On a night when there are enough unguarded crops, the chance crows come.
@export_range(0.0, 1.0) var crow_chance: float = 0.75

## When they come, they take between one and this many crops.
@export var crows_most_taken: int = 2


# --- Aphids (Stage 12, DECISIONS 048) -----------------------------------------

## Aphids start the night this opens (autumn day 1). Null: from day 1.
@export var pests_start: UnlockDef

## The seasons aphids live in. Out of them, the cold clears every crop of
## them overnight. Empty means every season.
@export var pest_seasons: Array[StringName] = []

## Each night, the chance that aphids land on one growing crop somewhere on
## the farm (a new outbreak).
@export_range(0.0, 1.0) var pest_outbreak_chance: float = 0.3

## Each night, for each crop with aphids, the chance they pass to one growing
## crop beside it.
@export_range(0.0, 1.0) var pest_spread_chance: float = 0.5

## A flower within this many tiles of a crop (a square round it) slows the
## aphids reaching it...
@export var flower_radius: int = 2

## ...to this share of the spread chance (0.25: a quarter as likely).
@export_range(0.0, 1.0) var flower_slows_pests: float = 0.25


## True if aphids live in the season `season_id`.
func pests_live_in(season_id: StringName) -> bool:
	return pest_seasons.is_empty() or season_id in pest_seasons


## True if weeds come up in the season `season_id`.
func weeds_grow_in(season_id: StringName) -> bool:
	return weed_seasons.is_empty() or season_id in weed_seasons
