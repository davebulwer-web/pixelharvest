class_name ScreenShake
extends RefCounted
##
## ScreenShake — a short jolt of the camera, for a thump the player should
## feel: a harvest, collapsing from tiredness (DECISIONS 042).
##
## It moves the camera's `offset`, not its position, so the camera's
## following and smoothing are untouched, and it always ends back at zero.
## Offsets are whole pixels: the game is pixel-snapped, and half a pixel of
## shake only blurs.
##

## How many jolts a second. Fast enough to read as a shake, not a wobble.
const STEPS_PER_SECOND := 30.0


## Shake `camera` by up to `pixels` world pixels for `seconds`, easing off.
## Asking again while it's shaking restarts it.
static func shake(camera: Camera2D, pixels: float, seconds: float) -> void:
	if camera == null or pixels <= 0.0:
		return
	if camera.has_meta(&"shake_tween"):
		var old: Tween = camera.get_meta(&"shake_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween := camera.create_tween()
	var steps := maxi(2, roundi(seconds * STEPS_PER_SECOND))
	for step in steps:
		var strength := pixels * (1.0 - float(step) / steps)
		var jolt := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)).round()
		tween.tween_property(camera, ^"offset", jolt, 1.0 / STEPS_PER_SECOND)
	tween.tween_property(camera, ^"offset", Vector2.ZERO, 1.0 / STEPS_PER_SECOND)
	camera.set_meta(&"shake_tween", tween)
