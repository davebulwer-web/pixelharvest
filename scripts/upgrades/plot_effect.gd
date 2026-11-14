class_name PlotEffect
extends UpgradeEffect
##
## A field: an area of the farm that starts overgrown with thicket and is
## cleared to grass when bought.
##
## The area is only written here. FarmLayout reads locked_area() when it
## builds a new farm, so adding a field is this one file and nothing else.
## Farms from before Stage 5 have no thicket, so for them every field is
## already "cleared" and is_useful() keeps it out of the shop.
##

## In farm cells: position is the top-left cell, size is width × height.
@export var area: Rect2i


func category() -> StringName:
	return &"land"


func locked_area() -> Rect2i:
	return area


func is_useful() -> bool:
	return GameState.farm.has_terrain_in(area, FarmTile.Terrain.THICKET)


func on_bought(upgrade: UpgradeDef) -> void:
	GameState.farm.clear_thicket(area)
	EventBus.plot_unlocked.emit(upgrade.id)
