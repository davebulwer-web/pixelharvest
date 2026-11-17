class_name FishAction
extends ToolAction
##
## Fishing rod (DECISIONS 054) and handline (DECISIONS 065) — casts a line
## into the water ahead.
##
## The rod only casts: it announces EventBus line_cast with the water's cell
## and kind, and Fishing (the autoload) does the waiting, the bite and the
## reel. So the player code is the same as for any tool (rule 5): Space asks
## "can you act here?", pays the energy, and says "act".
##
## Where there's water to cast into:
##   - on the farm, its pond (FarmData's WATER tiles), which is `farm_water`;
##   - away from the farm, wherever the map scene answers water_at(cell)
##     (the town's pond and river, the Woods' stream, the Cove's sea off
##     the pier, the quay and the breakwater: DECISIONS 065).
## A line can be limited to some kinds of water (`waters`): Tam's handline
## is a ToolDef with this same action, for the sea only.
## In winter every fresh water is frozen (the season's tiles draw it as ice;
## the sea never freezes). The
## rod still casts at it, and Fishing decides what that means: on bare ice,
## Space cuts a hole; at a hole, the line goes down through it (DECISIONS
## 055). So the rod itself never needs to know the season.
##
## Must not use the GameState autoload (tools can be listed in the starting
## kit, which game_rules.tres preloads).
##

## How long the float waits for a bite with this rod, as a multiple of the
## fishing rules' wait. The fine rod is a tier of this one, and its speed is
## in the fishing rules (rod_tier_wait_multipliers), so this stays 1.
@export var bite_wait_multiplier: float = 1.0

## The kind of water the farm's pond is.
@export var farm_water: StringName = &"pond"

## The kinds of water this line can be cast into (DECISIONS 065): Tam's
## handline is for the sea only ([&"sea"]). Empty: any water (Wren's rod).
@export var waters: Array[StringName] = []


## True if this line can be cast into `water` (&"" is dry land: never).
func casts_into(water: StringName) -> bool:
	return water != &"" and (waters.is_empty() or water in waters)


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	var tile := farm.tile(cell)
	return tile != null and tile.terrain == FarmTile.Terrain.WATER and casts_into(farm_water)


func apply(_farm: FarmData, cell: Vector2i) -> void:
	EventBus.line_cast.emit(cell, farm_water, bite_wait_multiplier)


func can_use_away(place: Node, cell: Vector2i) -> bool:
	return place != null and place.has_method(&"water_at") and casts_into(place.water_at(cell))


func apply_away(place: Node, cell: Vector2i) -> void:
	EventBus.line_cast.emit(cell, place.water_at(cell), bite_wait_multiplier)
