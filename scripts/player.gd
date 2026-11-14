class_name Player
extends CharacterBody2D
##
## Player — movement, four-direction animation, and the player's actions:
## using the held tool, interacting (harvest, shipping bin), and going to sleep.
##
## The node origin sits at the character's FEET, not the centre of the sprite.
## The AnimatedSprite2D is offset upward to achieve that. This matters for two
## reasons: Y-sorting compares node positions, so the feet are the correct
## reference for "who is in front"; and the tile the player is standing on is
## simply the tile under the origin.
##
## Tools act on the tile *in front of* the player, not under them — you hoe
## the ground ahead of you, as in every game of this kind.
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


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	velocity = direction * SPEED
	move_and_slide()
	_update_animation(direction)


## Discrete presses (use, switch tool) are handled here rather than polled in
## _physics_process, so one key press is exactly one action.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use_tool"):
		_use_tool()
	elif event.is_action_pressed(&"interact"):
		_interact()
	elif event.is_action_pressed(&"sleep"):
		# No bed yet: sleep is a key press anywhere on the farm. When the
		# farmhouse exists this moves to interacting with the bed.
		TimeSystem.end_day()
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


## Ask the tool whether it can act, pay for it, then act. The player never
## needs to know *which* tool it's holding — see tool_action.gd.
func _use_tool() -> void:
	var tool := GameState.selected_tool()
	if tool == null:
		return
	var cell := target_cell()
	if not tool.action.can_use(GameState.farm, cell):
		return
	if not GameState.try_spend_energy(tool.energy_cost):
		return
	tool.action.apply(GameState.farm, cell)
	# Seeds are used up as they're planted. Removing the last one takes the
	# packet off the hotbar, and GameState moves the selection along.
	if tool.consumed_on_use:
		GameState.inventory.remove(tool)


## E: harvest a ready crop by hand, or use whatever stands on the tile ahead
## (the shipping bin now; doors and people in Stage 7). Harvesting is free —
## the work was in growing it.
##
## Anything usable joins the "interactable" group and offers occupies(cell)
## and interact(), so this never grows a list of things it knows about.
func _interact() -> void:
	var cell := target_cell()
	if GameState.harvest(cell):
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
