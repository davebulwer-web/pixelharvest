class_name WateringCanAction
extends ToolAction
##
## Watering can — waters tilled soil. Watered soil is what lets a crop grow
## overnight; the water dries out when the day advances (next session).
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.can_water(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.water(cell)
