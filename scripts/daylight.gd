class_name Daylight
extends CanvasModulate
##
## Daylight — tints an outdoor location by the time of day, so evening looks
## like evening and midnight like night (DECISIONS 036).
##
## A CanvasModulate multiplies the colour of everything drawn in the world
## (not the HUD, which is on its own CanvasLayer). White leaves the picture
## alone; orange warms it; dark blue makes it night. This node picks that
## colour from the clock, listening for time_changed, and fades to each new
## colour rather than jumping, because the clock moves in 10-minute steps.
##
## Only the outdoor places have one (scenes/daylight.tscn): the farm, the town
## and the Woods. Interiors don't, so the farmhouse and the shops stay lit at
## any hour, as rooms with lamps would be.
##
## Godot allows one CanvasModulate per scene, so the season's tint lives here
## too: the colour shown is the time's colour times SeasonTheme.light_tint
## (winter's slight chill) times today's WeatherDef.light_tint (rain's grey,
## a heatwave's warmth; DECISIONS 046). Before this, winter's tint was its own
## CanvasModulate in the snow overlay, which would have fought this one.
##
## Lamps: anything in the "night_lights" group is faded in as it gets dark
## and out by day, by its modulate alpha. The town's lamp posts have a "Glow"
## sprite in it: a soft warm circle drawn with additive blending, so it
## brightens what's under it. Its self_modulate (above 1, on purpose) is how
## strong it is at full night; the tint darkens it along with everything else,
## which is why it starts so bright. It sits at z_index 1: with additive
## blending at z 0, parts of the ground were drawn over it, cutting the glow
## off in straight lines. (Godot's PointLight2D was tried first and
## drew with hard edges in testing, so a plain sprite is used: it looks the
## same on every renderer.)
##

## The sky's colour through the day: minutes after midnight (as the clock and
## game_rules.tres count them, so 6 PM is 1080 and 1 AM is 1500) -> colour.
## Between two times the colour blends smoothly; before the first or after the
## last it holds. Edit these in the inspector on scenes/daylight.tscn.
@export var sky: Dictionary[int, Color] = {
	360: Color(1.0, 0.92, 0.85),
	480: Color(1, 1, 1),
}

## How long a change of colour takes to fade in, in real seconds.
@export var fade_seconds: float = 2.0

## Group name for lights that come on at night.
const NIGHT_LIGHTS := &"night_lights"

var _tween: Tween


func _ready() -> void:
	EventBus.time_changed.connect(func(_m: int) -> void: _apply(false))
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _apply(true))
	EventBus.season_changed.connect(func(_s: int) -> void: _apply(true))
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _apply(true))
	# Deferred: the location places its lamps in its own _ready, which runs
	# after this one (children are ready before their parent).
	_apply.call_deferred(true)


## Set the tint and the lamps for the current time: at once when a scene
## opens or a day starts, faded otherwise.
func _apply(at_once: bool) -> void:
	var target := tint_at(GameState.minutes) * _season_tint() * _weather_tint()
	var glow := lamp_level(tint_at(GameState.minutes))
	if _tween != null:
		_tween.kill()
	if at_once or fade_seconds <= 0.0:
		color = target
		for light in get_tree().get_nodes_in_group(NIGHT_LIGHTS):
			if light is CanvasItem:
				light.modulate.a = glow
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, ^"color", target, fade_seconds)
	for light in get_tree().get_nodes_in_group(NIGHT_LIGHTS):
		if light is CanvasItem:
			_tween.tween_property(light, ^"modulate:a", glow, fade_seconds)


## The sky's colour at `minutes`, blended between the two nearest times in
## `sky`. No season tint here.
func tint_at(minutes: int) -> Color:
	if sky.is_empty():
		return Color.WHITE
	var times: Array = sky.keys()
	times.sort()
	if minutes <= times[0]:
		return sky[times[0]]
	for i in range(1, times.size()):
		var later: int = times[i]
		if minutes <= later:
			var earlier: int = times[i - 1]
			var t := float(minutes - earlier) / float(later - earlier)
			return sky[earlier].lerp(sky[later], t)
	return sky[times[-1]]


## How brightly lamps burn under `tint`, 0 to 1: off in full daylight, full
## at the darkest colour in `sky`. Worked out from the colours, so moving
## dusk earlier or later in the inspector moves the lamps with it.
func lamp_level(tint: Color) -> float:
	var darkest := 1.0
	for c: Color in sky.values():
		darkest = minf(darkest, _brightness(c))
	if darkest >= 0.999:
		return 0.0
	var darkness := (1.0 - _brightness(tint)) / (1.0 - darkest)
	# Start a little after the light begins to go, so lamps don't glow
	# faintly through a golden afternoon.
	return smoothstep(0.15, 0.9, darkness)


func _brightness(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0


func _season_tint() -> Color:
	var theme := GameState.current_season_theme()
	return theme.light_tint if theme != null else Color.WHITE


func _weather_tint() -> Color:
	return GameState.weather.light_tint if GameState.weather != null else Color.WHITE
