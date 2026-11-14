extends CanvasLayer
##
## ShopMenu — the seed shop, opened with B anywhere on the farm.
##
## A stopgap until the town (Stage 7), where a shopkeeper will open the same
## kind of list. It shows whatever ContentDB says is for sale (anything with a
## buy_price), so stocking it is a data change. Buying goes through Economy;
## this file only draws the list and passes on clicks and key presses.
##
## While it's open the game is paused, so the player can't walk off or swing a
## hoe, and energy can't run out mid-purchase. This node keeps running while
## paused (process_mode ALWAYS, set in main.tscn).
##
## Keys: W/S or arrows to choose, Space or Enter to buy one, B or Esc to close.
## The mouse works too.
##

const PANEL_WIDTH := 300

var _rows: VBoxContainer
var _gold_label: Label
var _note: Label
var _buttons: Dictionary = {}  # ItemDef -> Button
var _note_tween: Tween


func _ready() -> void:
	_build()
	visible = false
	EventBus.gold_changed.connect(func(_g: int, _d: int) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		# Only open from normal play — not over another pause.
		if event.is_action_pressed(&"open_shop") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"open_shop") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_fill()
	visible = true
	get_tree().paused = true
	var first: Button = _buttons.values().front() if not _buttons.is_empty() else null
	if first != null:
		first.grab_focus()


func close() -> void:
	# Let go of keyboard focus too, or the hidden button that had it would
	# still answer Space and Enter during play.
	get_viewport().gui_release_focus()
	visible = false
	get_tree().paused = false


func _buy(item: ItemDef) -> void:
	if Economy.buy(item):
		_refresh()
	else:
		_show_note("Not enough gold for %s" % item.display_name, UiStyle.WARNING)


# --- Building the panel ------------------------------------------------------

func _build() -> void:
	# A full-screen dimmer behind the panel, so it's obvious the game is paused.
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

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Seed shop"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_label(title, 12)
	header.add_child(title)
	_gold_label = Label.new()
	UiStyle.style_label(_gold_label, 12, UiStyle.GOLD)
	header.add_child(_gold_label)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	column.add_child(_rows)

	_note = Label.new()
	UiStyle.style_label(_note, 8, UiStyle.TEXT_DIM)
	column.add_child(_note)


## One button per item on sale. Rebuilt each time the shop opens, so new
## content shows up without anything here changing.
func _fill() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_buttons.clear()
	for item in ContentDB.shop_stock():
		var button := Button.new()
		button.icon = item.icon
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 10)
		button.add_theme_color_override(&"font_color", UiStyle.TEXT)
		button.add_theme_color_override(&"font_focus_color", UiStyle.TEXT)
		button.add_theme_color_override(&"font_hover_color", UiStyle.TEXT)
		button.add_theme_stylebox_override(&"normal", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT, 3))
		button.add_theme_stylebox_override(&"hover", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT_EDGE, 3))
		button.add_theme_stylebox_override(&"pressed", UiStyle.box(UiStyle.PANEL_EDGE, UiStyle.HIGHLIGHT, 3))
		button.add_theme_stylebox_override(&"focus", UiStyle.box(Color.TRANSPARENT, UiStyle.HIGHLIGHT, 3))
		button.pressed.connect(_buy.bind(item))
		_rows.add_child(button)
		_buttons[item] = button
	_show_note("Space / Enter: buy one     B / Esc: close", UiStyle.TEXT_DIM)
	_refresh()


## Update prices, counts and gold in place, without rebuilding the buttons
## (rebuilding would lose keyboard focus after every purchase).
func _refresh() -> void:
	if _gold_label == null:
		return
	_gold_label.text = "%dg" % GameState.gold
	for item: ItemDef in _buttons:
		var button: Button = _buttons[item]
		var price := Economy.buy_price(item)
		var detail := ""
		if item is ToolDef and item.action is PlantAction and item.action.crop != null:
			var crop: CropDef = item.action.crop
			detail = "  ·  %d days" % crop.days_to_mature()
			if crop.regrow_days > 0:
				detail += ", regrows every %d" % crop.regrow_days
			if crop.produce != null:
				detail += "  ·  sells %dg" % Economy.sell_price(crop.produce)
		button.text = "%s   %dg%s   (have %d)" % [
			item.display_name, price, detail, GameState.inventory.count(item)]
		button.modulate = Color.WHITE if GameState.gold >= price else Color(1, 1, 1, 0.5)


func _show_note(text: String, colour: Color) -> void:
	_note.text = text
	_note.add_theme_color_override(&"font_color", colour)
