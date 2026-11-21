class_name AlmanacBook
extends Control
##
## AlmanacBook — the almanac on screen (DECISIONS 085): press L to open the
## book, L or Esc to close it. Part of the HUD, so it opens anywhere.
##
## Six pages of entries (Almanac.PAGES) and a seventh, Years, with the mayor's
## review of each year and this year so far. Q and Tab turn the page; the
## arrow keys (or WASD) pick an entry, and the box under the grid says what it
## is: how many and the biggest for one filled in, a hint (when and where) for
## one still greyed out.
##
## Like the request log it holds nothing: every time it's drawn it asks the
## Almanac service. Unlike the log it's a book, not a note in your pocket: the
## game is paused while it's open (so it keeps running itself: process_mode
## ALWAYS), and it won't open over anything else that has paused the game (a
## shop, the cook menu, a question).
##

const WIDTH := 470
const COLUMNS := 10
const SLOT := 34
const YEARS := &"years"

## Slot colours on the panel's paper, from the palette.
const SLOT_FILL := Color8(232, 194, 144)
const SLOT_PICKED := Color8(247, 214, 90)
## What a greyed-out entry's picture is multiplied by: a dark shape.
const UNKNOWN_TINT := Color(0.18, 0.12, 0.11, 0.55)

var _page: int = 0
## The picked entry on each page, by page index.
var _picked: Dictionary = {}

var _root: Control
var _tabs: HBoxContainer
var _count_label: Label
var _page_label: Label
var _grid: GridContainer
var _years: VBoxContainer
var _name_label: Label
var _detail_label: Label

## The page's entries as last drawn (Almanac.entries, or the years).
var _entries: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if _root.visible or get_tree().paused:
		return
	_root.visible = true
	get_tree().paused = true
	_redraw()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		if event.is_action_pressed(&"almanac"):
			get_viewport().set_input_as_handled()
			open()
		return
	# While it's open, every key is the book's.
	if not event.is_pressed() or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"almanac") or event.is_action_pressed(&"ui_cancel"):
		close()
	elif event.is_action_pressed(&"next_tool"):
		_turn(1)
	elif event.is_action_pressed(&"prev_tool"):
		_turn(-1)
	elif event.is_action_pressed(&"ui_right"):
		_move(1)
	elif event.is_action_pressed(&"ui_left"):
		_move(-1)
	elif event.is_action_pressed(&"ui_down"):
		_move(1 if _is_years() else COLUMNS)
	elif event.is_action_pressed(&"ui_up"):
		_move(-1 if _is_years() else -COLUMNS)


func _page_ids() -> Array[StringName]:
	var ids: Array[StringName] = Almanac.PAGES.duplicate()
	ids.append(YEARS)
	return ids


func _is_years() -> bool:
	return _page_ids()[_page] == YEARS


func _turn(step: int) -> void:
	_page = posmod(_page + step, _page_ids().size())
	_redraw()


func _move(step: int) -> void:
	if _entries.is_empty():
		return
	var at: int = _picked.get(_page, 0) + step
	if at < 0 or at >= _entries.size():
		return
	_picked[_page] = at
	_redraw()


# --- Drawing -----------------------------------------------------------------

func _redraw() -> void:
	var page: StringName = _page_ids()[_page]
	_count_label.text = "%d of %d filled in" % [Almanac.filled_all(), Almanac.total_all()]
	_draw_tabs()
	if page == YEARS:
		_entries = _year_entries()
	else:
		_entries = Almanac.entries(page)
	var picked: int = clampi(_picked.get(_page, 0), 0, maxi(0, _entries.size() - 1))
	_picked[_page] = picked
	_grid.visible = page != YEARS
	_years.visible = page == YEARS
	if page == YEARS:
		_page_label.text = "The mayor's book: every year so far"
		_draw_years(picked)
	else:
		var known := _entries.filter(func(e: Dictionary) -> bool: return e["known"]).size()
		_page_label.text = "%s: %d of %d" % [Almanac.PAGE_NAMES[page], known, _entries.size()]
		_draw_grid(picked)
	if _entries.is_empty():
		_name_label.text = ""
		_detail_label.text = ""
		return
	var entry: Dictionary = _entries[picked]
	_name_label.text = entry["name"] if entry["known"] else "???"
	_detail_label.text = entry["detail"]


func _draw_tabs() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	var ids := _page_ids()
	for i in ids.size():
		var tab := PanelContainer.new()
		var style: StyleBox
		if i == _page:
			style = UiStyle.box(SLOT_FILL, UiStyle.INK_DIM, 2)
		else:
			style = StyleBoxEmpty.new()
			style.set_content_margin_all(2)
		tab.add_theme_stylebox_override(&"panel", style)
		var label := Label.new()
		label.text = "Years" if ids[i] == YEARS else Almanac.PAGE_NAMES[ids[i]]
		UiStyle.style_panel_label(label, 10, UiStyle.TEXT if i == _page else UiStyle.TEXT_DIM)
		tab.add_child(label)
		_tabs.add_child(tab)


func _draw_grid(picked: int) -> void:
	for child in _grid.get_children():
		child.queue_free()
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		var style := UiStyle.box(SLOT_PICKED if i == picked else SLOT_FILL,
				UiStyle.INK_ACCENT if i == picked else UiStyle.INK_DIM, 1)
		if i == picked:
			style.set_border_width_all(2)
		slot.add_theme_stylebox_override(&"panel", style)
		var picture := TextureRect.new()
		picture.texture = entry["icon"]
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(SLOT - 4, SLOT - 4)
		if not entry["known"]:
			picture.modulate = UNKNOWN_TINT
		slot.add_child(picture)
		_grid.add_child(slot)


## The Years page: this year so far first, then each review, newest first.
func _year_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var now := GameState.year_stats
	var this_year := int(now.get("year", GameState.year))
	if Almanac.review_of(this_year).is_empty():
		result.append({"name": "Year %d, so far" % this_year, "known": true,
				"detail": " ".join(Almanac.stat_lines(now, "you"))})
	var reviews := GameState.year_reviews.duplicate()
	reviews.reverse()
	for review: Dictionary in reviews:
		var how := "" if review.get("heard", false) else "  (left as a note: you missed lantern night)"
		var title := str(review.get("title", ""))
		result.append({"name": "Year %d: %s" % [int(review["year"]), title] if title != "" else "Year %d" % int(review["year"]),
				"known": true, "detail": " ".join(Almanac.stat_lines(review.get("stats", {}), "you")) + how})
	return result


func _draw_years(picked: int) -> void:
	for child in _years.get_children():
		child.queue_free()
	for i in _entries.size():
		var label := Label.new()
		label.text = ("> " if i == picked else "  ") + str(_entries[i]["name"])
		UiStyle.style_panel_label(label, 10, UiStyle.GOLD if i == picked else UiStyle.TEXT)
		_years.add_child(label)
	if _entries.is_empty():
		var none := Label.new()
		none.text = "Nothing yet."
		UiStyle.style_panel_label(none, 10, UiStyle.TEXT_DIM)
		_years.add_child(none)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# A dimmer behind the book, so it's plain the game is paused.
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.OUTLINE, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel(6))
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	panel.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = "Almanac"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_panel_label(title, 12)
	top.add_child(title)
	_count_label = Label.new()
	UiStyle.style_panel_label(_count_label, 10, UiStyle.TEXT_DIM)
	top.add_child(_count_label)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 2)
	column.add_child(_tabs)

	_page_label = Label.new()
	UiStyle.style_panel_label(_page_label, 10, UiStyle.GOLD)
	column.add_child(_page_label)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 2)
	_grid.add_theme_constant_override(&"v_separation", 2)
	_grid.custom_minimum_size.y = 3 * SLOT + 4
	column.add_child(_grid)

	_years = VBoxContainer.new()
	_years.add_theme_constant_override(&"separation", 0)
	_years.custom_minimum_size.y = 3 * SLOT + 4
	column.add_child(_years)

	column.add_child(HSeparator.new())
	_name_label = Label.new()
	UiStyle.style_panel_label(_name_label, 12)
	column.add_child(_name_label)
	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(WIDTH - 24, 64)
	UiStyle.style_panel_label(_detail_label, 10, UiStyle.TEXT)
	column.add_child(_detail_label)

	var hint := Label.new()
	hint.text = "Arrows to look   Q / Tab to turn the page   L to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_panel_label(hint, 10, UiStyle.TEXT_DIM)
	column.add_child(hint)
