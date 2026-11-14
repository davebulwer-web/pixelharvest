extends CharacterBody2D
##
## Player — movement and four-direction animation.
##
## The node origin sits at the character's FEET, not the centre of the sprite.
## The AnimatedSprite2D is offset upward by half a cell to achieve that. This
## matters for two reasons: Y-sorting compares node positions, so the feet are
## the correct reference for "who is in front"; and in Stage 2 the tile the
## player is standing on is simply the tile under the origin.
##

## Pixels per second. At 16px tiles this is roughly 4.4 tiles a second.
const SPEED := 70.0

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
