extends CanvasLayer
##
## Hud — a minimal readout of the day, selected tool and energy, plus a short
## message line and the fade between days.
##
## A stopgap so the loop is visible while testing. The real HUD (gold, season,
## icons) is Stage 4 work and will replace this. Note that it never reads from
## the player: it only listens to EventBus, which is the pattern the real HUD
## will follow too.
##

## How long a message stays up, and how long the morning fade-in takes.
## These are presentation timings, not balance numbers, so they live here.
const MESSAGE_SECONDS := 2.0
const FADE_SECONDS := 0.6

@onready var _label: Label = $Label
@onready var _message: Label = $Message
@onready var _fade: ColorRect = $Fade

var _message_tween: Tween


func _ready() -> void:
	EventBus.tool_selected.connect(func(_id: StringName) -> void: _refresh())
	EventBus.energy_changed.connect(func(_c: float, _m: float) -> void: _refresh())
	EventBus.day_started.connect(_on_day_started)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.game_saved.connect(_on_game_saved)
	_fade.modulate.a = 0.0
	_message.text = ""
	_refresh()


func _refresh() -> void:
	var tool := GameState.selected_tool()
	var tool_name := tool.display_name if tool != null else "—"
	_label.text = "Day %d   ·   %s   ·   Energy %d / %d" % [
		GameState.day, tool_name, roundi(GameState.energy), roundi(GameState.max_energy)
	]


## Night falls instantly; morning fades in. Snapping to black and easing back
## reads as "time passed" without making the player wait twice.
func _on_day_started(day: int, _season: int, _year: int) -> void:
	_refresh()
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, ^"modulate:a", 0.0, FADE_SECONDS)
	_show_message("Day %d" % day)


## The save lands just after the morning message, so it extends it rather
## than replacing it.
func _on_game_saved() -> void:
	_show_message("Day %d   ·   Saved" % GameState.day)


func _on_crop_harvested(_cell: Vector2i, crop_id: StringName, amount: int) -> void:
	# Until ContentDB exists there's no lookup from id to display name, so
	# the id is shown as-is. Stage 4 replaces this with the crop's name.
	_show_message("Harvested %d %s" % [amount, String(crop_id).capitalize()])


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SECONDS)
	_message_tween.tween_property(_message, ^"modulate:a", 0.0, 0.4)
