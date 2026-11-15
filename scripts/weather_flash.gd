class_name WeatherFlash
extends ColorRect
##
## WeatherFlash — lightning in a storm (DECISIONS 046): every so often the
## screen flashes white, once or twice, and a moment later the thunder rolls.
##
## Only a look and a sound, in the storm's overlay scene (scenes/weather/
## storm.tscn). It pauses with the game (a shop menu open, the day's
## summary), so a storm doesn't flash behind a menu.
##
## The thunder is asked for on EventBus (thunder_rolled), which Audio turns
## into the sound, rather than by calling Audio here: the storm scene is
## loaded with game_rules.tres (through the seasons and the weather), before
## the autoloads exist, so it mustn't name GameState or anything that does.
##
## The gaps are presentation timings, not balance numbers, so they live here
## as exports on the scene.
##

## Seconds between flashes, at random between these two.
@export var gap_min: float = 7.0
@export var gap_max: float = 18.0
## How bright the flash is at its peak (0 to 1).
@export var strength: float = 0.45

var _wait: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 0)
	_wait = randf_range(2.0, gap_max * 0.5)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(gap_min, gap_max)
	_strike()


## Flash (sometimes twice, the second fainter), then the thunder a moment
## later, as if the storm were a little way off.
func _strike() -> void:
	var tween := create_tween()
	tween.tween_property(self, ^"color:a", strength, 0.04)
	tween.tween_property(self, ^"color:a", 0.0, 0.18)
	if randf() < 0.5:
		tween.tween_property(self, ^"color:a", strength * 0.6, 0.04)
		tween.tween_property(self, ^"color:a", 0.0, 0.3)
	tween.tween_interval(randf_range(0.3, 1.2))
	tween.tween_callback(EventBus.thunder_rolled.emit)
