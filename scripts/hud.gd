extends CanvasLayer
##
## Hud — a minimal readout of the selected tool and energy.
##
## A stopgap so tool switching and energy costs are visible while testing.
## The real HUD (gold, day, season, icons) is Stage 4 work and will replace
## this. Note that it reads nothing directly from the player: it only listens
## to EventBus, which is the pattern the real HUD will follow too.
##

@onready var _label: Label = $Label


func _ready() -> void:
	EventBus.tool_selected.connect(func(_id: StringName) -> void: _refresh())
	EventBus.energy_changed.connect(func(_c: float, _m: float) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var tool := GameState.selected_tool()
	var tool_name := tool.display_name if tool != null else "—"
	_label.text = "%s   ·   Energy %d / %d" % [
		tool_name, roundi(GameState.energy), roundi(GameState.max_energy)
	]
