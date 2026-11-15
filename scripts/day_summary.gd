class_name DaySummary
extends CanvasLayer
##
## DaySummary — the screen at the end of each day: what you picked, planted
## and watered, what you sold and spent, and how the purse stands
## (DECISIONS 042). Below that, what's new this morning: what opened up and
## who has something to ask (DECISIONS 043).
##
## The HUD opens it on the morning after a night, on black, before the
## morning fades in, with the tally DayReport kept. It only shows what it's
## given and says when it's closed (`closed`); the HUD then carries on with
## the morning.
##
## Made in code and added when needed, like the difficulty menu. The game is
## paused while it's open; this node keeps running while paused.
##
## Keys: Space, E or Enter to carry on.
##

signal closed()

const PANEL_WIDTH := 300

## Keys pressed in the first moment are ignored: the E that put you to bed,
## or Space held down in the field when the energy ran out, would otherwise
## close it before it's been read.
const IGNORE_KEYS_MS := 400

var record: DayRecord

var _opened_at: int = 0


func _ready() -> void:
	layer = 9  # over the HUD (2) and its fade; under the difficulty menu (10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_opened_at = Time.get_ticks_msec()
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"use_tool") or event.is_action_pressed(&"interact")
			or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"sleep")):
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_at < IGNORE_KEYS_MS:
		return
	Audio.play(&"menu")
	get_tree().paused = false
	queue_free()
	closed.emit()


# --- What it says ------------------------------------------------------------

## The rows of the table, as [label, value] pairs, leaving out the empty ones.
## Separate from the drawing so it can be checked without a screen.
static func rows_for(r: DayRecord) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if not r.harvested.is_empty():
		rows.append(PackedStringArray(["Harvested", harvest_text(r.harvested)]))
	if r.planted > 0:
		rows.append(PackedStringArray(["Planted", "%d seed%s" % [r.planted, _s(r.planted)]]))
	if r.watered > 0:
		rows.append(PackedStringArray(["Watered", "%d tile%s" % [r.watered, _s(r.watered)]]))
	if r.shop_sales > 0:
		rows.append(PackedStringArray(["Sold in town", "%dg" % r.shop_sales]))
	if r.bin_sales > 0:
		rows.append(PackedStringArray(["Shipping bin", "%dg" % r.bin_sales]))
	if r.other_income() > 0:
		rows.append(PackedStringArray(["Rewards", "%dg" % r.other_income()]))
	if r.spent > 0:
		rows.append(PackedStringArray(["Spent", "-%dg" % r.spent]))
	return rows


## What's new this morning, one line each (DECISIONS 043): what opened up
## (from a request handed in yesterday, or the calendar overnight), then who
## has something new to ask today. Separate from the drawing, like rows_for.
static func news_for(r: DayRecord) -> Array[String]:
	var news: Array[String] = []
	for id in r.unlocked:
		var unlock_def := ContentDB.unlock(id)
		if unlock_def != null and unlock_def.announcement != "":
			news.append(unlock_def.announcement)
	var names: Array[String] = []
	for giver in Quests.givers_new_today():
		var person := ContentDB.character(giver)
		names.append(person.display_name if person != null else String(giver))
	if not names.is_empty():
		news.append("%s %s something to ask you." % [_and_list(names), "has" if names.size() == 1 else "have"])
	return news


## "A", "A and B", "A, B and C".
static func _and_list(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## "6 Parsnip, 2 Potato", most first.
static func harvest_text(harvested: Dictionary[StringName, int]) -> String:
	var ids: Array = harvested.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		if harvested[a] != harvested[b]:
			return harvested[a] > harvested[b]
		return String(a) < String(b)
	)
	var parts: PackedStringArray = []
	for id: StringName in ids:
		var item := ContentDB.item(id)
		parts.append("%d %s" % [harvested[id], item.display_name if item != null else String(id)])
	return ", ".join(parts)


## "+330g", "-40g" or "0g".
static func signed_gold(amount: int) -> String:
	return ("+%dg" if amount > 0 else "%dg") % amount


static func _s(count: int) -> String:
	return "" if count == 1 else "s"


# --- Drawing it --------------------------------------------------------------

func _build() -> void:
	# Night: the HUD's fade is already black underneath; this makes sure.
	var back := ColorRect.new()
	back.color = UiStyle.OUTLINE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

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
	title.text = "End of %s" % _date_text()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, 12)
	column.add_child(title)

	var rows := rows_for(record)
	if rows.is_empty():
		var quiet := Label.new()
		quiet.text = "A quiet day."
		quiet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.style_label(quiet, 10, UiStyle.TEXT_DIM)
		column.add_child(quiet)
	else:
		column.add_child(_table(rows))

	column.add_child(HSeparator.new())
	var totals: Array[PackedStringArray] = [
		PackedStringArray(["Today", signed_gold(record.net())]),
		PackedStringArray(["Purse", "%dg" % record.gold_at_end]),
	]
	column.add_child(_table(totals, UiStyle.GOLD))

	for quest_id in record.quests_done:
		var quest := ContentDB.quest(quest_id)
		var done := Label.new()
		done.text = "Request done: %s" % (quest.title if quest != null else String(quest_id))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.style_label(done, 10, UiStyle.GOLD)
		column.add_child(done)

	var news := news_for(record)
	if not news.is_empty():
		column.add_child(HSeparator.new())
		for line in news:
			var item := Label.new()
			item.text = line
			item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiStyle.style_label(item, 10, UiStyle.TEXT)
			column.add_child(item)

	var hint := Label.new()
	hint.text = "Space to start day %d" % GameState.day
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(hint, 9, UiStyle.TEXT_DIM)
	column.add_child(hint)

	# Pop in: start a little small and see-through, settle at full size.
	panel.pivot_offset = Vector2(PANEL_WIDTH / 2.0, 60)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, ^"scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, ^"modulate:a", 1.0, 0.2)


## Two columns: names on the left, values on the right.
func _table(rows: Array[PackedStringArray], value_colour: Color = UiStyle.TEXT) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 1)
	for row in rows:
		var name_label := Label.new()
		name_label.text = row[0]
		UiStyle.style_label(name_label, 10, UiStyle.TEXT_DIM)
		grid.add_child(name_label)
		var value := Label.new()
		value.text = row[1]
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiStyle.style_label(value, 10, value_colour)
		grid.add_child(value)
	return grid


## "Spring · Day 5 · Year 1" for the day the record is of.
func _date_text() -> String:
	var seasons := GameState.RULES.seasons
	var season_name := "Season %d" % (record.season + 1)
	if record.season >= 0 and record.season < seasons.size() and seasons[record.season] != null:
		season_name = seasons[record.season].display_name
	return "%s · Day %d · Year %d" % [season_name, record.day, record.year]
