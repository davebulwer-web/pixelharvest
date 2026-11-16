class_name FertiliseAction
extends ToolAction
##
## Fertiliser (DECISIONS 058) — puts a bag of growth feed or mulch into the
## tilled soil in front of you. One script for every kind: which one it is
## (and so what the soil then does) is the FertiliserDef named by
## `fertiliser_id`, the item this action belongs to.
##
## Named by id rather than held directly, as PlaceObjectAction does: the
## item holds this action, so the action can't hold the item back.
##

@export var fertiliser_id: StringName


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.can_fertilise(cell, _fertiliser())


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.fertilise(cell, _fertiliser())


func _fertiliser() -> FertiliserDef:
	return ContentDB.item(fertiliser_id) as FertiliserDef
