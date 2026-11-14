class_name ToolDef
extends ItemDef
##
## ToolDef — an item you hold and use on a tile: a hoe, a watering can, a
## packet of seeds.
##
## The id, name, icon and prices come from ItemDef. This adds what using it
## costs and does. The behaviour is `action`, a ToolAction resource embedded
## in the same .tres file; see tool_action.gd for why the two are split.
##
## Tiers and area of effect (1 → 3 → 9 tiles) arrive in Stage 5 as more fields
## here; nothing about how tools are used will need to change for them.
##

@export var energy_cost: float = 0.0
@export var action: ToolAction

## True for things used up as you use them, like seeds: each use takes one
## from the bag, and when the last one goes the item leaves the hotbar.
## False for tools, which last for ever.
@export var consumed_on_use: bool = false
