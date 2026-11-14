class_name PlantAction
extends ToolAction
##
## Seeds — plants `crop` in tilled, empty soil.
##
## One script serves every kind of seed: which crop it plants is data, set in
## the seed's .tres file. A new crop's seeds are a new .tres, not new code.
## Until the inventory arrives (Stage 4) seeds are unlimited.
##

@export var crop: CropDef


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return crop != null and farm.can_plant(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.plant(cell, crop)
