extends Control
##
## QuestPanel — the request log: press J to see what the townsfolk have asked
## of you and how far along each request is, J again to put it away
## (DECISIONS 038). Part of the HUD, so it's there on the farm, in town and
## indoors.
##
## Like the rest of the HUD it holds nothing: it reads the Quests service and
## redraws whenever EventBus says a request started, moved on or was finished,
## or the bag changed (a delivery counts what's in the bag). The game carries
## on while it's open; it's a note in your pocket, not a menu.
##

const WIDTH := 250

var _panel: PanelContainer
var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_panel.visible = false
	for signal_ref: Signal in [EventBus.quest_started, EventBus.quest_completed, EventBus.item_added,
			EventBus.item_removed, EventBus.gold_changed]:
		signal_ref.connect(func(_a = null, _b = null) -> void: _refresh())
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quest_log"):
		get_viewport().set_input_as_handled()
		_panel.visible = not _panel.visible
		_refresh()


func is_open() -> bool:
	return _panel.visible


func _refresh() -> void:
	if not _panel.visible:
		return
	for child in _list.get_children():
		child.queue_free()
	_add_line("Requests", 10, UiStyle.GOLD)
	var quests := Quests.active()
	if quests.is_empty():
		_add_line("Nothing asked of you just now. Townsfolk with a ! over their heads have something to ask.",
				8, UiStyle.TEXT_DIM)
	for quest in quests:
		var who := Quests.giver_name(quest.giver)
		var done := Quests.progress(quest)
		var status := "Ready! Go and see %s" % who if Quests.is_ready(quest) else quest.goal.progress_text(done)
		_add_line("%s  (%s)" % [quest.title, who], 9, UiStyle.TEXT)
		# Once some of a "one of each" request is found, say what's left
		# rather than the whole list again (DECISIONS 049).
		var what := quest.goal.describe()
		var missing := "" if Quests.is_ready(quest) else quest.goal.still_needed(GameState.inventory)
		if missing != "" and done > 0:
			what = "Still to find: %s" % missing
		_add_line("%s.  %s" % [what, status], 8, UiStyle.TEXT_DIM)
	var finished := GameState.quests.done_count()
	if finished > 0:
		_add_line("Finished: %d" % finished, 8, UiStyle.TEXT_DIM)
	_add_line("J to close", 8, UiStyle.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)


func _add_line(text: String, size: int, colour: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 12, 0)
	UiStyle.style_label(label, size, colour)
	_list.add_child(label)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.box(UiStyle.PANEL, UiStyle.PANEL_EDGE, 6))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	# Top right, under the date line, clear of the hotbar.
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -WIDTH - 6
	_panel.offset_right = -6
	_panel.offset_top = 36
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	_panel.add_child(_list)
