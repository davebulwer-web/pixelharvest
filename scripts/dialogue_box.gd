extends CanvasLayer
##
## DialogueBox — someone says something, in a box along the bottom of the
## screen, and the player presses E or Space to carry on.
##
## It's deliberately small: a speaker's name, a list of lines, and a
## `finished` signal for whoever asked. Quests in Stage 8 will use the same box.
## The game is paused while it's open, so the player can't wander off mid-sentence
## (this node keeps running while paused: process_mode ALWAYS in the scene).
##

signal finished

const PANEL_WIDTH := 440  # width of the text inside, to wrap at

var _name_label: Label
var _text_label: Label
var _hint: Label
var _lines: Array[String] = []
var _index: int = 0


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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool") \
			or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_index += 1
		if _index >= _lines.size():
			_close()
		else:
			_show_line()


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

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_label(_hint, 8, UiStyle.TEXT_DIM)
	column.add_child(_hint)
