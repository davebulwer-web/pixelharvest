extends CanvasLayer
##
## ShopMenu — what a shopkeeper's counter offers, opened by talking to them.
##
## Which shop it is decides everything (ShopDef). Two columns, each shown only
## if the shop has anything for it: on the left, things to buy — seeds and
## supplies, then whichever upgrades this shop sells, one step of each line at a
## time (the great hoe appears once the wide hoe is bought); on the right, produce
## in the bag that the shop will buy for gold now. Stocking a shop is a data
## change. Buying and selling go through Economy; this file only draws the lists
## and passes on clicks and key presses.
##
## While it's open the game is paused, so energy can't run out mid-purchase.
## This node keeps running while paused (process_mode ALWAYS in the scene).
##
## Keys: WASD or arrows to choose, Space or Enter to buy or sell, Esc to leave.
## The mouse works too. Before Stage 7 this menu opened with B anywhere on the
## farm; now the shopkeeper opens it (DECISIONS 027).
##

const PANEL_WIDTH := 520
const COLUMN_WIDTH := 250

var _shop: ShopDef
var _title: Label
var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _goods: VBoxContainer
var _sells: VBoxContainer
var _gold_label: Label
var _detail: Label
var _note: Label

## Each button -> what it buys or sells (an ItemDef or an UpgradeDef), so focus
## can be put back on the same thing after the lists are rebuilt.
var _buttons: Dictionary = {}


func _ready() -> void:
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Open the counter of `shop`. Pauses the game until it's closed.
func open(shop: ShopDef) -> void:
	_shop = shop
	_title.text = shop.display_name
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


func _sell_item(item: ItemDef) -> void:
	var gold := Economy.sell_to_shop(item, _shop)
	if gold > 0:
		_fill(item)
		var note := "Sold for %dg" % gold
		if Economy.shop_flooded(item, _shop):
			note += ". %s has plenty of %s now" % [_shop.keeper_name, QuestGoal.plural(item.display_name, 2)]
		_show_note(note, UiStyle.GOLD)


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
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_label(_title, 12)
	header.add_child(_title)
	_gold_label = Label.new()
	UiStyle.style_label(_gold_label, 12, UiStyle.GOLD)
	header.add_child(_gold_label)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override(&"separation", 12)
	column.add_child(lists)
	_goods = _add_list(lists, "For sale")
	_buy_box = _goods.get_parent()
	_sells = _add_list(lists, "Sell your produce (paid now)")
	_sell_box = _sells.get_parent()

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
## and after every purchase or sale (buying an upgrade can bring on its
## successor; selling the last of something removes its row).
## `keep_focus_on` is what was just dealt in: focus goes back to it, or to
## whatever has taken its place in the list.
func _fill(keep_focus_on: Resource) -> void:
	var focus_list: VBoxContainer = _goods
	var focus_index := 0
	for button: Button in _buttons:
		if _buttons[button] == keep_focus_on:
			focus_list = button.get_parent()
			focus_index = button.get_index()
	for list: VBoxContainer in [_goods, _sells]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	_buttons.clear()

	for item in Economy.shop_stock(_shop):
		var button := _add_button(_goods, item, item.icon, _item_text(item),
				Economy.buy_price(item), _item_detail(item))
		button.pressed.connect(_buy_item.bind(item))
	for upgrade in Economy.upgrades_on_offer(_shop):
		var price := Economy.upgrade_price(upgrade)
		var button := _add_button(_goods, upgrade, upgrade.icon,
				"%s   %dg" % [upgrade.display_name, price], price, upgrade.description)
		button.pressed.connect(_buy_upgrade.bind(upgrade))
	# A stall that only buys (the market's grocer) shows just its buying list.
	_buy_box.visible = _goods.get_child_count() > 0 or not _shop.buys_produce
	if _goods.get_child_count() == 0:
		_add_none(_goods, "Nothing for sale right now")

	_sell_box.visible = _shop.buys_produce
	if _shop.buys_produce:
		for item in GameState.inventory.items():
			if not Economy.shop_buys(item, _shop):
				continue
			var amount := GameState.inventory.count(item)
			var total := Economy.store_total(item, _shop, amount)
			var each := Economy.store_price(item, _shop)
			var detail := "Sell all %d for %dg. The shipping bin on the farm pays full price, but only overnight." \
					% [amount, total]
			if is_equal_approx(_shop.produce_pay_rate, 1.0):
				# Tam (DECISIONS 065): the bin's price, but now.
				detail = "Sell all %d for %dg: what the shipping bin pays, but today." % [amount, total]
			elif _shop.produce_pay_rate > 1.0:
				detail = "Sell all %d for %dg, more than the shipping bin pays (%dg)." \
						% [amount, total, Economy.bin_pays(item, amount)]
			# Where to sell (DECISIONS 063): a buyer who has had plenty of
			# something today pays less for more, until the morning.
			var full := Economy.full_store_price(item, _shop)
			if Economy.shop_flooded(item, _shop):
				detail += " %s has had plenty of %s today: %dg each now, %dg again tomorrow." \
						% [_shop.keeper_name, QuestGoal.plural(item.display_name, 2), each, full]
			elif total < full * amount:
				detail += " Only so many fetch full price: %s pays less for each after %d today." \
						% [_shop.keeper_name, _shop.demand.full_price_count]
			var button := _add_button(_sells, item, item.icon,
					"%s x%d   %dg each" % [item.display_name, amount, each],
					0, detail)
			if Economy.shop_flooded(item, _shop):
				button.text += "  (plenty today)"
			button.pressed.connect(_sell_item.bind(item))
		if _sells.get_child_count() == 0:
			_add_none(_sells, "Nothing %s buys" % _shop.keeper_name if not _shop.buys_tags.is_empty() else "No produce to sell")

	_gold_label.text = "%dg" % GameState.gold
	_show_detail("")
	_show_note("Space / Enter: %s     Esc: leave" % ("buy or sell" if _shop.buys_produce else "buy"),
			UiStyle.TEXT_DIM)

	var target := _button_at(focus_list, focus_index)
	if target == null:
		target = _button_at(_goods, 0)
	if target == null:
		target = _button_at(_sells, 0)
	if target != null:
		target.grab_focus()


func _add_none(list: VBoxContainer, text: String) -> void:
	var none := Label.new()
	none.text = text
	UiStyle.style_label(none, 10, UiStyle.TEXT_DIM)
	list.add_child(none)


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
	var text := "%s   %dg   (have %d)" % [
		item.display_name, Economy.buy_price(item), GameState.inventory.count(item)]
	# Still for sale out of season — buying ahead is planning — but marked.
	if item is ToolDef and item.action != null \
			and not item.action.usable_in_season(GameState.season_id()):
		text += "   · off-season"
	return text


## What an item is for. Its own description if it has one; seeds otherwise
## describe their crop, so a new crop needs no words written for the shop.
func _item_detail(item: ItemDef) -> String:
	if item.description != "":
		return item.description
	if item is ToolDef and item.action is PlantAction and item.action.crop != null:
		var crop: CropDef = item.action.crop
		var text := "Grows all year.  " if crop.seasons.is_empty() \
				else "Grows in %s.  " % GameState.describe_seasons(crop.seasons).to_lower()
		if not crop.plant_seasons.is_empty():
			text += "Planted in %s.  " % GameState.describe_seasons(crop.plant_seasons).to_lower()
		if not crop.can_plant_in(GameState.season_id()):
			text += "Can't be planted in %s.  " % GameState.season_name(GameState.season_id()).to_lower()
		var grow_scale := GameState.difficulty.grow_time_multiplier
		text += "Ready in %d watered days" % crop.days_to_mature(grow_scale)
		if crop.regrow_days > 0:
			text += ", then again every %d" % crop.days_to_regrow(grow_scale)
		if crop.produce != null:
			text += ".  Sells for %dg each." % Economy.sell_price(crop.produce)
		var rules := crop.rules_text()
		if rules != "":
			text += "  " + rules
		return text
	return ""


func _show_detail(text: String) -> void:
	_detail.text = text


func _show_note(text: String, colour: Color) -> void:
	_note.text = text
	_note.add_theme_color_override(&"font_color", colour)
