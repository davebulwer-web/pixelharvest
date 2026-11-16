class_name FishingLine
extends Node2D
##
## FishingLine — what a cast looks like (DECISIONS 054): the line from the
## rod's tip to the float, the float bobbing on the water (under it, with a
## "!", when something bites), rings spreading round it, and while a fish is
## on, the reel bar over the farmer's head.
##
## Only a look: Fishing (the autoload) decides everything and tells this
## node what to show. It's put in the current scene while the line is out
## and freed when it's reeled in. Drawn in code, like the tile cursor,
## except the float, which is a picture (assets/sprites/fishing/bobber.png)
## so Pixellab art can replace it.
##

const TILE_PX := 16
const BOBBER: Texture2D = preload("res://assets/sprites/fishing/bobber.png")

## Colours from art/palette.png, so it all stays on-palette.
const LINE_COLOUR := Color8(255, 231, 216, 170)
const RING_COLOUR := Color8(171, 220, 239, 160)
const BAR_FRAME := Color8(46, 31, 26)
const BAR_BACK := Color8(120, 88, 83)
const BAR_ZONE := Color8(111, 191, 74)
const BAR_MARKER := Color8(255, 231, 216)
const PIP_DONE := Color8(168, 224, 107)
const PIP_TO_DO := Color8(74, 55, 55)
const SLACK := Color8(196, 73, 76)
const ALERT := Color8(251, 160, 87)

## The reel bar's size and where it sits: above the farmer's hat, or under
## their feet when the line goes up the screen (the float is up there).
const BAR_SIZE := Vector2(48, 6)
const BAR_ABOVE := 46.0
const BAR_BELOW := 6.0

## How much further out the float lands when casting upwards (see setup).
const FAR_CAST_PX := 24.0

var _player: Node2D
var _float_at: Vector2
var _biting: bool = false
var _cast_up: bool = false
var _time: float = 0.0

var _bar_shown: bool = false
var _marker: float = 0.0
var _zone_start: float = 0.0
var _zone_width: float = 0.0
var _pulls: int = 0
var _pulls_needed: int = 1
var _slack: int = 0


## `player` is who's holding the rod; the float lands in the middle of `cell`.
func setup(player: Node2D, cell: Vector2i) -> void:
	_player = player
	_float_at = Vector2(cell * TILE_PX) + Vector2(TILE_PX / 2.0, TILE_PX / 2.0)
	# Casting upwards, the tile ahead is behind the farmer's head and hat, so
	# the float lands a little further out where it can be seen.
	if player != null and player.position.y > _float_at.y + TILE_PX / 2.0:
		_cast_up = true
		_float_at.y -= FAR_CAST_PX
	# Over the y-sorted world (people, trees), under the HUD.
	z_index = 20


func set_biting(biting: bool) -> void:
	_biting = biting
	queue_redraw()


func set_bar(marker: float, zone_start: float, zone_width: float, pulls: int, pulls_needed: int,
		slack: int) -> void:
	_bar_shown = true
	_marker = marker
	_zone_start = zone_start
	_zone_width = zone_width
	_pulls = pulls
	_pulls_needed = pulls_needed
	_slack = slack
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var tip := _rod_tip()
	# The float bobs gently while waiting, jerks under when something bites.
	var bob := sin(_time * 3.0) * 1.0
	if _biting:
		bob = 3.0 + sin(_time * 30.0) * 1.5
	var float_at := _float_at + Vector2(0, roundf(bob))
	# Rings spreading out from the float, one after another.
	for i in 2:
		var age := fposmod(_time * (1.6 if _biting else 0.7) + i * 0.5, 1.0)
		var colour := RING_COLOUR
		colour.a *= 1.0 - age
		draw_arc(_float_at + Vector2(0, 2), 2.0 + age * 7.0, 0.0, TAU, 16, colour, 1.0)
	# The line sags a little between the rod and the float.
	var points := PackedVector2Array()
	for step in 9:
		var t := step / 8.0
		var sag := sin(t * PI) * 4.0
		points.append(tip.lerp(float_at, t) + Vector2(0, sag))
	draw_polyline(points, LINE_COLOUR, 1.0)
	draw_texture(BOBBER, float_at - BOBBER.get_size() / 2.0)
	if _biting:
		_draw_alert(_float_at + Vector2(0, -12))
	if _bar_shown and _player != null:
		_draw_bar(_player.position + Vector2(-BAR_SIZE.x / 2.0, BAR_BELOW if _cast_up else -BAR_ABOVE))


## Where the rod's tip is: up from the farmer's hands, leaning towards the water.
func _rod_tip() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return _float_at
	var toward := (_float_at - _player.position).normalized()
	return _player.position + Vector2(0, -20) + toward * 9.0


## A "!" in pixels: a bar and a dot.
func _draw_alert(at: Vector2) -> void:
	var shake := Vector2(roundf(sin(_time * 40.0)), 0)
	draw_rect(Rect2(at + shake + Vector2(-2, -7), Vector2(4, 7)), BAR_FRAME)
	draw_rect(Rect2(at + shake + Vector2(-1, -6), Vector2(2, 5)), ALERT)
	draw_rect(Rect2(at + shake + Vector2(-2, 1), Vector2(4, 3)), BAR_FRAME)
	draw_rect(Rect2(at + shake + Vector2(-1, 2), Vector2(2, 1)), ALERT)


## The reel bar: a frame, the green zone, the marker, and under it a pip for
## each good pull needed (lit as they're made) and a red one per slack pull.
func _draw_bar(corner: Vector2) -> void:
	corner = corner.round()
	draw_rect(Rect2(corner - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), BAR_FRAME)
	draw_rect(Rect2(corner, BAR_SIZE), BAR_BACK)
	draw_rect(Rect2(corner + Vector2(roundf(_zone_start * BAR_SIZE.x), 0),
			Vector2(maxf(2.0, roundf(_zone_width * BAR_SIZE.x)), BAR_SIZE.y)), BAR_ZONE)
	var x := roundf(clampf(_marker, 0.0, 1.0) * (BAR_SIZE.x - 2))
	draw_rect(Rect2(corner + Vector2(x - 1, -2), Vector2(4, BAR_SIZE.y + 4)), BAR_FRAME)
	draw_rect(Rect2(corner + Vector2(x, -1), Vector2(2, BAR_SIZE.y + 2)), BAR_MARKER)
	var pip_y := corner.y + BAR_SIZE.y + 3
	var count := _pulls_needed + _slack
	var left := corner.x + BAR_SIZE.x / 2.0 - count * 2.0
	for i in count:
		var colour := SLACK if i >= _pulls_needed else (PIP_DONE if i < _pulls else PIP_TO_DO)
		draw_rect(Rect2(Vector2(left + i * 4, pip_y) - Vector2(0.0, 0.0), Vector2(3, 3)), BAR_FRAME)
		draw_rect(Rect2(Vector2(left + i * 4 + 0.0, pip_y), Vector2(2, 2)), colour)
