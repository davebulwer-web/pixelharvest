class_name ToolDef
extends Resource
##
## ToolDef — the data half of a tool: what it's called and what it costs.
##
## The behaviour half is `action`, a ToolAction resource embedded in the same
## .tres file. See tool_action.gd for why the two are split.
##
## Tiers and area of effect (1 → 3 → 9 tiles) arrive in Stage 5 as more fields
## here; nothing about how tools are used will need to change for them.
##

@export var id: StringName
@export var display_name: String
@export var energy_cost: float = 0.0
@export var action: ToolAction
