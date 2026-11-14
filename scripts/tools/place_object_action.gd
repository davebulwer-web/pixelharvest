class_name PlaceObjectAction
extends ToolAction
##
## Puts an object down on the farm — a sprinkler, for now. One script for
## anything placeable: which object it places is data, set in the item's
## .tres. The item has consumed_on_use set, so placing takes it out of the bag.
##
## The object is named by id rather than held directly. The object's
## definition points back at this item (what you get when you pick it up), and
## two .tres files that point at each other can't be loaded.
##

@export var object_id: StringName


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return ContentDB.object(object_id) != null and farm.can_place(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.place_object(cell, object_id)
