class_name FarmEffects
extends Node2D
##
## FarmEffects — the farm's "juice": little bursts of dirt, water and leaves,
## the harvest popping up out of the ground, a jolt of the camera
## (DECISIONS 042).
##
## Like the HUD and Audio, it only listens on EventBus, and it only draws:
## take this node out of main.tscn and the farm plays exactly the same.
##
## Particles are CPUParticles2D with no texture, so each one is a single
## pixel (or two) of a palette colour, which fits the pixel art. Every effect
## frees itself when it's done.
##
## Sits above the y-sorted Entities (z_index 1), so a puff is never hidden
## behind a crop.
##

const TILE_PX := 16

## Palette colours (art/palette.png), one pair per kind of burst: the shade
## a bit starts as, and the one it darkens to.
const DIRT := [Color8(200, 153, 123), Color8(74, 47, 34)]
const WATER := [Color8(247, 253, 255), Color8(79, 184, 172)]
const LEAF := [Color8(168, 224, 107), Color8(74, 127, 58)]
const DUST := [Color8(255, 231, 216), Color8(171, 129, 108)]

## Camera jolts, in world pixels and seconds. Presentation, not balance.
const HARVEST_SHAKE := [1.0, 0.12]
const COLLAPSE_SHAKE := [3.0, 0.4]


func _ready() -> void:
	z_index = 1
	EventBus.tile_tilled.connect(func(cell: Vector2i) -> void: _burst(cell, DIRT, 10, 70.0))
	EventBus.tile_watered.connect(func(cell: Vector2i) -> void: _burst(cell, WATER, 8, 55.0))
	EventBus.crop_planted.connect(func(cell: Vector2i, _id: StringName) -> void: _burst(cell, LEAF, 5, 40.0))
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.object_placed.connect(func(cell: Vector2i, _id: StringName) -> void: _puff(cell))
	EventBus.object_removed.connect(func(cell: Vector2i, _id: StringName) -> void: _puff(cell))
	EventBus.energy_exhausted.connect(func() -> void: _shake(COLLAPSE_SHAKE))


## Overnight (sprinklers watering, the season turning) nothing is shown:
## the player is asleep, and the scene may be about to close.
func _awake() -> bool:
	return not TimeSystem.is_ending_day()


## The middle of a cell, in the farm's coordinates.
func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_PX) + Vector2(TILE_PX, TILE_PX) / 2.0


## A handful of pixels thrown up from the middle of `cell`, falling back.
func _burst(cell: Vector2i, colours: Array, amount: int, speed: float) -> void:
	if not _awake():
		return
	var particles := _particles(colours, amount)
	particles.position = _centre(cell)
	particles.direction = Vector2.UP
	particles.spread = 50.0
	particles.initial_velocity_min = speed * 0.6
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 260)
	particles.lifetime = 0.55
	_fire(particles)


## Dust spreading out low along the ground: something put down or picked up.
func _puff(cell: Vector2i) -> void:
	if not _awake():
		return
	var particles := _particles(DUST, 10)
	particles.position = _centre(cell) + Vector2(0, 6)
	particles.direction = Vector2.UP
	particles.spread = 90.0
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 24.0
	particles.gravity = Vector2(0, 20)
	particles.damping_min = 20.0
	particles.damping_max = 30.0
	particles.lifetime = 0.5
	_fire(particles)


## The produce jumps up out of the ground and fades, with a shower of leaves
## and a small jolt of the camera. "+2" beside it if more than one came up.
func _on_crop_harvested(cell: Vector2i, crop_id: StringName, amount: int) -> void:
	if not _awake():
		return
	_burst(cell, LEAF, 10, 70.0)
	_shake(HARVEST_SHAKE)
	var crop := ContentDB.crop(crop_id)
	if crop == null or crop.produce == null or crop.produce.icon == null:
		return
	var pop := Node2D.new()
	pop.position = _centre(cell)
	add_child(pop)
	var icon := Sprite2D.new()
	icon.texture = crop.produce.icon
	pop.add_child(icon)
	if amount > 1:
		var count := Label.new()
		count.text = "+%d" % amount
		UiStyle.style_label(count, 8)
		count.position = Vector2(6, -8)
		pop.add_child(count)
	pop.scale = Vector2(0.5, 0.5)
	var tween := pop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, ^"position:y", pop.position.y - 18.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, ^"scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, ^"modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.chain().tween_callback(pop.queue_free)


func _particles(colours: Array, amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	# Light first, darker as they fall, fading out at the very end. The light
	# shade is what makes a puff of dirt show up against dirt.
	var ramp := Gradient.new()
	ramp.set_color(0, colours[0])
	ramp.set_color(1, Color(colours[1], 0.0))
	ramp.add_point(0.7, colours[1])
	particles.color_ramp = ramp
	return particles


## Start a one-shot burst and free it once its last particle has gone.
func _fire(particles: CPUParticles2D) -> void:
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _shake(shake: Array) -> void:
	ScreenShake.shake(get_viewport().get_camera_2d(), shake[0], shake[1])
