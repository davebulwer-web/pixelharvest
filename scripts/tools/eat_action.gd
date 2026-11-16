class_name EatAction
extends ToolAction
##
## Eating (DECISIONS 056) — what a dish does when it's used: it gives back
## `energy`. A dish is a ToolDef with this action, kept in data/dishes/, so it
## sits on the hotbar like a packet of seeds and Space uses it.
##
## Food is the one thing on the hotbar that isn't used on a tile: it's used on
## the farmer, wherever they are (the farm, the town, a shop, the Woods). So
## it answers used_on_self() with true, and the player hands it to
## GameState.eat() instead of asking about the tile ahead. Its tile methods
## keep the defaults (it does nothing to any tile), so the cursor and the
## farm's own checks ignore it.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## Energy one helping gives back. Never more than the farmer's maximum.
@export var energy: float = 30.0


func used_on_self() -> bool:
	return true
