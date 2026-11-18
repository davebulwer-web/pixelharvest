class_name DartsGame
extends CanvasLayer
##
## DartsGame — your go at darts on darts night at the Wheatsheaf (DECISIONS
## 068): three darts, each aimed in two presses. The aim swings across the
## board from side to side; press to stop it, then it swings up and down;
## press again and the dart flies there. Each dart scores by the ring it
## lands in (TavernRules: the bull 50, then 25, 15, 10, 5, off the board
## nothing). Beat tonight's best and the pot is yours (Tavern.finish_darts).
##
## While it's open the game is paused, like the shop menu, so the clock
## doesn't run on while you aim; this node keeps running (process_mode
## ALWAYS). Esc before the first dart walks away without spending your go.
##
## The board is drawn here with circles, not a picture: its rings have to
## match the scoring exactly, and the rules say where they are.
##

## Said when the go is over, with what Nell and the bar say about it (empty
## if you walked away before throwing).
signal finished(lines: Array[String])

## The board's radius on screen, in pixels (the screen is 640 × 360).
const BOARD_RADIUS := 64.0

const RING_COLOURS: Array[Color] = [Color8(196, 73, 76), Color8(74, 127, 58), Color8(255, 231, 216),
		Color8(34, 34, 43), Color8(255, 231, 216)]
const DART_COLOUR := Color8(251, 160, 87)
const AIM_COLOUR := Color8(247, 253, 255)

enum Step { AIM_ACROSS, AIM_UP_DOWN, LANDED, DONE }

var _step: Step = Step.DONE
var _canvas: Control
var _label: Label
var _time: float = 0.0
var _aim := Vector2.ZERO  # as a share of the board's radius
var _darts: Array[Vector2] = []
var _scores: Array[int] = []
var _pause_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	visible = false
	_build()


## Start a go: three darts. Pauses the game until it's over.
func open() -> void:
	_darts.clear()
	_scores.clear()
	_aim = Vector2.ZERO
	_time = 0.0
	_step = Step.AIM_ACROSS
	visible = true
	get_tree().paused = true
	_say()


func _process(delta: float) -> void:
	if not visible:
		return
	var rules := Tavern.rules()
	_time += delta
	var swing := sin(_time * TAU * rules.aim_sweeps_per_second) * rules.aim_overshoot
	match _step:
		Step.AIM_ACROSS:
			_aim.x = swing
		Step.AIM_UP_DOWN:
			_aim.y = swing
		Step.LANDED:
			_pause_left -= delta
			if _pause_left <= 0.0:
				_next_dart()
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") and _darts.is_empty() and _step != Step.DONE:
		get_viewport().set_input_as_handled()
		_close([])
		return
	var pressed := event.is_action_pressed(&"use_tool") or event.is_action_pressed(&"interact") \
			or event.is_action_pressed(&"ui_accept")
	if not pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	match _step:
		Step.AIM_ACROSS:
			_step = Step.AIM_UP_DOWN
			_time = 0.0
		Step.AIM_UP_DOWN:
			_throw()
		Step.DONE:
			var lines := Tavern.finish_darts(_total())
			_close(lines)
	_say()


func _throw() -> void:
	_darts.append(_aim)
	_scores.append(Tavern.dart_score(_aim))
	_step = Step.LANDED
	_pause_left = 0.6


func _next_dart() -> void:
	if _darts.size() >= Tavern.rules().darts_per_go:
		_step = Step.DONE
	else:
		_step = Step.AIM_ACROSS
		_aim = Vector2.ZERO
		_time = 0.0
	_say()


func _total() -> int:
	var total := 0
	for score in _scores:
		total += score
	return total


func _close(lines: Array[String]) -> void:
	visible = false
	_step = Step.DONE
	get_tree().paused = false
	finished.emit(lines)


## The words under the board: whose score to beat, what to press, and the
## darts so far.
func _say() -> void:
	var best := Tavern.tonights_best()
	var thrown: Array[String] = []
	for score in _scores:
		thrown.append(str(score))
	var text := "To beat: %s's %d.   " % [best["who"], best["score"]]
	if not thrown.is_empty():
		text += "Your darts: %s = %d.   " % [" + ".join(thrown), _total()]
	match _step:
		Step.AIM_ACROSS:
			text += "Dart %d: Space to stop the aim across%s." % [_darts.size() + 1,
					", Esc to walk away" if _darts.is_empty() else ""]
		Step.AIM_UP_DOWN:
			text += "Now Space to stop it up and down, and throw."
		Step.LANDED:
			text += "%d!" % _scores[-1]
		Step.DONE:
			text += "Space to hear what the bar thinks."
	_label.text = text


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_board)
	add_child(_canvas)
	_label = Label.new()
	_label.position = Vector2(40, 300)
	_label.size = Vector2(560, 40)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_label, 10)
	add_child(_label)


func _centre() -> Vector2:
	return Vector2(320, 150)


func _draw_board() -> void:
	var rules := Tavern.rules()
	if rules == null:
		return
	var centre := _centre()
	# The cabinet behind, then the rings from the outside in.
	_canvas.draw_rect(Rect2(centre - Vector2(84, 84), Vector2(168, 168)), Color8(74, 47, 34))
	_canvas.draw_circle(centre, BOARD_RADIUS + 4, Color8(34, 34, 43))
	for i in range(rules.ring_radii.size() - 1, -1, -1):
		_canvas.draw_circle(centre, BOARD_RADIUS * rules.ring_radii[i], RING_COLOURS[i % RING_COLOURS.size()])
	for dart in _darts:
		var at := centre + dart * BOARD_RADIUS
		_canvas.draw_line(at, at + Vector2(6, -8), Color8(212, 231, 245), 2.0)
		_canvas.draw_circle(at, 2.5, DART_COLOUR)
	if _step == Step.AIM_ACROSS or _step == Step.AIM_UP_DOWN:
		var at := centre + _aim * BOARD_RADIUS
		var reach := BOARD_RADIUS * rules.aim_overshoot
		if _step == Step.AIM_ACROSS:
			_canvas.draw_line(Vector2(at.x, centre.y - reach), Vector2(at.x, centre.y + reach), Color(AIM_COLOUR, 0.5))
		else:
			_canvas.draw_line(Vector2(centre.x - reach, at.y), Vector2(centre.x + reach, at.y), Color(AIM_COLOUR, 0.5))
		_canvas.draw_arc(at, 5.0, 0.0, TAU, 16, AIM_COLOUR, 1.5)
		_canvas.draw_circle(at, 1.5, AIM_COLOUR)
