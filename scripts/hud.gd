extends CanvasLayer
##
## Hud — the always-on readout: the date, gold, energy, what's waiting in
## the shipping bin, a short message line, the hotbar (hotbar.gd), and the fade
## between days.
##
## It never reads from the player and nothing calls it: it listens on EventBus
## and reads GameState. That's what will let Stage 8's quest log or a market-day
## banner join the screen without anything else changing.
##

## How long a message stays up, and how long the morning fade-in takes.
## These are presentation timings, not balance numbers, so they live here.
const MESSAGE_SECONDS := 2.5
const FADE_SECONDS := 0.6

@onready var _label: Label = $Label
@onready var _message: Label = $Message
@onready var _fade: ColorRect = $Fade

var _message_tween: Tween

## What happened overnight. The bin is sold and crops die during the night,
## before the morning starts, so it's gathered here and moved into the
## _morning_ copies when day breaks, for the morning message.
var _overnight_sales: int = 0
var _overnight_deaths: int = 0
var _overnight_new_season: bool = false
var _morning_sales: int = 0
var _morning_deaths: int = 0
var _morning_new_season: bool = false


func _ready() -> void:
	EventBus.tool_selected.connect(func(_id: StringName) -> void: _refresh())
	EventBus.energy_changed.connect(func(_c: float, _m: float) -> void: _refresh())
	EventBus.gold_changed.connect(func(_g: int, _d: int) -> void: _refresh())
	EventBus.day_started.connect(_on_day_started)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.items_shipped.connect(_on_items_shipped)
	EventBus.shipment_sold.connect(func(gold: int) -> void: _overnight_sales = gold)
	EventBus.crop_died.connect(func(_cell: Vector2i, _id: StringName) -> void: _overnight_deaths += 1)
	EventBus.season_changed.connect(func(_s: int) -> void: _overnight_new_season = true)
	EventBus.item_bought.connect(_on_item_bought)
	EventBus.upgrade_bought.connect(_on_upgrade_bought)
	EventBus.object_placed.connect(_on_object_placed)
	EventBus.object_removed.connect(_on_object_removed)
	EventBus.game_saved.connect(_on_game_saved)
	_fade.modulate.a = 0.0
	_message.text = ""
	_refresh()


func _refresh() -> void:
	var text := "%s    %dg    Energy %d / %d" % [
		_date(), GameState.gold, roundi(GameState.energy), roundi(GameState.max_energy),
	]
	var in_bin := Economy.bin_value()
	if in_bin > 0:
		text += "    In the bin: %dg" % in_bin
	_label.text = text


## Night falls instantly; morning fades in. Snapping to black and easing back
## reads as "time passed" without making the player wait twice.
func _on_day_started(_day: int, _season: int, _year: int) -> void:
	_morning_sales = _overnight_sales
	_morning_deaths = _overnight_deaths
	_morning_new_season = _overnight_new_season
	_overnight_sales = 0
	_overnight_deaths = 0
	_overnight_new_season = false
	_refresh()
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, ^"modulate:a", 0.0, FADE_SECONDS)
	_show_message(_morning_text())


## The save lands just after the morning message, so it extends it rather
## than replacing it.
func _on_game_saved() -> void:
	_show_message(_morning_text() + "    Saved")


## "Spring · Day 5 · Year 1"
func _date() -> String:
	var theme := GameState.current_season_theme()
	var season_name := theme.display_name if theme != null else "Season %d" % (GameState.season + 1)
	return "%s · Day %d · Year %d" % [season_name, GameState.day, GameState.year]


func _morning_text() -> String:
	var text := "Day %d" % GameState.day
	if _morning_new_season:
		var theme := GameState.current_season_theme()
		text = "%s has come" % (theme.display_name if theme != null else "A new season")
		if GameState.season == 0:
			text += " — year %d" % GameState.year
	if _morning_deaths > 0:
		text += "    %d crop%s died out of season" % [_morning_deaths, "" if _morning_deaths == 1 else "s"]
	if _morning_sales > 0:
		text += "    The bin sold for %dg" % _morning_sales
	return text


func _on_crop_harvested(_cell: Vector2i, crop_id: StringName, amount: int) -> void:
	var crop := ContentDB.crop(crop_id)
	var item_name := crop.produce.display_name if crop != null and crop.produce != null else String(crop_id)
	_show_message("Harvested %d %s" % [amount, item_name])


func _on_items_shipped(count: int, value: int) -> void:
	_refresh()
	if count == 0:
		_show_message("Nothing to ship — the bin takes produce")
	else:
		_show_message("Shipped %d for %dg — paid overnight" % [count, value])


func _on_item_bought(item_id: StringName, amount: int, cost: int) -> void:
	var item := ContentDB.item(item_id)
	_show_message("Bought %d %s for %dg" % [amount, item.display_name if item else String(item_id), cost])


func _on_upgrade_bought(upgrade_id: StringName, cost: int) -> void:
	var upgrade := ContentDB.upgrade(upgrade_id)
	_show_message("Bought %s for %dg" % [upgrade.display_name if upgrade else String(upgrade_id), cost])


func _on_object_placed(_cell: Vector2i, object_id: StringName) -> void:
	var object_def := ContentDB.object(object_id)
	if object_def == null:
		return
	var text := "Placed the %s" % object_def.display_name.to_lower()
	if not object_def.water_offsets.is_empty():
		text += " — it waters %d tiles every morning" % object_def.water_offsets.size()
	_show_message(text)


func _on_object_removed(_cell: Vector2i, object_id: StringName) -> void:
	var object_def := ContentDB.object(object_id)
	if object_def != null:
		_show_message("Picked up the %s" % object_def.display_name.to_lower())


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SECONDS)
	_message_tween.tween_property(_message, ^"modulate:a", 0.0, 0.4)
