class_name DaySummary
extends CanvasLayer
##
## DaySummary — the screen at the end of each day: what you picked, planted
## and watered, what you sold and spent, and how the purse stands
## (DECISIONS 042). Below that, what's new this morning: what opened up and
## who has something to ask (DECISIONS 043), what the hazards did or are
## about to do: crows in the night, crops wilting (DECISIONS 045), and the
## weather today and tomorrow, with a warning days ahead of autumn's frost
## (DECISIONS 046).
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
	if not r.caught.is_empty():
		rows.append(PackedStringArray(["Caught", harvest_text(r.caught)]))
	if r.weeds_pulled > 0:
		rows.append(PackedStringArray(["Weeded", "%d patch%s" % [r.weeds_pulled, "" if r.weeds_pulled == 1 else "es"]]))
	if not r.lost.is_empty():
		rows.append(PackedStringArray(["Crops lost", lost_text(r.lost)]))
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
## has something new to ask today, and in a season's last days the warning
## that it's ending. Separate from the drawing, like rows_for.
static func news_for(r: DayRecord) -> Array[String]:
	var news: Array[String] = []
	var weather := Notices.weather_report()
	if weather != "":
		news.append(weather)
	var coming := Notices.weather_warning()
	if coming != "":
		news.append(coming)
	for id in r.unlocked:
		var unlock_def := ContentDB.unlock(id)
		if unlock_def != null and unlock_def.announcement != "":
			news.append(unlock_def.announcement)
	var crows := crows_news(r.taken_by_crows)
	if crows != "":
		news.append(crows)
	var giants := giants_news(r.giants)
	if giants != "":
		news.append(giants)
	var made := made_news(r.made)
	if made != "":
		news.append(made)
	var thirst := thirst_warning()
	if thirst != "":
		news.append(thirst)
	var pests := pests_warning()
	if pests != "":
		news.append(pests)
	# Requests that ran out in the night, and today's orders (DECISIONS 050).
	for title in r.quests_expired:
		news.append("Out of time: %s. That request has gone." % title)
	news.append_array(Quests.order_news_today())
	# Today's festivals (DECISIONS 059).
	news.append_array(Festivals.news_today())
	var names: Array[String] = []
	for giver in Quests.givers_new_today():
		names.append(Quests.giver_name(giver))
	if not names.is_empty():
		news.append("%s %s something to ask you." % [_and_list(names), "has" if names.size() == 1 else "have"])
	# The notice board's end-of-season warning, here too (DECISIONS 044).
	var warning := Notices.season_end_warning()
	if warning != "":
		news.append(warning)
	return news


## "2 to thirst, 1 to crows": crops lost overnight, by cause, in a fixed order.
static func lost_text(lost: Dictionary[StringName, int]) -> String:
	var words := {&"thirst": "to thirst", &"crows": "to crows", &"storm": "to the storm",
			&"frost": "to frost", &"season": "to the season"}
	var parts: PackedStringArray = []
	for cause: StringName in [&"thirst", &"crows", &"storm", &"frost", &"season"]:
		if lost.get(cause, 0) > 0:
			parts.append("%d %s" % [lost[cause], words[cause]])
	for cause: StringName in lost:  # any cause added later still shows
		if not words.has(cause) and lost[cause] > 0:
			parts.append("%d to %s" % [lost[cause], cause])
	return ", ".join(parts)


## "A crow took your Parsnip in the night. ...", or "" if none did.
static func crows_news(crop_ids: Array[StringName]) -> String:
	if crop_ids.is_empty():
		return ""
	var names: Array[String] = []
	for id in crop_ids:
		var crop := ContentDB.crop(id)
		names.append(crop.display_name if crop != null else String(id))
	return "%s %s your %s in the night. A scarecrow keeps them off the crops round it." % [
		"A crow" if crop_ids.size() == 1 else "Crows", "took", _and_list(names)]


## The warning about thirsty crops on the farm and in the greenhouse this
## morning, or "": how many will die tonight unless watered, or (where thirst
## doesn't kill, or not yet) how many are wilting. In a heatwave a crop
## outside gets thirstier faster (DECISIONS 046), so a dry night counts
## double here too; under glass (DECISIONS 057) it never does.
static func thirst_warning() -> String:
	var deadline := GameState.thirst_deadline()
	var wilting := 0
	var dying := 0
	for plot in GameState.plots():
		if plot == null:
			continue
		var step := 1 if plot.under_glass else GameState.thirst_per_dry_night()
		for cell in GameState.wilted_crops(plot):
			wilting += 1
			if deadline > 0 and plot.tile(cell).dry_nights + step >= deadline:
				dying += 1
	if wilting == 0:
		return ""
	if dying > 0:
		return "%d crop%s will die of thirst tonight unless watered." % [dying, _s(dying)]
	return "%d crop%s %s wilting for want of water." % [wilting, _s(wilting), "is" if wilting == 1 else "are"]


## "Your bees have been busy: 2 honey ready to collect...", or "" if nothing was made
## overnight (DECISIONS 057).
static func made_news(made: Dictionary[StringName, int]) -> String:
	if made.is_empty():
		return ""
	var parts: Array[String] = []
	for item_id: StringName in made:
		var item := ContentDB.item(item_id)
		var name := item.display_name.to_lower() if item != null else String(item_id)
		parts.append("%d %s" % [made[item_id], name])
	return "Your bees have been busy: %s ready to collect. E at a hive takes it." % _and_list(parts)


## "A giant Pumpkin grew overnight! ...", or "" if none did (DECISIONS 048).
static func giants_news(crop_ids: Array[StringName]) -> String:
	if crop_ids.is_empty():
		return ""
	var names: Array[String] = []
	for id in crop_ids:
		var crop := ContentDB.crop(id)
		names.append(crop.display_name if crop != null else String(id))
	return "%s grew overnight! Pick %s with E." % [
		"A giant " + names[0] if names.size() == 1 else "Giants (" + _and_list(names) + ")",
		"it" if names.size() == 1 else "them"]


## "Aphids are on 3 crops. ...", or "" if there are none (DECISIONS 048).
static func pests_warning() -> String:
	var count := GameState.crops_with_pests().size()
	if count == 0:
		return ""
	return "Aphids are on %d crop%s: %s stopped growing. Spray %s (Marlow sells pest spray) or dig %s up before they spread." % [
		count, _s(count), "it has" if count == 1 else "they have", "it" if count == 1 else "them",
		"it" if count == 1 else "them"]


## "A", "A and B", "A, B and C".
static func _and_list(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## "6 Parsnip, 2 Potato", most first. Fish caught are listed the same way.
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

	for result in record.festival_results:
		var placed := Label.new()
		placed.text = result
		placed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiStyle.style_label(placed, 10, UiStyle.GOLD)
		column.add_child(placed)

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
