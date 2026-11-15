extends CanvasLayer
##
## DialogueBox — someone says something, in a box along the bottom of the
## screen, and the player presses E or Space to carry on.
##
## It's deliberately small: a speaker's name, a list of lines, and a
## `finished` signal for whoever asked. Quests in Stage 8 will use the same box.
##
## It can also ask a question with a few answers (ask(), DECISIONS 050): Rosa's
## three orders to choose between, or whether to take the board's job. W/S or
## the arrow keys move between the answers, E, Space or Enter picks one, Esc
## picks the last (always the "no thanks" one). It then announces `chosen`
## with the answer's position, and not `finished`.
## The game is paused while it's open, so the player can't wander off mid-sentence
## (this node keeps running while paused: process_mode ALWAYS in the scene).
##

signal finished

## The player picked answer `index` (counting from 0) to ask()'s question.
signal chosen(index: int)

const PANEL_WIDTH := 440  # width of the text inside, to wrap at

var _name_label: Label
var _text_label: Label
var _hint: Label
var _lines: Array[String] = []
var _index: int = 0

## While asking: the answers, one label each, and which is highlighted.
var _choice_list: VBoxContainer
var _choices: Array[String] = []
var _picked: int = 0


func _ready() -> void:
	_build()
	visible = false


## Show `lines` one after another, attributed to `speaker`.
func say(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_name_label.text = speaker
	visible = true
	get_tree().paused = true
	_show_line()


## Ask `question`, as `speaker`, with `answers` to pick from. Put the
## "no thanks" answer last: Esc picks it. Answer with the `chosen` signal.
func ask(speaker: String, question: String, answers: Array[String]) -> void:
	_lines = []
	_index = 0
	_choices = answers
	_picked = 0
	_name_label.text = speaker
	_text_label.text = question
	_text_label.visible = question != ""
	_hint.text = "W / S to choose, E to pick"
	_show_choices()
	visible = true
	get_tree().paused = true


func is_asking() -> bool:
	return visible and not _choices.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _choices.is_empty():
		_answer_input(event)
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool") \
			or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_index += 1
		if _index >= _lines.size():
			_close()
		else:
			_show_line()


## Keys while asking: move the highlight, or pick.
func _answer_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		step = -1
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		_picked = posmod(_picked + step, _choices.size())
		_show_choices()
		return
	var index := -1
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool") \
			or event.is_action_pressed(&"ui_accept"):
		index = _picked
	elif event.is_action_pressed(&"ui_cancel"):
		index = _choices.size() - 1
	if index < 0:
		return
	get_viewport().set_input_as_handled()
	_choices = []
	_show_choices()
	_text_label.visible = true
	visible = false
	get_tree().paused = false
	chosen.emit(index)


## Draw the answers, the highlighted one marked and coloured.
func _show_choices() -> void:
	for child in _choice_list.get_children():
		child.queue_free()
	_choice_list.visible = not _choices.is_empty()
	for i in _choices.size():
		var label := Label.new()
		label.text = ("> " if i == _picked else "   ") + _choices[i]
		UiStyle.style_label(label, 10, UiStyle.GOLD if i == _picked else UiStyle.TEXT)
		_choice_list.add_child(label)


func _show_line() -> void:
	_text_label.text = _lines[_index]
	_hint.text = "E / Space" if _index < _lines.size() - 1 else "E / Space to continue"


func _close() -> void:
	visible = false
	get_tree().paused = false
	finished.emit()


func _build() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.box(UiStyle.PANEL, UiStyle.PANEL_EDGE, 8))
	anchor.add_child(panel)
	# Along the bottom, inset 100px each side, above the hotbar.
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 100.0
	panel.offset_right = -100.0
	panel.offset_top = -90.0
	panel.offset_bottom = -30.0
	# With answers to choose from it grows upwards, keeping its bottom edge.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)

	_name_label = Label.new()
	UiStyle.style_label(_name_label, 10, UiStyle.GOLD)
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 30)
	UiStyle.style_label(_text_label, 10)
	column.add_child(_text_label)

	_choice_list = VBoxContainer.new()
	_choice_list.add_theme_constant_override(&"separation", 0)
	_choice_list.visible = false
	column.add_child(_choice_list)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_label(_hint, 8, UiStyle.TEXT_DIM)
	column.add_child(_hint)
