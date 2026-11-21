class_name DifficultyMenu
extends CanvasLayer
##
## DifficultyMenu — "How would you like to play?", asked once when a new game
## starts (DECISIONS 040).
##
## It lists the difficulties in game_rules.tres, in order, starting on the
## default one, and says in words what each changes. It only reports the
## choice (the `chosen` signal); whoever opened it starts the game. So the
## boot scene (first launch, no save) and Ctrl+N (SaveSystem) share it.
##
## Made in code and added wherever it's needed, like a dialog, rather than
## placed in every scene: it only exists while it's being asked.
##
## The game is paused while it's open; this node keeps running while paused.
##
## Keys: W/S or arrows to choose, Space or Enter to start, Esc to go back
## (only from Ctrl+N: at first launch there's no game to go back to).
## The title screen's and the Esc menu's "New game" open it too (DECISIONS 086).
##

signal chosen(difficulty: DifficultyDef)

const PANEL_WIDTH := 360

## True when there's somewhere to go back to (Ctrl+N, the title screen), so
## Esc closes the menu.
var can_cancel: bool = false
## What the hint says Esc goes back to.
var cancel_words: String = "back to your game"

var _detail: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 10  # above the HUD (2) and the shop and dialogue boxes
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if can_cancel and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _choose(difficulty: DifficultyDef) -> void:
	_close()
	chosen.emit(difficulty)


func _close() -> void:
	get_viewport().gui_release_focus()
	get_tree().paused = false
	queue_free()


# --- Building the panel ------------------------------------------------------

func _build() -> void:
	# Over a running game, dim it so it's clear it's paused; at first launch
	# there's nothing behind, so a solid background.
	var back := ColorRect.new()
	back.color = Color(UiStyle.OUTLINE, 0.6) if can_cancel else UiStyle.OUTLINE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel(8))
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)

	var title := Label.new()
	title.text = "New game: how would you like to play?"
	UiStyle.style_panel_label(title, 12)
	column.add_child(title)

	var rules: GameRules = GameState.RULES
	var choices: Array[DifficultyDef] = rules.difficulties.duplicate()
	if choices.is_empty():
		choices.append(rules.standard_difficulty())
	var default_id := rules.standard_difficulty().id
	var focus_on: Button = null
	for difficulty in choices:
		var button := _add_button(column, difficulty, rules.starting_gold)
		if difficulty.id == default_id:
			focus_on = button

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 70)
	UiStyle.style_panel_label(_detail, 8)
	column.add_child(_detail)

	var hint := Label.new()
	hint.text = "Space / Enter: start" + ("     Esc: " + cancel_words if can_cancel else "")
	UiStyle.style_panel_label(hint, 8, UiStyle.TEXT_DIM)
	column.add_child(hint)

	if focus_on == null:
		focus_on = _buttons[0]
	focus_on.grab_focus()


func _add_button(list: VBoxContainer, difficulty: DifficultyDef, base_gold: int) -> Button:
	var button := Button.new()
	button.text = difficulty.display_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The theme's button: plain ink on the panel, the wooden button when picked.
	UiStyle.style_button(button)
	# The line under the list explains whichever is focused or under the mouse.
	var detail := difficulty.description
	var changes := difficulty.summary(base_gold)
	if not detail.is_empty():
		detail += "\n"
	detail += ".  ".join(changes) + "."
	button.focus_entered.connect(func() -> void: _detail.text = detail)
	button.mouse_entered.connect(func() -> void: _detail.text = detail)
	button.pressed.connect(_choose.bind(difficulty))
	list.add_child(button)
	_buttons.append(button)
	return button
