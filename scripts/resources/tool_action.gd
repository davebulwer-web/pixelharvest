class_name ToolAction
extends Resource
##
## ToolAction — the one interface every tool acts on tiles through (rule 5).
##
## A tool is two things: a ToolDef (name, energy cost — data) and a ToolAction
## (what it actually does to a tile — behaviour). Each concrete tool overrides
## the two methods below in its own small script under scripts/tools/.
##
## Why this shape: the code that *uses* a tool never needs to know which tool
## it is. It asks "can you act on this cell?" and then "act on it". So adding
## a scythe in Stage 5 is a new .tres plus a new ten-line script, and the
## player code doesn't change at all — no growing if/else of tool names.
##
## Why split the check from the action: the player only pays energy when the
## action will actually do something. Swinging a hoe at a pond is free.
##


## True if this tool would do something useful to `cell`. Must not change anything.
func can_use(_farm: FarmData, _cell: Vector2i) -> bool:
	return false


## Do it. Only called after can_use() returned true and the energy was paid.
func apply(_farm: FarmData, _cell: Vector2i) -> void:
	pass


## False if this tool can't be used at all in the season `season_id` — seeds
## out of season. Most tools work all year, so that's the default. The player
## asks this before can_use(), and the hotbar asks it to grey out what can't
## be used today.
func usable_in_season(_season_id: StringName) -> bool:
	return true


# --- Clearing the farm (DECISIONS 060) -----------------------------------------
# The farm's new ground starts covered in debris (stones, stumps, brambles,
# nettles: ObjectDefs). A tool says which of them it clears, by ObjectDef id,
# in its .tres; the hoe, the axe and the sickle ask clears_at() alongside
# their usual jobs. What clearing gives is the debris's own business.

## The debris this tool clears, by ObjectDef id (&"stones" for the hoe).
## Empty for a tool that clears nothing.
@export var clears: Array[StringName] = []


## True if there's debris at `cell` that this tool clears.
func clears_at(farm: FarmData, cell: Vector2i) -> bool:
	return not clears.is_empty() and farm.can_clear(cell, clears)


# --- Away from the farm (DECISIONS 053) ----------------------------------------
# The axe is the first tool that works somewhere other than the farm: in the
# Woods. Those places have no FarmData, so they're asked through `place`, the
# map's scene, instead. Each place says for itself what its tools can do
# there (the Woods answers choppable_at). Most tools only work on the farm,
# so by default these say no.

## True if this tool would do something to `cell` in `place` (the scene of a
## map that isn't the farm). Must not change anything.
func can_use_away(_place: Node, _cell: Vector2i) -> bool:
	return false


## Do it, away from the farm. Only called after can_use_away() said yes and
## the energy was paid.
func apply_away(_place: Node, _cell: Vector2i) -> void:
	pass


# --- Used on the farmer (DECISIONS 056) ----------------------------------------
# Food is used on the farmer rather than on a tile, so it works anywhere,
# including the shops and the farmhouse. The player asks this first; a tool
# that says yes is given to GameState.eat() and its tile methods are never
# asked.

## True for something used on the farmer, not a tile: a dish (EatAction).
func used_on_self() -> bool:
	return false
