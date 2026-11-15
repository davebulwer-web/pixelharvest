extends StaticBody2D
##
## PlacedObject — something the player put down and can pick back up with E:
## a sprinkler, or a decoration (a scarecrow, a lamp post; DECISIONS 039).
##
## Like the shipping bin, this node is only the object's presence on the farm
## (picture, collision, answering E). Where it stands is in FarmData, and what
## it does overnight is in its ObjectDef — FarmData runs the sprinklers, not
## this node, so they water even on a night the farm scene isn't loaded.
##

const TILE_PX := 16


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return home_cell() == cell


func interact() -> void:
	GameState.pick_up_object(home_cell())


## The tile this stands on. The origin is the bottom-middle of its tile
## (main.gd, cell_base), so step 1px up to land inside it.
func home_cell() -> Vector2i:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX)
