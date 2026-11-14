class_name HoeAction
extends ToolAction
##
## Hoe — turns grass into tilled soil, ready for seeds.
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.can_till(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.till(cell)
