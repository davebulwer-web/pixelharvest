class_name PlantAction
extends ToolAction
##
## Seeds — plants `crop` in tilled, empty soil.
##
## One script serves every kind of seed: which crop it plants is data, set in
## the seed's .tres file. A new crop's seeds are a new .tres, not new code.
## Seeds are counted: the ToolDef has consumed_on_use set, so the player takes
## one from the bag for each planting. This script doesn't need to know.
##
## A crop's own rules about where it goes are asked too (DECISIONS 047): a
## water-loving crop only goes in beside water, and an overwintering one only
## in its planting season (CropDef.can_plant_in), not every season it grows in.
##
## Seeds only go in during a season their crop grows in (DECISIONS 025): the
## player asks usable_in_season() before anything else, so planting out of
## season simply doesn't happen — no energy, no seed used — and the hotbar
## greys the packet out to say why. (This script can't ask GameState itself:
## GameState loads the rules, the rules load the seeds, and the seeds would
## load GameState — a loop that stops the game starting.)
##

@export var crop: CropDef


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return crop != null and farm.can_plant_crop(cell, crop)


func usable_in_season(season_id: StringName) -> bool:
	return crop != null and crop.can_plant_in(season_id)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.plant(cell, crop)
