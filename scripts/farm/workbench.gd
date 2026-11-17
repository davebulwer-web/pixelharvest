class_name Workbench
extends StaticBody2D
##
## Workbench — the old farmer's bench under the lean-to by the farmhouse
## (DECISIONS 063). Face it and press E to make things from stone, timber and
## fibre: the plans the farmer knows (RecipeDef made_at &"workbench").
##
## It stands on the farm as an object (ObjectDef `workbench`), like the
## shipping bin: where it is lives in FarmData, and this node is only its
## picture, its collision and its answer to E. It isn't a PlacedObject, so E
## never picks it up.
##
## It starts one leg short. The first E with enough stones in the bag props
## it level (GameState.mend_workbench), which earns RULES.workbench_unlock and
## with it the old farmer's first plans. After that E opens the plans menu,
## the stove's CookMenu with `place` set to the workbench.
##

const TILE_PX := 16
const MENDED := preload("res://assets/sprites/farm/workbench.png")
const BROKEN := preload("res://assets/sprites/farm/workbench_broken.png")

var _menu: CookMenu


func _ready() -> void:
	add_to_group(&"interactable")
	_menu = CookMenu.new()
	_menu.name = "PlansMenu"
	_menu.place = &"workbench"
	add_child(_menu)
	_update_look()
	EventBus.unlocked.connect(func(_id: StringName) -> void: _update_look())


## True if the bench stands on `cell`. The origin is the bottom-middle of its
## tile (main.gd, cell_base), so step 1px up to land inside it.
func occupies(cell: Vector2i) -> bool:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX) == cell


func interact() -> void:
	if not GameState.workbench_open():
		_try_to_mend()
		return
	if GameState.known_recipes(&"workbench").is_empty():
		EventBus.message_posted.emit("The workbench is ready, but you don't know any plans yet")
		return
	_menu.open()


## E at the broken bench: prop it up if the bag has what it takes, otherwise
## say what it takes and where to find it.
func _try_to_mend() -> void:
	var rules := GameState.RULES
	var item := rules.workbench_mend_item
	var count := rules.workbench_mend_count
	if not GameState.mend_workbench():
		EventBus.message_posted.emit(
				"The old farmer's workbench, one leg short. %d %s would prop it level: the hoe turns them up on the new ground"
				% [count, QuestGoal.plural(item.display_name, count)])
		return
	var plans: Array[String] = []
	for recipe in GameState.known_recipes(&"workbench"):
		plans.append(recipe.display_name().to_lower())
	var text := "You prop the short leg level on %d %s." % [count, QuestGoal.plural(item.display_name, count)]
	if not plans.is_empty():
		text += " Pinned above the bench, the old farmer's plans: %s" % _join(plans)
	EventBus.message_posted.emit(text)


func _update_look() -> void:
	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = MENDED if GameState.workbench_open() else BROKEN


func _join(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
