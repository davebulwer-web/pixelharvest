class_name CookMenu
extends CanvasLayer
##
## CookMenu — the stove's menu (DECISIONS 056): every recipe the farmer knows,
## what goes in and what's in the bag, and what each dish gives back.
## Choose one and it's cooked, once per press.
##
## It looks and works like the shop's counter (ShopMenu): the game is paused
## while it's open, WASD or arrows to choose, Space or Enter to cook, Esc to
## leave. A recipe short of something stays in the list, dimmed; choosing it
## says what's missing. The cooking itself is GameState.cook(); this only
## draws the list and passes on presses.
##
## The farmhouse builds it in code (no scene of its own), and it keeps running
## while the game is paused (process_mode ALWAYS).
##

const PANEL_WIDTH := 520

## Recipes are listed in two columns, so a long list still fits the screen.
const COLUMNS := 2

var _list: GridContainer
var _detail: Label
var _note: Label

## Each button -> its RecipeDef, so focus can go back to the same recipe after
## the list is rebuilt.
var _buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Open the menu. Pauses the game until it's closed.
func open() -> void:
	visible = true
	get_tree().paused = true
	_fill(null)


func close() -> void:
	# Let go of focus, or the hidden button would still answer Space.
	get_viewport().gui_release_focus()
	visible = false
	get_tree().paused = false


func _cook(recipe: RecipeDef) -> void:
	if GameState.cook(recipe):
		_fill(recipe)
		_show_note("Cooked %s. It's on your hotbar: Space to eat" % recipe.display_name().to_lower(), UiStyle.GOLD)
	else:
		_show_note("Still need %s" % recipe.missing(GameState.inventory), UiStyle.WARNING)


# --- Building the panel ------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.OUTLINE, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.add_theme_stylebox_override(&"panel", UiStyle.box(UiStyle.PANEL, UiStyle.PANEL_EDGE, 8))
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)

	var title := Label.new()
	title.text = "The stove"
	UiStyle.style_label(title, 12)
	column.add_child(title)

	var heading := Label.new()
	heading.text = "Recipes you know"
	UiStyle.style_label(heading, 10, UiStyle.TEXT_DIM)
	column.add_child(heading)

	_list = GridContainer.new()
	_list.columns = COLUMNS
	_list.add_theme_constant_override(&"h_separation", 4)
	_list.add_theme_constant_override(&"v_separation", 2)
	column.add_child(_list)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 24)
	UiStyle.style_label(_detail, 8)
	column.add_child(_detail)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = PANEL_WIDTH - 16
	UiStyle.style_label(_note, 8, UiStyle.TEXT_DIM)
	column.add_child(_note)


## Rebuild the list from what's known and what's in the bag. Done on opening
## and after each dish cooked (the counts change). Focus goes back to
## `keep_focus_on`, or the first recipe.
func _fill(keep_focus_on: RecipeDef) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()

	var bag := GameState.inventory
	var focus: Button = null
	for recipe in GameState.known_recipes():
		var dish := recipe.dish
		var energy := roundi((dish.action as EatAction).energy) if dish.action is EatAction else 0
		var text := "%s   +%d" % [recipe.display_name(), energy]
		var detail := "%s: +%d energy, you have %d. Needs %s." % [recipe.display_name(), energy,
				bag.count(dish), recipe.ingredients_text(bag)]
		if recipe.makes > 1:
			detail += " Makes %d." % recipe.makes
		var button := _add_button(dish.icon, text, detail, recipe.can_cook(bag))
		button.pressed.connect(_cook.bind(recipe))
		_buttons[button] = recipe
		if focus == null or recipe == keep_focus_on:
			focus = button
	if _buttons.is_empty():
		var none := Label.new()
		none.text = "No recipes yet"
		UiStyle.style_label(none, 10, UiStyle.TEXT_DIM)
		_list.add_child(none)
	_show_detail("")
	_show_note("Space / Enter: cook one     Esc: leave", UiStyle.TEXT_DIM)
	if focus != null:
		focus.grab_focus()


func _add_button(icon: Texture2D, text: String, detail: String, can_cook: bool) -> Button:
	var button := Button.new()
	button.icon = icon
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.x = (PANEL_WIDTH - 20) / COLUMNS
	button.clip_text = true
	button.add_theme_font_size_override(&"font_size", 10)
	button.add_theme_color_override(&"font_color", UiStyle.TEXT)
	button.add_theme_color_override(&"font_focus_color", UiStyle.TEXT)
	button.add_theme_color_override(&"font_hover_color", UiStyle.TEXT)
	button.add_theme_stylebox_override(&"normal", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT, 3))
	button.add_theme_stylebox_override(&"hover", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT_EDGE, 3))
	button.add_theme_stylebox_override(&"pressed", UiStyle.box(UiStyle.PANEL_EDGE, UiStyle.HIGHLIGHT, 3))
	button.add_theme_stylebox_override(&"focus", UiStyle.box(Color.TRANSPARENT, UiStyle.HIGHLIGHT, 3))
	# Dimmed when something's missing; still pressable, to say what.
	button.modulate = Color.WHITE if can_cook else Color(1, 1, 1, 0.5)
	button.focus_entered.connect(_show_detail.bind(detail))
	button.mouse_entered.connect(_show_detail.bind(detail))
	_list.add_child(button)
	return button


func _show_detail(text: String) -> void:
	_detail.text = text


func _show_note(text: String, colour: Color) -> void:
	_note.text = text
	_note.add_theme_color_override(&"font_color", colour)
