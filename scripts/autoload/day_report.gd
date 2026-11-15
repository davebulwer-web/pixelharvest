extends Node
##
## DayReport — keeps a tally of the day, for the summary shown at night
## (DECISIONS 042).
##
## It only listens on EventBus: what was harvested, planted, watered and
## weeded, what was lost overnight (DECISIONS 045), what
## was sold where, what was spent, which requests were finished, and what
## opened up (DECISIONS 043). When the day
## ends it closes the tally, and the next morning's HUD takes it and shows the
## summary screen (day_summary.gd) before the morning fades in.
##
## Nothing here is saved. The game saves at the start of a day, when the
## tally is empty, so there's nothing to keep.
##
## Order matters in one place: this autoload connects to day_started before
## any scene's HUD does (autoloads are made first), so the day's record is
## already closed when the HUD asks for it.
##

## Today's tally, filling up as the day goes on.
var today: DayRecord

## Yesterday's finished tally, waiting for the HUD to show it. Null when
## there's nothing to show: before the first night, or once it's been taken.
var _finished: DayRecord

## True from day_ended until day_started: the night, when the bin pays out.
var _night: bool = false


func _ready() -> void:
	_start_record()
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.crop_planted.connect(func(_c: Vector2i, _id: StringName) -> void: today.planted += 1)
	EventBus.tile_watered.connect(_on_tile_watered)
	EventBus.weeds_pulled.connect(func(_c: Vector2i) -> void: today.weeds_pulled += 1)
	# Crops are lost in the night, before day_started closes the record.
	EventBus.crop_died.connect(_on_crop_died)
	EventBus.giant_grew.connect(func(_c: Vector2i, id: StringName) -> void: today.giants.append(id))
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.shipment_sold.connect(func(gold: int) -> void: today.bin_sales += gold)
	EventBus.items_sold_to_shop.connect(func(_id: StringName, _n: int, gold: int) -> void: today.shop_sales += gold)
	EventBus.quest_completed.connect(func(id: StringName) -> void: today.quests_done.append(id))
	# Requests run out in the night (DECISIONS 050), before day_started.
	EventBus.quest_expired.connect(func(_id: StringName, title: String) -> void: today.quests_expired.append(title))
	# Overnight ones arrive before day_started closes the record, so the
	# morning's summary includes what the calendar opened.
	EventBus.unlocked.connect(func(id: StringName) -> void: today.unlocked.append(id))
	EventBus.day_ended.connect(func(_d: int) -> void: _night = true)
	EventBus.day_started.connect(_on_day_started)
	# A different game: forget this one's day.
	EventBus.new_game_started.connect(_reset)
	EventBus.game_loaded.connect(_reset)


## Hand over yesterday's finished tally, once. Null if there's none.
func take_finished() -> DayRecord:
	var record := _finished
	_finished = null
	return record


func _start_record() -> void:
	today = DayRecord.new()
	today.day = GameState.day
	today.season = GameState.season
	today.year = GameState.year


func _reset() -> void:
	_finished = null
	_night = false
	_start_record()


func _on_day_started(_day: int, _season: int, _year: int) -> void:
	if not _night:
		return
	_night = false
	today.gold_at_end = GameState.gold
	_finished = today
	_start_record()


func _on_crop_harvested(_cell: Vector2i, crop_id: StringName, amount: int) -> void:
	var crop := ContentDB.crop(crop_id)
	var item_id: StringName = crop.produce.id if crop != null and crop.produce != null else crop_id
	today.harvested[item_id] = today.harvested.get(item_id, 0) + amount


func _on_tile_watered(_cell: Vector2i) -> void:
	if not _night:
		today.watered += 1


func _on_crop_died(_cell: Vector2i, crop_id: StringName, cause: StringName) -> void:
	today.lost[cause] = today.lost.get(cause, 0) + 1
	if cause == &"crows":
		today.taken_by_crows.append(crop_id)


## Every coin in or out passes through here. Sales are also counted by kind
## (above), and DayRecord.other_income() is what's left over.
func _on_gold_changed(_amount: int, delta: int) -> void:
	if delta < 0:
		today.spent -= delta
	else:
		today.gold_in += delta
