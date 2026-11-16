class_name FishAction
extends ToolAction
##
## Fishing rod (DECISIONS 054) — casts a line into the water ahead.
##
## The rod only casts: it announces EventBus line_cast with the water's cell
## and kind, and Fishing (the autoload) does the waiting, the bite and the
## reel. So the player code is the same as for any tool (rule 5): Space asks
## "can you act here?", pays the energy, and says "act".
##
## Where there's water to cast into:
##   - on the farm, its pond (FarmData's WATER tiles), which is `farm_water`;
##   - away from the farm, wherever the map scene answers water_at(cell)
##     (the town's pond and river, the Woods' stream).
## Every water is frozen in winter (the season's tiles draw it as ice), so the
## rod can't be used then: usable_in_season says no, and the hotbar greys it.
## Session 2 cuts a hole in the ice.
##
## Must not use the GameState autoload (tools can be listed in the starting
## kit, which game_rules.tres preloads): the frozen seasons are read from
## data/fishing_rules.tres directly.
##

const FISHING_RULES: FishingRules = preload("res://data/fishing_rules.tres")

## How long the float waits for a bite with this rod, as a multiple of the
## fishing rules' wait: a better rod bites sooner (below 1).
@export var bite_wait_multiplier: float = 1.0

## The kind of water the farm's pond is.
@export var farm_water: StringName = &"pond"


func usable_in_season(season_id: StringName) -> bool:
	return season_id not in FISHING_RULES.frozen_seasons


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	var tile := farm.tile(cell)
	return tile != null and tile.terrain == FarmTile.Terrain.WATER


func apply(_farm: FarmData, cell: Vector2i) -> void:
	EventBus.line_cast.emit(cell, farm_water, bite_wait_multiplier)


func can_use_away(place: Node, cell: Vector2i) -> bool:
	return place != null and place.has_method(&"water_at") and place.water_at(cell) != &""


func apply_away(place: Node, cell: Vector2i) -> void:
	EventBus.line_cast.emit(cell, place.water_at(cell), bite_wait_multiplier)
