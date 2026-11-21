class_name MenuScreen
extends CanvasLayer
##
## MenuScreen — what the title screen and the Esc menu have in common
## (DECISIONS 086): a wooden panel in the middle of the screen over the
## paused game, a list of buttons, a line under them saying what the picked
## one does, and the pages both offer: Settings, Controls, and "are you sure?".
##
## TitleScreen and PauseMenu extend it and fill in the first page
## (_show_main) and what Esc does there (_on_escape_at_main). Both are made
## in code and added to the root like DifficultyMenu, so they outlive a
## change of scene and only exist while they're open.
##
## Keys: W/S or the arrows move between buttons, Space or Enter picks, A/D or
## left/right change a setting, Esc goes back a page. The mouse works too.
##

## How wide the panel is, in game pixels.
const PANEL_WIDTH := 300

## How long a setting's name is padded to, so the values line up (monogram
## is a monospaced font: every letter is the same width).
const NAME_WIDTH := 15

## The keys, for the Controls page: [keys, what they do]. Kept here rather than
## worked out from InputActions because the words for players aren't the
## action names (and the test switches aren't for players).
const CONTROLS: Array = [
	["W A S D / arrows", "walk"],
	["Space", "use what's in your hand"],
	["E", "talk, open, pick up, look"],
	["Q / Tab", "the tool before / after"],
	["J", "requests you've taken"],
	["L", "the almanac"],
	["M", "sound off / on"],
	["Esc", "this menu (back, in menus)"],
	["Ctrl+N", "new game"],
	["Ctrl+Y", "little animations off / on"],
]

## How dark the game behind is: 0 shows it as it is, 1 hides it.
var dim: float = 0.6

var _column: VBoxContainer
var _detail: Label
var _hint: Label
## The page showing now: the main page, or one under it that Esc leaves.
var _on_main: bool = true


func _ready() -> void:
	layer = 8  # over the HUD (2); under the day's summary (9) and DifficultyMenu (10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()
	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _on_main:
		_on_escape_at_main()
	else:
		Audio.play(&"menu")
		_show_main()


## Close the menu and let the game run again.
func close() -> void:
	get_viewport().gui_release_focus()
	get_tree().paused = false
	queue_free()


# --- For TitleScreen and PauseMenu to fill in ------------------------------------

## Build the first page (start with _page(), then _button() for each choice).
func _show_main() -> void:
	pass


## Esc on the first page.
func _on_escape_at_main() -> void:
	pass


## What sits above the panel (the title screen's name). Nothing by default.
func _build_top(_holder: VBoxContainer) -> void:
	pass


# --- The frame ---------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(UiStyle.OUTLINE, dim)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var holder := VBoxContainer.new()
	holder.add_theme_constant_override(&"separation", 6)
	centre.add_child(holder)
	_build_top(holder)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel(6))
	holder.add_child(panel)

	var inside := VBoxContainer.new()
	inside.add_theme_constant_override(&"separation", 4)
	panel.add_child(inside)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 1)
	inside.add_child(_column)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Three lines' room, so the panel doesn't jump as the line changes.
	_detail.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 48)
	UiStyle.style_panel_label(_detail, 8, UiStyle.TEXT_DIM)
	inside.add_child(_detail)

	_hint = Label.new()
	UiStyle.style_panel_label(_hint, 8, UiStyle.TEXT_DIM)
	inside.add_child(_hint)


## Empty the panel and start a page called `title`. `main` says whether it's
## the first page (where Esc is the screen's own business) or one under it.
func _page(title: String, main: bool = false) -> void:
	_on_main = main
	_column.add_theme_constant_override(&"separation", 1)
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_detail.text = ""
	_hint.text = "Space / Enter: choose" + ("" if main else "     Esc: back")
	if title != "":
		var heading := Label.new()
		heading.text = title
		UiStyle.style_panel_label(heading, 12)
		_column.add_child(heading)


## A button on the page that runs `action` when picked, and says `detail`
## under the list while it's picked or under the mouse.
func _button(text: String, detail: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiStyle.style_button(button)
	_on_picked(button, func() -> String: return detail)
	button.pressed.connect(func() -> void:
		Audio.play(&"menu")
		action.call())
	_column.add_child(button)
	return button


## Show `detail()` under the list when `button` is picked or under the mouse.
func _on_picked(button: Button, detail: Callable) -> void:
	button.focus_entered.connect(func() -> void: _detail.text = detail.call())
	# The mouse only changes the line, not the keyboard's place: a mouse left
	# resting over the panel would otherwise move it as the page opens.
	button.mouse_entered.connect(func() -> void: _detail.text = detail.call())


## Put the keyboard on the first button of the page.
func _focus_first() -> void:
	for child in _column.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


# --- Settings ----------------------------------------------------------------

func _show_settings() -> void:
	_page("Settings")
	_hint.text = "A / D or left / right: change     Esc: back"
	var window_note := "" if Settings.can_change_window() else \
			" (The game is running inside the editor, so this waits until it runs in a window of its own.)"
	_setting("Music",
			func() -> String: return _volume_text(Settings.music_volume),
			func(step: int) -> void: Settings.set_music_volume(Settings.music_volume + step),
			"How loud the season's tunes are. 0 turns them off.")
	_setting("Sounds",
			func() -> String: return _volume_text(Settings.sound_volume),
			func(step: int) -> void:
				Settings.set_sound_volume(Settings.sound_volume + step)
				Audio.play(&"menu"),  # so you hear how loud it is now
			"How loud everything else is: tools, doors, rain, the shop's till. 0 turns them off.")
	_setting("Screen",
			func() -> String: return "Full screen" if Settings.fullscreen else "Window",
			func(_step: int) -> void: Settings.set_fullscreen(not Settings.fullscreen),
			"Play in a window, or fill the whole screen." + window_note)
	_setting("Window size",
			func() -> String:
				if Settings.fullscreen:
					return "(full screen)"
				var base := 640 * Settings.window_scale
				return "x%d  (%d x %d)" % [Settings.window_scale, base, 360 * Settings.window_scale],
			func(step: int) -> void:
				if Settings.fullscreen:
					return
				var sizes := Settings.window_scales_that_fit()
				var at := maxi(0, sizes.find(Settings.window_scale))
				Settings.set_window_scale(sizes[wrapi(at + step, 0, sizes.size())]),
			"How big the window is, in whole steps of the game's picture. Only sizes that fit your screen are offered." + window_note)
	_setting("Pixels",
			func() -> String: return "Whole steps" if Settings.whole_pixels else "Fill the screen",
			func(_step: int) -> void: Settings.set_whole_pixels(not Settings.whole_pixels),
			"Fill the screen to its edges, or grow in whole steps so every pixel is the same size (with a dark border if the screen isn't an exact fit).")
	_setting("Animations",
			func() -> String: return "On" if Settings.ambience else "Off",
			func(_step: int) -> void: Settings.set_ambience(not Settings.ambience),
			"The little things that move by themselves: chimney smoke, lit windows, butterflies, birds, leaves, sparkles on the water. Only looks. Ctrl+Y also swaps them.")
	_button("Back", "Back to the menu. Settings are kept as you change them.", _show_main)
	_focus_first()


## One setting: a button that reads "Name    < value >". Left / right (or
## A / D) call `change` with -1 / +1; Space, Enter or a click with +1.
func _setting(name: String, value: Callable, change: Callable, detail: String) -> void:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiStyle.style_button(button)
	var redraw := func() -> void:
		button.text = "%s<  %s  >" % [name.rpad(NAME_WIDTH), value.call()]
	redraw.call()
	button.set_meta(&"refresh", redraw)
	_on_picked(button, func() -> String: return detail)
	button.pressed.connect(func() -> void:
		change.call(1)
		_refresh_settings())
	button.gui_input.connect(func(event: InputEvent) -> void:
		var step := 0
		if event.is_action_pressed(&"ui_left", true):
			step = -1
		elif event.is_action_pressed(&"ui_right", true):
			step = 1
		if step != 0:
			button.accept_event()
			change.call(step)
			_refresh_settings())
	_column.add_child(button)


## Some settings change what others show (full screen hides the window size).
func _refresh_settings() -> void:
	for child in _column.get_children():
		if child is Button and child.has_meta(&"refresh"):
			(child.get_meta(&"refresh") as Callable).call()


func _volume_text(steps: int) -> String:
	if steps <= 0:
		return "off"
	return "%3d%%" % (steps * 100 / Settings.VOLUME_STEPS)


# --- Controls ------------------------------------------------------------------

func _show_controls() -> void:
	_page("Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 0)
	for row: Array in CONTROLS:
		for i in 2:
			var label := Label.new()
			label.text = row[i]
			UiStyle.style_panel_label(label, 8, UiStyle.GOLD if i == 0 else UiStyle.TEXT)
			grid.add_child(label)
	_column.add_child(grid)
	_button("Back", "", _show_main)
	_focus_first()


# --- Are you sure? -------------------------------------------------------------

## A page asking `question`, with `yes` and "Back" (picked first, so a
## quick double press of Enter doesn't do the thing by mistake).
func _confirm(question: String, yes_text: String, yes: Callable) -> void:
	_page("")
	var label := Label.new()
	label.text = question
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PANEL_WIDTH - 24
	UiStyle.style_panel_label(label, 8)
	_column.add_child(label)
	var back := _button("Back", "", _show_main)
	_button(yes_text, "", yes)
	back.grab_focus()


# --- Leaving the game ---------------------------------------------------------

## Close the game the way the window's close button does, so Audio stops its
## sounds first (see Audio._notification).
func _quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
