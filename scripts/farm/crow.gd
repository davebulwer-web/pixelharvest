class_name Crow
extends Node2D
##
## Crow — the crow standing where it took a crop last night (DECISIONS 045).
##
## Only a picture: by the time it's seen, the crop is already gone
## (FarmHazards did that overnight, in the data). It's there so the loss is
## seen on the farm and not only read in the morning's summary. It pecks at
## the ground until the player comes near, then flies off and is gone for
## good: it tells FarmData it's left, so walking back from town doesn't bring
## it back.
##
## The farm scene makes one for each cell in FarmData.crows_landed.
##

const TEXTURE: Texture2D = preload("res://assets/sprites/farm/crow.png")

## Frame 0 standing, frame 1 wings up.
const FRAMES := 2

## How close the player can come, in pixels, before it takes off.
const SCARE_DISTANCE := 40.0

## Seconds between pecks while it waits.
const PECK_SECONDS := 0.6

## Which way it flies off, in pixels, and how long it takes.
const FLIGHT := Vector2(90, -110)
const FLIGHT_SECONDS := 1.4

var cell: Vector2i
var _watching: Node2D
var _sprite: Sprite2D
var _peck_timer: float = 0.0
var _flying: bool = false


## A crow on `at_cell`, standing at `base` (the cell's bottom middle), keeping
## an eye on `watching` (the player).
static func create(at_cell: Vector2i, base: Vector2, watching: Node2D) -> Crow:
	var crow := Crow.new()
	crow.cell = at_cell
	crow.position = base
	crow._watching = watching
	return crow


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.hframes = FRAMES
	_sprite.offset = Vector2(0, -TEXTURE.get_height() / 2.0)
	add_child(_sprite)
	_peck_timer = randf() * PECK_SECONDS  # so two crows don't peck in step


func _process(delta: float) -> void:
	if _flying:
		return
	if is_instance_valid(_watching) and _watching.position.distance_to(position) < SCARE_DISTANCE:
		fly_off()
		return
	# Peck: dip the head (a pixel down) now and then.
	_peck_timer -= delta
	if _peck_timer <= 0.0:
		_peck_timer = PECK_SECONDS
		_sprite.position.y = 1.0 if _sprite.position.y == 0.0 else 0.0


## Off it goes, away from the player, and it won't be back today.
func fly_off() -> void:
	if _flying:
		return
	_flying = true
	GameState.farm.crows_landed.erase(cell)
	_sprite.frame = 1
	_sprite.position.y = 0.0
	# Flap: flick between the two frames as it climbs.
	var flap := create_tween().set_loops(8)
	flap.tween_callback(func() -> void: _sprite.frame = 1 - _sprite.frame).set_delay(0.08)
	var away := FLIGHT
	# Fly away from the player, not over them. The picture faces left.
	if is_instance_valid(_watching) and _watching.position.x > position.x:
		away.x = -away.x
	else:
		_sprite.flip_h = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"position", position + away, FLIGHT_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_property(self, ^"modulate:a", 0.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
