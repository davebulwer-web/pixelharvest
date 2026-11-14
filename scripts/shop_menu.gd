extends CanvasLayer
##
## ShopMenu — the shop, opened with B anywhere on the farm.
##
## Two columns: on the left, things to carry (seeds, sprinklers) — whatever
## ContentDB says has a buy_price; on the right, upgrades — whatever Economy
## says is on offer right now, one step of each line at a time (the great hoe
## appears once the wide hoe is bought). Stocking either is a data change.
## Buying goes through Economy; this file only draws the lists and passes on
## clicks and key presses.
##
## A stopgap until the town (Stage 7), where the seed shop and the blacksmith
## will open these same lists.
##
## While it's open the game is paused, so the player can't walk off or swing a
## hoe, and energy can't run out mid-purchase. This node keeps running while
## paused (process_mode ALWAYS, set in main.tscn).
##
## Keys: WASD or arrows to choose, Space or Enter to buy one, B or Esc to
## close. The mouse works too.
##

const PANEL_WIDTH := 520
const COLUMN_WIDTH := 250

var _goods: VBoxContainer
var _upgrades: VBoxContainer
var _gold_label: Label
var _detail: Label
var _note: Label

## Each button -> what it buys (an ItemDef or an UpgradeDef), so focus can be
## put back on the same thing after the lists are rebuilt.
var _buttons: Dictionary = {}


func _ready() -> void:
	_build()
	visible = false


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
	visible = true
	get_tree().paused = true
	_fill(null)


func close() -> void:
	# Let go of keyboard focus too, or the hidden button that had it would
	# still answer Space and Enter during play.
	get_viewport().gui_release_focus()
	visible = false
	get_tree().paused = false


func _buy_item(item: ItemDef) -> void:
	if Economy.buy(item):
		_fill(item)
	else:
		_show_note("Not enough gold for %s" % item.display_name, UiStyle.WARNING)


func _buy_upgrade(upgrade: UpgradeDef) -> void:
	if Economy.buy_upgrade(upgrade):
		_fill(upgrade)
		_show_note("Bought %s" % upgrade.display_name, UiStyle.GOLD)
	else:
		_show_note("Not enough gold for %s" % upgrade.display_name, UiStyle.WARNING)


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
	title.text = "Shop"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_label(title, 12)
	header.add_child(title)
	_gold_label = Label.new()
	UiStyle.style_label(_gold_label, 12, UiStyle.GOLD)
	header.add_child(_gold_label)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override(&"separation", 12)
	column.add_child(lists)
	_goods = _add_list(lists, "Seeds and supplies")
	_upgrades = _add_list(lists, "Upgrades")

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 24)
	UiStyle.style_label(_detail, 8)
	column.add_child(_detail)

	_note = Label.new()
	UiStyle.style_label(_note, 8, UiStyle.TEXT_DIM)
	column.add_child(_note)


## A headed column that buttons are added to.
func _add_list(parent: Container, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = COLUMN_WIDTH
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override(&"separation", 2)
	parent.add_child(box)
	var label := Label.new()
	label.text = heading
	UiStyle.style_label(label, 10, UiStyle.TEXT_DIM)
	box.add_child(label)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 2)
	box.add_child(rows)
	return rows


## Rebuild both lists from ContentDB and Economy, so new content and newly
## offered upgrades show up without anything here changing. Done on opening
## and after every purchase (buying an upgrade can bring on its successor).
## `keep_focus_on` is what was just bought: focus goes back to it, or to
## whatever has taken its place in the list.
func _fill(keep_focus_on: Resource) -> void:
	var focus_list: VBoxContainer = _goods
	var focus_index := 0
	for button: Button in _buttons:
		if _buttons[button] == keep_focus_on:
			focus_list = button.get_parent()
			focus_index = button.get_index()
	for list: VBoxContainer in [_goods, _upgrades]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	_buttons.clear()

	for item in ContentDB.shop_stock():
		var button := _add_button(_goods, item, item.icon, _item_text(item),
				Economy.buy_price(item), _item_detail(item))
		button.pressed.connect(_buy_item.bind(item))
	for upgrade in Economy.upgrades_on_offer():
		var price := Economy.upgrade_price(upgrade)
		var button := _add_button(_upgrades, upgrade, upgrade.icon,
				"%s   %dg" % [upgrade.display_name, price], price, upgrade.description)
		button.pressed.connect(_buy_upgrade.bind(upgrade))
	if _upgrades.get_child_count() == 0:
		var none := Label.new()
		none.text = "Nothing more for now"
		UiStyle.style_label(none, 10, UiStyle.TEXT_DIM)
		_upgrades.add_child(none)

	_gold_label.text = "%dg" % GameState.gold
	_show_note("Space / Enter: buy     B / Esc: close", UiStyle.TEXT_DIM)

	var target := _button_at(focus_list, focus_index)
	if target == null:
		target = _button_at(_goods, 0)
	if target != null:
		target.grab_focus()


func _button_at(list: VBoxContainer, index: int) -> Button:
	var buttons := list.get_children().filter(func(n: Node) -> bool: return n is Button)
	if buttons.is_empty():
		return null
	return buttons[clampi(index, 0, buttons.size() - 1)]


func _add_button(list: VBoxContainer, buys: Resource, icon: Texture2D, text: String,
		price: int, detail: String) -> Button:
	var button := Button.new()
	button.icon = icon
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override(&"font_size", 10)
	button.add_theme_color_override(&"font_color", UiStyle.TEXT)
	button.add_theme_color_override(&"font_focus_color", UiStyle.TEXT)
	button.add_theme_color_override(&"font_hover_color", UiStyle.TEXT)
	button.add_theme_stylebox_override(&"normal", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT, 3))
	button.add_theme_stylebox_override(&"hover", UiStyle.box(UiStyle.SLOT, UiStyle.SLOT_EDGE, 3))
	button.add_theme_stylebox_override(&"pressed", UiStyle.box(UiStyle.PANEL_EDGE, UiStyle.HIGHLIGHT, 3))
	button.add_theme_stylebox_override(&"focus", UiStyle.box(Color.TRANSPARENT, UiStyle.HIGHLIGHT, 3))
	# Dimmed when it can't be afforded; still pressable, to say why not.
	button.modulate = Color.WHITE if GameState.gold >= price else Color(1, 1, 1, 0.5)
	# The line under the lists explains whatever is focused or under the mouse.
	button.focus_entered.connect(_show_detail.bind(detail))
	button.mouse_entered.connect(_show_detail.bind(detail))
	list.add_child(button)
	_buttons[button] = buys
	return button


func _item_text(item: ItemDef) -> String:
	return "%s   %dg   (have %d)" % [
		item.display_name, Economy.buy_price(item), GameState.inventory.count(item)]


## What an item is for. Its own description if it has one; seeds otherwise
## describe their crop, so a new crop needs no words written for the shop.
func _item_detail(item: ItemDef) -> String:
	if item.description != "":
		return item.description
	if item is ToolDef and item.action is PlantAction and item.action.crop != null:
		var crop: CropDef = item.action.crop
		var text := "Ready in %d watered days" % crop.days_to_mature()
		if crop.regrow_days > 0:
			text += ", then again every %d" % crop.regrow_days
		if crop.produce != null:
			text += ".  Sells for %dg each." % Economy.sell_price(crop.produce)
		return text
	return ""


func _show_detail(text: String) -> void:
	_detail.text = text


func _show_note(text: String, colour: Color) -> void:
	_note.text = text
	_note.add_theme_color_override(&"font_color", colour)
