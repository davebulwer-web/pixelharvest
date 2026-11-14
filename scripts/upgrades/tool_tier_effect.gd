class_name ToolTierEffect
extends UpgradeEffect
##
## Raises one tool to a better tier — a wider hoe, a bigger watering can.
## The tiers themselves (name, area, energy) are on the tool's own ToolDef;
## this only says "you now have tier N of that tool".
##

@export var tool: ToolDef
@export var tier: int = 1


func category() -> StringName:
	return &"tools"


func tool_tier(tool_id: StringName) -> int:
	return tier if tool != null and tool.id == tool_id else 0


func on_bought(_upgrade: UpgradeDef) -> void:
	EventBus.tool_upgraded.emit(tool.id, tier)
