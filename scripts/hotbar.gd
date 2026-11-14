extends Control
##
## Hotbar — the strip along the bottom of the screen showing what's in the bag.
##
## Left: the hotbar proper — tools and seeds, the things Tab and Q move
## between — with the selected one outlined and named above. Right, after a
## gap: everything else carried (produce), with counts. That's the whole
## inventory on screen at once, so there's no separate bag window yet.
##
## It's drawn in code rather than built from nodes: it's a row of boxes that
## changes whenever the bag does, and redrawing it from GameState each time is
## simpler than keeping a set of nodes in step.
##
## Like the rest of the HUD it only reads GameState and listens on EventBus;
## nothing tells it to update.
##

const SLOT_PX := 18
const GAP := 2
const GROUP_GAP := 10
const BOTTOM_MARGIN := 6


func _ready() -> void:
	EventBus.item_added.connect(func(_id: StringName, _n: int) -> void: queue_redraw())
	EventBus.item_removed.connect(func(_id: StringName, _n: int) -> void: queue_redraw())
	EventBus.tool_selected.connect(func(_id: StringName) -> void: queue_redraw())
	EventBus.tool_upgraded.connect(func(_id: StringName, _tier: int) -> void: queue_redraw())
	EventBus.game_loaded.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var tools := GameState.hotbar()
	var others: Array[ItemDef] = []
	for item in GameState.inventory.items():
		if not item is ToolDef:
			others.append(item)
	var selected := GameState.selected_tool()

	var slots := tools.size() + others.size()
	var width := slots * (SLOT_PX + GAP) - GAP + (GROUP_GAP if not others.is_empty() else 0)
	var x := roundf((size.x - width) / 2.0)
	var y := size.y - SLOT_PX - BOTTOM_MARGIN

	for tool_def in tools:
		var is_selected := tool_def == selected
		_draw_slot(Vector2(x, y), tool_def, is_selected, tool_def.consumed_on_use)
		if is_selected:
			_draw_name(GameState.tool_name(tool_def), Vector2(x + SLOT_PX / 2.0, y - 4))
		x += SLOT_PX + GAP
	x += GROUP_GAP
	for item in others:
		_draw_slot(Vector2(x, y), item, false, true)
		x += SLOT_PX + GAP


func _draw_slot(at: Vector2, item: ItemDef, is_selected: bool, show_count: bool) -> void:
	var rect := Rect2(at, Vector2(SLOT_PX, SLOT_PX))
	draw_rect(rect, UiStyle.SLOT)
	draw_rect(rect.grow(-0.5), UiStyle.HIGHLIGHT if is_selected else UiStyle.SLOT_EDGE, false, 1.0)
	if item.icon != null:
		draw_texture(item.icon, at + Vector2(1, 1))
	if show_count:
		var text := str(GameState.inventory.count(item))
		var font := get_theme_default_font()
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var pos := at + Vector2(SLOT_PX - text_size.x, SLOT_PX + 1)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, UiStyle.OUTLINE)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.TEXT)


## The selected item's name, centred above its slot but kept on screen.
func _draw_name(text: String, centre: Vector2) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var left := clampf(centre.x - text_size.x / 2.0, 2.0, size.x - text_size.x - 2.0)
	var pos := Vector2(roundf(left), centre.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, UiStyle.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.TEXT)
