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
## Stage 12 (DECISIONS 047) added the crop *rules*: each is a field or two
## here, off by default, so the first eight crops didn't change. Bunches
## (harvest_max), trellis (solid), perennial, overwintering (plant_seasons and
## rests_in), hardy (needs_water), water-loving (near_water), weather-loving
## (loves_weather), seed-returning (seed_chance), tall (for storms). Flowers
## are a tag on the produce (ItemDef.tags), since bees and the flower show
## care about the flower, not the plant.
##

@export var id: StringName
@export var display_name: String

## How many growth stages after the seed. The crop is ready to harvest when
## it reaches the last one.
@export var growth_stages: int = 4

## Watered days needed to move from one stage to the next. A day without
## water is a day of no growth, and a night thirstier: enough dry nights and
## the crop wilts, then dies (HazardRules, DECISIONS 045).
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

## Bunches (Stage 12): above harvest_amount, each harvest gives a random number
## from harvest_amount to this. 0 (or anything not above harvest_amount) means
## always exactly harvest_amount.
@export var harvest_max: int = 0

## Seed-returning (Stage 12): the chance, 0 to 1, that a harvest also gives
## back a packet of this crop's seeds (whichever seeds plant it, ContentDB.seeds_for).
@export_range(0.0, 1.0, 0.05) var seed_chance: float = 0.0

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

# --- Rules (Stage 12, DECISIONS 047) ------------------------------------------

## Overwintering: the seasons seeds can go in, if not every season in
## `seasons`. Garlic grows in autumn and spring but is planted only in autumn.
@export var plant_seasons: Array[StringName] = []

## Seasons the crop lives through without growing, asleep: no growth, no
## thirst, and the season's turn doesn't kill it. Garlic rests in winter.
@export var rests_in: Array[StringName] = []

## Perennial: rests through every season it doesn't grow in, so it never dies
## at a season's turn and comes back each year. A regrowing perennial that
## goes to sleep ripe loses that crop: it wakes ready to regrow, not ripe.
@export var perennial: bool = false

## Hardy: grows every night whether watered or not, and is never thirsty.
@export var needs_water: bool = true

## Water-loving: can only be planted on a tile beside water (the pond), the
## eight around it.
@export var near_water: bool = false

## Weather-loving: on a day with one of these weathers (WeatherDef ids, e.g.
## &"heatwave"), a crop that grew that night grows a second day's worth.
@export var loves_weather: Array[StringName] = []

## Trellis: once it's past the seed, the player can't walk through it, so the
## layout of a field matters (leave paths).
@export var solid: bool = false

## Tall: a storm may flatten it unless something that shelters (a fence,
## ObjectDef.shelters_radius) stands close by (WeatherDef.flattens_tall_crops).
@export var tall: bool = false


## True if this crop keeps growing in the season `season_id`.
func grows_in(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons


## True if seeds of this crop can go in during `season_id`: its plant_seasons
## if it has any, otherwise every season it grows in.
func can_plant_in(season_id: StringName) -> bool:
	if not plant_seasons.is_empty():
		return season_id in plant_seasons
	return grows_in(season_id)


## True if the crop is asleep in `season_id`: alive, but not growing.
func rests_during(season_id: StringName) -> bool:
	return not grows_in(season_id) and (perennial or season_id in rests_in)


## True if the crop lives through `season_id`, growing or asleep. A season's
## turn (and frost) kills every crop that doesn't.
func survives(season_id: StringName) -> bool:
	return grows_in(season_id) or rests_during(season_id)


## How many to pick this time: harvest_amount, or for bunches a roll from
## harvest_amount to harvest_max on `dice`.
func roll_harvest(dice: RandomNumberGenerator) -> int:
	if harvest_max > harvest_amount and dice != null:
		return dice.randi_range(harvest_amount, harvest_max)
	return harvest_amount


## True if `stage` blocks the way: a trellis crop that has come up.
func is_solid_at(stage: int) -> bool:
	return solid and stage >= 1


## True if `stage` is the final, harvestable one.
func is_ready_stage(stage: int) -> bool:
	return stage >= growth_stages


## Watered days needed to leave `stage`. A regrowing crop that has already been
## harvested waits regrow_days for its last step instead of days_per_stage.
##
## `scale` is the difficulty's grow_time_multiplier (DECISIONS 040). Days are
## whole, so the scaled time is rounded along the way rather than stage by
## stage: at 1.25 a 4-day parsnip takes 5 days (stages of 1, 2, 1, 1), where
## rounding each stage would have made it 4 or 8. No stage takes under a day.
func days_to_grow_from(stage: int, regrowing: bool, scale: float = 1.0) -> int:
	if regrowing and stage == growth_stages - 1:
		return days_to_regrow(scale)
	var before := roundi(stage * days_per_stage * scale)
	var after := roundi((stage + 1) * days_per_stage * scale)
	return maxi(1, after - before)


## Watered days for a regrowing crop to be ready again after a harvest.
func days_to_regrow(scale: float = 1.0) -> int:
	return maxi(1, roundi(regrow_days * scale))


## The rules this crop has, in a few words each, for the seed shop's detail
## line: "Gives 1–3 a time. Grows on a trellis: you can't walk through it."
## Empty for a crop with none.
func rules_text() -> String:
	var parts: PackedStringArray = []
	if harvest_max > harvest_amount:
		parts.append("Gives %d–%d a time." % [harvest_amount, harvest_max])
	if not needs_water:
		parts.append("Hardy: grows without watering.")
	if near_water:
		parts.append("Must be planted beside water.")
	if solid:
		parts.append("Grows on a trellis: you can't walk through it.")
	if perennial:
		parts.append("Comes back every year.")
	elif not rests_in.is_empty():
		parts.append("Sleeps through %s." % " and ".join(rests_in))
	if not loves_weather.is_empty():
		parts.append("Loves %s: grows twice as fast." % " and ".join(loves_weather))
	if seed_chance > 0.0:
		parts.append("Sometimes gives seeds back.")
	if tall:
		parts.append("Tall: a storm can flatten it unless a fence is close.")
	return " ".join(parts)


## Total watered days from planting to the first harvest, at `scale`. Handy
## for the shop and for balancing; nothing in the growing code uses it.
func days_to_mature(scale: float = 1.0) -> int:
	var total := 0
	for stage in growth_stages:
		total += days_to_grow_from(stage, false, scale)
	return total
