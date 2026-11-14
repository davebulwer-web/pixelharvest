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
