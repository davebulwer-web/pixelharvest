class_name PlantAction
extends ToolAction
##
## Seeds — plants `crop` in tilled, empty soil.
##
## One script serves every kind of seed: which crop it plants is data, set in
## the seed's .tres file. A new crop's seeds are a new .tres, not new code.
## Seeds are counted: the ToolDef has consumed_on_use set, so the player takes
## one from the bag for each planting. This script doesn't need to know.
##

@export var crop: CropDef


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return crop != null and farm.can_plant(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.plant(cell, crop)
