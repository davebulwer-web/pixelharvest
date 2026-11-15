class_name HoeAction
extends ToolAction
##
## Hoe — turns grass into tilled soil, ready for seeds. On a tile with weeds
## (DECISIONS 045) it digs the weeds out instead, crop or no crop: one swing,
## one job, so hoeing weedy grass takes a second swing to till it.
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.has_weeds(cell) or farm.can_till(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	if not farm.pull_weeds(cell):
		farm.till(cell)
