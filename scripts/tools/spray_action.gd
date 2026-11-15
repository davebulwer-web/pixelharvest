class_name SprayAction
extends ToolAction
##
## Pest spray (DECISIONS 048) — clears the aphids off one crop. Marlow sells
## it by the dose: the item has consumed_on_use set, so each crop sprayed
## takes one from the bag, and a crop without aphids isn't sprayed at all.
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.has_pests(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.clear_pests(cell)
