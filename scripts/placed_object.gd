extends StaticBody2D
##
## PlacedObject — something the player put down and can pick back up with E:
## a sprinkler, or a decoration (a scarecrow, a lamp post; DECISIONS 039), or
## a bee hive (DECISIONS 057). An object that has made something (honey in
## the hive) gives that up to the first E, and is only picked up by the next.
## If the scene has a child called "Ready", it shows while something waits.
##
## Like the shipping bin, this node is only the object's presence on the farm
## (picture, collision, answering E). Where it stands is in FarmData, and what
## it does overnight is in its ObjectDef — FarmData runs the sprinklers, not
## this node, so they water even on a night the farm scene isn't loaded.
##

const TILE_PX := 16


func _ready() -> void:
	add_to_group(&"interactable")
	_update_ready()
	# Collected, or (should the player be watching) made: show it at once.
	EventBus.object_emptied.connect(func(_c: Vector2i, _o: StringName, _i: StringName, _n: int) -> void: _update_ready())
	EventBus.object_made.connect(func(_c: Vector2i, _o: StringName, _i: StringName, _n: int) -> void: _update_ready())


func occupies(cell: Vector2i) -> bool:
	return home_cell() == cell


## E only reaches this on the tile straight ahead (DECISIONS 079), because E
## picks it up: a sprinkler shouldn't come up because you missed the crop
## beside it. Except while something waits in it (a hive's honey): then E
## collects that, which does no harm, so a near miss is fine.
func aim_exactly() -> bool:
	var plot := GameState.plot_here()
	return plot == null or plot.made_at(home_cell()) <= 0


func interact() -> void:
	if GameState.collect_from_object(home_cell()):
		return
	GameState.pick_up_object(home_cell())


## Show the "Ready" marker (a jar over the hive) while something waits here.
func _update_ready() -> void:
	var marker := get_node_or_null(^"Ready") as CanvasItem
	if marker == null:
		return
	var plot := GameState.plot_here()
	marker.visible = plot != null and plot.made_at(home_cell()) > 0


## The tile this stands on. The origin is the bottom-middle of its tile
## (main.gd, cell_base), so step 1px up to land inside it.
func home_cell() -> Vector2i:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX)
