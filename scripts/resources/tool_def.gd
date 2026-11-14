class_name ToolDef
extends ItemDef
##
## ToolDef — an item you hold and use on a tile: a hoe, a watering can, a
## packet of seeds, a sprinkler to put down.
##
## The id, name, icon and prices come from ItemDef. This adds what using it
## costs and does. The behaviour is `action`, a ToolAction resource embedded
## in the same .tres file; see tool_action.gd for why the two are split.
##
## Tiers (Stage 5, DECISIONS 024): a tool can list better versions of itself
## in `tiers`. Which tier the player has is GameState's business (it comes from
## the upgrades they've bought); this file only answers "at tier N, what's it
## called, what does it cost, and which tiles does it cover?". The action
## itself never knows about tiers — it is still asked about one tile at a time.
##

## Energy for one use at tier 0. Better tiers set their own cost.
@export var energy_cost: float = 0.0
@export var action: ToolAction

## True for things used up as you use them, like seeds: each use takes one
## from the bag, and when the last one goes the item leaves the hotbar.
## False for tools, which last for ever.
@export var consumed_on_use: bool = false

## Better versions of this tool, in order: tier 1 first. Empty for things that
## never improve, like seeds.
@export var tiers: Array[ToolTier] = []


## The highest tier this tool has.
func max_tier() -> int:
	return tiers.size()


## The ToolTier for `tier`, or null for tier 0 (the tool as it comes).
func tier_info(tier: int) -> ToolTier:
	if tier <= 0 or tiers.is_empty():
		return null
	return tiers[mini(tier, tiers.size()) - 1]


func name_at(tier: int) -> String:
	var info := tier_info(tier)
	return info.display_name if info != null else display_name


func energy_cost_at(tier: int) -> float:
	var info := tier_info(tier)
	return info.energy_cost if info != null else energy_cost


## Every tile one use covers at `tier`, for a player facing `facing` (a unit
## step such as Vector2i.UP) whose target tile is `front`. At tier 0 that's
## just `front`, so a one-tile tool behaves exactly as it always has.
func cells_at(tier: int, front: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var info := tier_info(tier)
	var length := info.length if info != null else 1
	var width := info.width if info != null else 1
	# "Across" is facing turned a quarter: up/down facing spreads left-right.
	var across := Vector2i(facing.y, facing.x)
	var half := floori((width - 1) / 2.0)
	var cells: Array[Vector2i] = []
	for step in length:
		for side in range(-half, width - half):
			cells.append(front + facing * step + across * side)
	return cells
