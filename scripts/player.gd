class_name Player
extends CharacterBody2D
##
## Player — movement, four-direction animation, and the player's actions:
## using the held tool (or eating the held dish), and interacting (harvest,
## shipping bin, the bed, the stove).
##
## Away from the farm (the town, a shop, the farmhouse) `can_farm` is switched
## off by the scene: tools and harvesting are about the farm's tiles, which
## aren't there. The greenhouse leaves it on: its plot is farmed just like the
## farm, and GameState.plot_here() says which plot the tools are working on
## (DECISIONS 057).
##
## The node origin sits at the character's FEET, not the centre of the sprite.
## The AnimatedSprite2D is offset upward to achieve that. This matters for two
## reasons: Y-sorting compares node positions, so the feet are the correct
## reference for "who is in front"; and the tile the player is standing on is
## simply the tile under the origin.
##
## Tools act on the tile *in front of* the player, not under them — you hoe
## the ground ahead of you, as in every game of this kind. Upgraded tools
## (Stage 5) cover more tiles, starting from that one and running ahead.
##

## Pixels per second. At 16px tiles this is roughly 4.4 tiles a second.
const SPEED := 70.0
const TILE_PX := 16

## Where on the body counts as "standing". The origin is the very bottom edge
## of the feet, which sits exactly on a tile boundary when the player is lined
## up with the grid — so it would flip between two cells. The middle of the
## collision box (4px up) is unambiguous and matches what the eye reads as
## "the tile they're standing on".
const STANDING_PROBE := Vector2(0, -4)

const FACING_VECTORS: Dictionary = {
	&"down": Vector2i.DOWN,
	&"up": Vector2i.UP,
	&"left": Vector2i.LEFT,
	&"right": Vector2i.RIGHT,
}

@onready var _sprite: AnimatedSprite2D = $Sprite

## Last direction faced, so idle animation keeps facing the right way.
var _facing: StringName = &"down"

## True on the farm. The town and the shops switch it off (see above).
var can_farm: bool = true

## Away from the farm, the map scene whose tools can still do something there
## (DECISIONS 053): the Woods set it to themselves, so the axe works there,
## and the town too, for the fishing rod at its pond and river (DECISIONS
## 054). Null in the shops and the farmhouse: nothing to use a tool on.
var tool_place: Node = null


func _ready() -> void:
	# Fishing (DECISIONS 054) finds whoever holds the rod by this group, to
	# draw the line from their hands.
	add_to_group(&"player")


func _physics_process(_delta: float) -> void:
	# A line is out (DECISIONS 054): stand still, facing the water, and leave
	# the keys to Fishing until it's reeled in.
	if Fishing.is_busy():
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	velocity = direction * SPEED
	move_and_slide()
	_update_animation(direction)


## Discrete presses (use, switch tool) are handled here rather than polled in
## _physics_process, so one key press is exactly one action.
func _unhandled_input(event: InputEvent) -> void:
	if Fishing.is_busy():
		return
	if event.is_action_pressed(&"use_tool"):
		# Food is used on the farmer, not a tile, so it's eaten anywhere
		# (DECISIONS 056): even in a shop, where no other tool works.
		var held := GameState.selected_tool()
		if held != null and held.action != null and held.action.used_on_self():
			GameState.eat(held)
		elif can_farm:
			_use_tool()
		elif tool_place != null:
			_use_tool_away()
	elif event.is_action_pressed(&"interact"):
		_interact()
	elif event.is_action_pressed(&"sleep"):
		# Enter used to sleep anywhere on the farm. Since the farmhouse (Stage 7)
		# the day ends at the bed; the key stays so it can say where that is.
		EventBus.message_posted.emit("To sleep, go to bed: E at the bed in the farmhouse")
	elif event.is_action_pressed(&"next_tool"):
		GameState.cycle_tool(1)
	elif event.is_action_pressed(&"prev_tool"):
		GameState.cycle_tool(-1)


## The cell under the player's feet.
func standing_cell() -> Vector2i:
	var probe := position + STANDING_PROBE
	return Vector2i(floori(probe.x / TILE_PX), floori(probe.y / TILE_PX))


## The cell the player is facing — the one tools act on.
func target_cell() -> Vector2i:
	return standing_cell() + FACING_VECTORS[_facing]


## Every cell the held tool would act on, at the tier the player owns. One
## cell (the one in front) for anything not upgraded.
func target_cells() -> Array[Vector2i]:
	var tool := GameState.selected_tool()
	if tool == null:
		return [target_cell()]
	return tool.cells_at(GameState.tool_tier(tool), target_cell(), FACING_VECTORS[_facing])


## Ask the tool which of its cells it can act on, pay once for the swing,
## then act on each. The player never needs to know *which* tool it's
## holding — see tool_action.gd.
##
## The swing costs the tier's energy, but never more than doing the same
## tiles one at a time with the basic tool would: a great hoe that only
## catches one tile of grass at the edge of a field costs what a plain hoe
## would. So an upgrade is never worse than what it replaced.
func _use_tool() -> void:
	var tool := GameState.selected_tool()
	var plot := GameState.plot_here()
	if tool == null or tool.action == null or plot == null or not GameState.tool_usable_here(tool):
		return
	var usable: Array[Vector2i] = []
	for cell in target_cells():
		if tool.action.can_use(plot, cell):
			usable.append(cell)
	if usable.is_empty():
		return
	var tier_cost := tool.energy_cost_at(GameState.tool_tier(tool))
	var cost := minf(tier_cost, tool.energy_cost * usable.size())
	# The difficulty makes every swing lighter or heavier (DECISIONS 040).
	cost *= GameState.difficulty.energy_cost_multiplier
	if not GameState.try_spend_energy(cost):
		return
	for cell in usable:
		# Seeds and sprinklers are used up as they're used. Removing the last
		# one takes it off the hotbar, and GameState moves the selection along.
		if tool.consumed_on_use and not GameState.inventory.remove(tool):
			break
		tool.action.apply(plot, cell)


## The same, away from the farm: the tool asks `tool_place` (the Woods)
## about each cell instead of the farm's tiles. Energy is paid the same way.
func _use_tool_away() -> void:
	var tool := GameState.selected_tool()
	if tool == null or tool.action == null or not tool.action.usable_in_season(GameState.season_id()):
		return
	var usable: Array[Vector2i] = []
	for cell in target_cells():
		if tool.action.can_use_away(tool_place, cell):
			usable.append(cell)
	if usable.is_empty():
		return
	var tier_cost := tool.energy_cost_at(GameState.tool_tier(tool))
	var cost := minf(tier_cost, tool.energy_cost * usable.size())
	cost *= GameState.difficulty.energy_cost_multiplier
	if not GameState.try_spend_energy(cost):
		return
	for cell in usable:
		if tool.consumed_on_use and not GameState.inventory.remove(tool):
			break
		tool.action.apply_away(tool_place, cell)


## E: harvest a ready crop by hand, pull up weeds (DECISIONS 045) or
## brambles and nettles (DECISIONS 060), or use
## whatever stands on the tile ahead (the shipping bin, a sprinkler to pick it
## up, a hive's honey to collect, a shopkeeper to talk to, the bed).
## Harvesting is free — the work was in growing it. Weeding costs a little
## energy.
##
## Anything usable joins the "interactable" group and offers occupies(cell)
## and interact(), so this never grows a list of things it knows about.
func _interact() -> void:
	var cell := target_cell()
	if can_farm and (GameState.harvest(cell) or GameState.pull_weeds(cell)
			or GameState.clear_by_hand(cell)):
		return
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.occupies(cell):
			node.interact()
			return


func _update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		_sprite.play("idle_%s" % _facing)
		return
	_facing = _facing_for(direction)
	_sprite.play("walk_%s" % _facing)


## Movement is eight-way but the art is four-way, so the larger axis wins.
## Horizontal is checked first, which makes diagonal movement read as
## left/right — the convention most top-down games use, because the side
## profiles are more distinctive than front and back.
func _facing_for(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"
