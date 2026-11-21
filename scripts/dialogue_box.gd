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
## Portraits (Stage 24, DECISIONS 074): whoever asks can pass the speaker's
## portrait (CharacterDef.portrait, ShopDef.keeper_portrait), and it's shown in
## a wooden frame to the left of the box. A portrait picture is a strip of
## equal busts, one per mood, in the order of MOODS: neutral, happy, worried.
## The caller says which mood the conversation is in (a request handed in is
## happy); a single line can change it for itself by starting with a mood in
## square brackets, "[worried] The nets are torn again.", which is how a
## character's own lines in their .tres pick a face. The tag is never shown.
## No portrait (the notice board, the slate): no frame.
##
signal finished

## The player picked answer `index` (counting from 0) to ask()'s question.
signal chosen(index: int)

const PANEL_WIDTH := 440  # width of the text inside, to wrap at
const TEXT_HEIGHT := 34   # room for two lines, so the box doesn't jump between lines

## The moods a portrait strip holds, left to right.
const MOODS: Array[StringName] = [&"neutral", &"happy", &"worried"]

## The frame (assets/ui/portrait_frame.png) and the gap between it and the box.
const FRAME_SIZE := 84
const FRAME_GAP := 4
const PORTRAIT_FRAME: Texture2D = preload("res://assets/ui/portrait_frame.png")

var _name_label: Label
var _text_label: Label
var _hint: Label
var _lines: Array[String] = []
var _index: int = 0

## The speaker's portrait strip, and the mood the conversation is in.
var _portrait_strip: Texture2D = null
var _mood: StringName = &"neutral"
var _frame: Control
var _portrait: TextureRect
var _paper: ColorRect
var _border: NinePatchRect

## While asking: the answers, one label each, and which is highlighted.
var _choice_list: VBoxContainer
var _choices: Array[String] = []
var _picked: int = 0


func _ready() -> void:
	_build()
	visible = false
	add_to_group(&"pack_ui")  # TEST (DECISIONS 081)
	pack_ui_changed()


## TEST (DECISIONS 081): the Wood theme's portrait frame and paper, or ours.
func pack_ui_changed() -> void:
	var wood := PackLook.ui_texture("portrait_frame")
	_border.texture = wood if wood != null else PORTRAIT_FRAME
	var margin := PackLook.ui_margin("portrait_frame") if wood != null else 0
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_border.set_patch_margin(side, margin)
	_paper.color = PackLook.WOOD_PAPER if wood != null else UiStyle.PAPER


## Show `lines` one after another, attributed to `speaker`, with their
## `portrait` (a strip of moods; null for none) in `mood`.
func say(speaker: String, lines: Array[String], portrait: Texture2D = null,
		mood: StringName = &"neutral") -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_name_label.text = speaker
	_set_portrait(portrait, mood)
	_text_label.custom_minimum_size.y = TEXT_HEIGHT
	visible = true
	get_tree().paused = true
	_show_line()


## Ask `question`, as `speaker`, with `answers` to pick from. Put the
## "no thanks" answer last: Esc picks it. Answer with the `chosen` signal.
func ask(speaker: String, question: String, answers: Array[String],
		portrait: Texture2D = null, mood: StringName = &"neutral") -> void:
	_lines = []
	_index = 0
	_choices = answers
	_picked = 0
	_name_label.text = speaker
	_set_portrait(portrait, mood)
	_text_label.custom_minimum_size.y = 0  # no room kept for a second line
	_text_label.text = _strip_mood(question)
	_show_face(_mood_of(question))
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
		UiStyle.style_panel_label(label, 10, UiStyle.GOLD if i == _picked else UiStyle.TEXT)
		_choice_list.add_child(label)


func _show_line() -> void:
	var line := _lines[_index]
	_text_label.text = _strip_mood(line)
	_show_face(_mood_of(line))
	_hint.text = "E / Space" if _index < _lines.size() - 1 else "E / Space to continue"


## Remember the speaker's portrait and mood, and show or hide the frame.
func _set_portrait(portrait: Texture2D, mood: StringName) -> void:
	_portrait_strip = portrait
	_mood = mood if mood in MOODS else &"neutral"
	_frame.visible = portrait != null
	_show_face(&"")


## Show the face for `mood`, or the conversation's own with "".
func _show_face(mood: StringName) -> void:
	if _portrait_strip == null:
		_portrait.texture = null
		return
	if mood == &"":
		mood = _mood
	_portrait.texture = face(_portrait_strip, mood)


## One mood's bust cut from a portrait strip (MOODS, left to right). A strip
## with fewer busts than moods shows its first for any it lacks.
static func face(strip: Texture2D, mood: StringName) -> Texture2D:
	var height := strip.get_height()
	var count := maxi(1, strip.get_width() / maxi(1, height))
	var column := MOODS.find(mood)
	if column < 0 or column >= count:
		column = 0
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(column * height, 0, height, height)
	return atlas


## The mood a line asks for with a leading "[happy]", or "" for none.
static func _mood_of(line: String) -> StringName:
	if not line.begins_with("["):
		return &""
	var end := line.find("]")
	if end < 0:
		return &""
	var mood := StringName(line.substr(1, end - 1).strip_edges().to_lower())
	return mood if mood in MOODS else &""


## The line without its mood tag.
static func _strip_mood(line: String) -> String:
	if _mood_of(line) == &"":
		return line
	return line.substr(line.find("]") + 1).strip_edges()


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
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel(2))
	anchor.add_child(panel)
	# Along the bottom, inset 100px each side, above the hotbar.
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 100.0
	panel.offset_right = -100.0
	panel.offset_top = -98.0
	panel.offset_bottom = -30.0
	# With answers to choose from it grows upwards, keeping its bottom edge.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# The portrait: a frame in the left margin, its foot level with the box's,
	# the bust on the panel's paper inside it.
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_frame.offset_left = 100.0 - FRAME_GAP - FRAME_SIZE
	_frame.offset_right = 100.0 - FRAME_GAP
	_frame.offset_top = -30.0 - FRAME_SIZE
	_frame.offset_bottom = -30.0
	_frame.visible = false
	anchor.add_child(_frame)
	var inset := (FRAME_SIZE - 64) / 2.0
	_paper = ColorRect.new()
	_paper.color = UiStyle.PAPER
	_paper.position = Vector2(inset, inset)
	_paper.size = Vector2(64, 64)
	_frame.add_child(_paper)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(inset, inset)
	_portrait.size = Vector2(64, 64)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_frame.add_child(_portrait)
	# A nine-patch so the Wood frame (54px) can stretch to ours (DECISIONS 081).
	_border = NinePatchRect.new()
	_border.texture = PORTRAIT_FRAME
	_border.size = Vector2(FRAME_SIZE, FRAME_SIZE)
	_frame.add_child(_border)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	panel.add_child(column)

	_name_label = Label.new()
	UiStyle.style_panel_label(_name_label, 12, UiStyle.GOLD)
	column.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(PANEL_WIDTH - 16, TEXT_HEIGHT)
	UiStyle.style_panel_label(_text_label, 10)
	column.add_child(_text_label)

	_choice_list = VBoxContainer.new()
	_choice_list.add_theme_constant_override(&"separation", 0)
	_choice_list.visible = false
	column.add_child(_choice_list)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_panel_label(_hint, 8, UiStyle.TEXT_DIM)
	column.add_child(_hint)
