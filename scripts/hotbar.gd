extends Control
##
## Hotbar — the strip along the bottom of the screen showing what's in the bag.
##
## Left: the hotbar proper — tools and seeds, the things Tab and Q move
## between — with the selected one outlined and named above. Right, after a
## gap: everything else carried (produce), with counts. That's the whole
## inventory on screen at once, so there's no separate bag window yet.
##
## Size (DECISIONS 089). Slots are drawn at a whole-number size: ×2 (each
## 16 px picture drawn 32 px, in a 36 px box) unless Settings → Toolbar says
## small (the old ×1). Whole numbers keep every picture's pixels square. The
## screen is always 640 × 360 game pixels whatever the window size (the
## window only magnifies it), so this layout is the same at every size:
##   - everything fits on one row: one row, centred, as before;
##   - it doesn't: the tools keep the bottom row and the rest of the bag
##     moves to a row of its own just above them;
##   - a row that still doesn't fit: the tools show a window of slots around
##     the selected one, with "<3" / "5>" saying how many are off each side;
##     the rest of the bag drops to small slots, and past that shows "+n".
## While someone's talking (DialogueBox, in the group "covers_hotbar") the
## strip is hidden: the box sits where the strip's top row would be.
##
## It's drawn in code rather than built from nodes: it's a row of boxes that
## changes whenever the bag does, and redrawing it from GameState each time is
## simpler than keeping a set of nodes in step.
##
## Like the rest of the HUD it only reads GameState and listens on EventBus;
## nothing tells it to update.
##

## A slot's size at ×1, the picture inside it, and the gaps. Everything is
## multiplied by the scale (presentation sizes, not balance numbers).
const SLOT_PX := 18
const ICON_PX := 16
const GAP := 2
const GROUP_GAP := 6
## Space kept clear at the bottom and at each side of the screen.
const BOTTOM_MARGIN := 4
const SIDE_MARGIN := 6
## Room for the "<3" / "5>" markers when a row is cut short.
const MORE_ROOM := 18
## Between the bag's row and the tools' row when they're on two rows.
const ROW_GAP := 3

## How an item that can't be used today (seeds out of season) is drawn.
const UNUSABLE_TINT := Color(1, 1, 1, 0.35)


func _ready() -> void:
	EventBus.item_added.connect(func(_id: StringName, _n: int) -> void: queue_redraw())
	EventBus.item_removed.connect(func(_id: StringName, _n: int) -> void: queue_redraw())
	EventBus.tool_selected.connect(func(_id: StringName) -> void: queue_redraw())
	EventBus.tool_upgraded.connect(func(_id: StringName, _tier: int) -> void: queue_redraw())
	EventBus.game_loaded.connect(queue_redraw)
	# Seeds grey out and come back as the seasons turn.
	EventBus.season_changed.connect(func(_s: int) -> void: queue_redraw())
	Settings.toolbar_changed.connect(func(_large: bool) -> void: queue_redraw())
	resized.connect(queue_redraw)
	# Runs while the game is paused, which is when conversations are open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pack_ui")  # TEST (DECISIONS 081): Ctrl+U redraws it


func _process(_delta: float) -> void:
	var covered := false
	for node in get_tree().get_nodes_in_group(&"covers_hotbar"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			covered = true
			break
	if visible == covered:
		visible = not covered


func pack_ui_changed() -> void:
	queue_redraw()


## How many game pixels a whole row of `count` slots at `scale` takes.
static func row_width(count: int, scale: int) -> int:
	if count <= 0:
		return 0
	return count * (SLOT_PX + GAP) * scale - GAP * scale


## The scale slots are drawn at: 2 normally, 1 with Settings → Toolbar small.
static func scale() -> int:
	return 2 if Settings.toolbar_large else 1


## How tall the strip is at the bottom of the screen, in game pixels, with
## the bag as it is now: for anything else that sits at the bottom of the
## screen and wants to keep clear of it.
func strip_height() -> int:
	var layout := _layout()
	return int(size.y - layout["top"])


func _draw() -> void:
	var layout := _layout()
	var tools: Array[ToolDef] = layout["tools"]
	var others: Array[ItemDef] = layout["others"]
	var selected := GameState.selected_tool()
	var season := GameState.season_id()

	# The tools' row (and, on one row, the rest after it).
	var s: int = layout["scale"]
	var y: float = layout["tools_y"]
	var x: float = layout["tools_x"]
	var first: int = layout["first_tool"]
	var shown: int = layout["tools_shown"]
	var name_at := Vector2(-1, -1)
	var name_text := ""
	if first > 0:
		_draw_more("<%d" % first, Vector2(x - MORE_ROOM, y), s, false)
	for i in range(first, first + shown):
		var tool_def := tools[i]
		var is_selected := tool_def == selected
		# Seeds out of season are greyed out, and say so when selected.
		# Under glass (the greenhouse, DECISIONS 057) every seed can go in.
		var usable := GameState.tool_usable_here(tool_def)
		_draw_slot(Vector2(x, y), tool_def, is_selected, tool_def.consumed_on_use, usable, s)
		if is_selected:
			name_text = GameState.tool_name(tool_def)
			if not usable:
				name_text += " · not in %s" % GameState.season_name(season).to_lower()
			# A dish says what it gives back (DECISIONS 056).
			if tool_def.action is EatAction:
				name_text += " · Space to eat, +%d energy" % roundi((tool_def.action as EatAction).energy)
			name_at = Vector2(x + SLOT_PX * s / 2.0, 0)
		x += (SLOT_PX + GAP) * s
	var hidden_after := tools.size() - first - shown
	if hidden_after > 0:
		_draw_more("%d>" % hidden_after, Vector2(x - GAP * s + 3, y), s, true)

	# The rest of the bag: after a gap on the same row, or on the row above.
	var bag_s: int = layout["bag_scale"]
	var bx: float = layout["bag_x"]
	var by: float = layout["bag_y"]
	var bag_shown: int = layout["bag_shown"]
	for i in bag_shown:
		_draw_slot(Vector2(bx, by), others[i], false, true, true, bag_s)
		bx += (SLOT_PX + GAP) * bag_s
	if bag_shown < others.size():
		_draw_more("+%d" % (others.size() - bag_shown), Vector2(bx, by), bag_s, true)

	# The selected tool's name, over the top row, centred on its slot.
	if name_text != "":
		_draw_name(name_text, Vector2(name_at.x, layout["top"] - 3))


## Where everything goes this frame. Worked out from the bag and the screen,
## so the drawing and strip_height() agree.
func _layout() -> Dictionary:
	var tools := GameState.hotbar()
	var others: Array[ItemDef] = []
	for item in GameState.inventory.items():
		if not item is ToolDef:
			others.append(item)
	var s := scale()
	var room := size.x - SIDE_MARGIN * 2
	var slot_h := SLOT_PX * s
	var tools_y := size.y - slot_h - BOTTOM_MARGIN
	var result := {
		"tools": tools, "others": others, "scale": s,
		"tools_y": tools_y, "first_tool": 0, "tools_shown": tools.size(),
		"bag_scale": s, "bag_shown": others.size(),
	}

	# One row, as it always was, if it fits.
	var one_row := row_width(tools.size(), s) + row_width(others.size(), s) \
			+ (GROUP_GAP * s + GAP * s if not tools.is_empty() and not others.is_empty() else 0)
	if one_row <= room:
		var x := roundf((size.x - one_row) / 2.0)
		result["tools_x"] = x
		result["bag_x"] = x + row_width(tools.size(), s) + (GROUP_GAP + GAP) * s if not tools.is_empty() else x
		result["bag_y"] = tools_y
		result["top"] = tools_y
		return result

	# Two rows. The tools: all of them if they fit, otherwise a window round
	# the selected one.
	var per_slot := (SLOT_PX + GAP) * s
	var fit := int((room + GAP * s) / per_slot)
	if tools.size() > fit:
		fit = maxi(1, int((room - MORE_ROOM * 2 + GAP * s) / per_slot))
		var at := maxi(0, tools.find(GameState.selected_tool()))
		var first := clampi(at - fit / 2, 0, tools.size() - fit)
		result["first_tool"] = first
		result["tools_shown"] = fit
	result["tools_x"] = roundf((size.x - row_width(result["tools_shown"], s)) / 2.0)

	# The rest of the bag, on the row above: at the same size if it fits,
	# small if not, and cut short with "+n" past that.
	var bag_s := s
	if row_width(others.size(), bag_s) > room:
		bag_s = 1
	var bag_fit := others.size()
	if row_width(others.size(), bag_s) > room:
		bag_fit = maxi(0, int((room - MORE_ROOM + GAP * bag_s) / ((SLOT_PX + GAP) * bag_s)))
	var bag_y := tools_y - ROW_GAP - SLOT_PX * bag_s
	result["bag_scale"] = bag_s
	result["bag_shown"] = bag_fit
	result["bag_x"] = roundf((size.x - row_width(bag_fit, bag_s)) / 2.0)
	result["bag_y"] = bag_y
	result["top"] = bag_y if not others.is_empty() else tools_y
	return result


func _draw_slot(at: Vector2, item: ItemDef, is_selected: bool, show_count: bool,
		usable: bool = true, s: int = 1) -> void:
	var rect := Rect2(at, Vector2(SLOT_PX, SLOT_PX) * s)
	# TEST (DECISIONS 081): the Wood theme's slots, if switched on.
	var wood := PackLook.ui_texture("slot_selected" if is_selected else "slot")
	if wood != null:
		draw_texture_rect(wood, rect, false)
	else:
		draw_rect(rect, UiStyle.SLOT)
		# The outline is a game pixel wide at ×1, two at ×2; the selected
		# slot's is a pixel thicker again so it stands out at either size.
		var edge := float(s + (1 if is_selected and s > 1 else 0))
		draw_rect(rect.grow(-edge / 2.0), UiStyle.HIGHLIGHT if is_selected else UiStyle.SLOT_EDGE, false, edge)
	if item.icon != null:
		var inset := (SLOT_PX - ICON_PX) / 2.0 * s
		draw_texture_rect(item.icon, Rect2(at + Vector2(inset, inset), Vector2(ICON_PX, ICON_PX) * s), false,
				Color.WHITE if usable else UNUSABLE_TINT)
	if show_count:
		var text := str(GameState.inventory.count(item))
		var font := get_theme_default_font()
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE)
		# Bottom right, inside the box at ×2, just under it at ×1 (as before).
		var pos := at + Vector2(SLOT_PX * s - text_size.x - (s - 1) * 2, SLOT_PX * s + 1 - (s - 1) * 4)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, 3, UiStyle.OUTLINE)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, UiStyle.TEXT)


## "<3", "5>" or "+4" beside a row that's been cut short, in the middle of
## the row's height. `at` is the row's top, at its left (or right) end.
func _draw_more(text: String, at: Vector2, s: int, left_aligned: bool) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE)
	var x := at.x if left_aligned else at.x + MORE_ROOM - text_size.x - 3
	var pos := Vector2(roundf(x), roundf(at.y + SLOT_PX * s / 2.0 + text_size.y / 4.0))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, 3, UiStyle.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, UiStyle.TEXT_DIM)


## The selected item's name, centred above its slot but kept on screen.
func _draw_name(text: String, centre: Vector2) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE)
	var left := clampf(centre.x - text_size.x / 2.0, 2.0, size.x - text_size.x - 2.0)
	var pos := Vector2(roundf(left), centre.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, 4, UiStyle.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.FONT_SIZE, UiStyle.TEXT)
