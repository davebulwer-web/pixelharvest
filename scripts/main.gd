extends Node2D
##
## Stage 0 placeholder scene.
##
## Its only job is to prove the project opens, the autoloads start, and input
## registration works end to end. Stage 1 replaces it with the farm scene.
##

const LINES: Array[String] = [
	"PIXEL HARVEST",
	"Stage 0 — project skeleton",
	"",
	"If you can read this, the project opens and the autoloads are running.",
	"Press movement keys, SPACE, E, I, TAB, Q or ENTER —",
	"each should log to the Output panel at the bottom of the editor.",
]


func _ready() -> void:
	print("--- Pixel Harvest ---")
	print("Godot %s" % Engine.get_version_info().get("string", "unknown"))
	print("EventBus loaded: %s" % (EventBus != null))
	print("InputActions loaded: %s" % (InputActions != null))
	print("Input actions registered: %d" % InputActions.ACTIONS.size())
	print("Press keys to test input. ---")
	_add_banner()


func _add_banner() -> void:
	var label := Label.new()
	label.text = "\n".join(LINES)
	label.position = Vector2(24.0, 24.0)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action_name: StringName in InputActions.ACTIONS:
		if event.is_action_pressed(action_name):
			print("action pressed: %s" % action_name)
