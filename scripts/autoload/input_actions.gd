extends Node
##
## InputActions — registers every input action the game uses, in code.
##
## Why here rather than in the editor's Input Map: these then live in a file
## that can be read, reviewed and changed like any other source, and they
## travel with the repo without anyone having to click through the editor.
## See DECISIONS.md entry 010 for the trade-off.
##
## Physical keycodes are used deliberately, so the WASD cluster stays in the
## same place on non-QWERTY keyboards.
##
## A key can carry Ctrl by adding KEY_MASK_CTRL, e.g. KEY_N | KEY_MASK_CTRL.
## Avoid bare function keys: the Godot editor keeps several for itself while
## the game runs (F9 pauses the running project), so the game never sees them.
##

## action name -> list of physical keys that trigger it
const ACTIONS: Dictionary = {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"use_tool": [KEY_SPACE],
	&"interact": [KEY_E],
	&"open_inventory": [KEY_I],
	&"quest_log": [KEY_J],
	&"next_tool": [KEY_TAB],
	&"prev_tool": [KEY_Q],
	&"sleep": [KEY_ENTER],
	&"new_game": [KEY_N | KEY_MASK_CTRL],
	# Godot's built-in menu actions already have the arrow keys; adding WASD
	# lets the shop menu be driven from the same hand as walking.
	&"ui_up": [KEY_W],
	&"ui_down": [KEY_S],
	&"ui_left": [KEY_A],
	&"ui_right": [KEY_D],
}


func _ready() -> void:
	_register_actions()


func _register_actions() -> void:
	for action_name: StringName in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode: Key in ACTIONS[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode & KEY_CODE_MASK
			event.ctrl_pressed = (keycode & KEY_MASK_CTRL) != 0
			InputMap.action_add_event(action_name, event)
