class_name PauseMenu
extends MenuScreen
##
## PauseMenu — Esc out in the world (DECISIONS 086): Resume, Settings,
## Controls, New game, Back to the title, Quit.
##
## The game saves each night (DECISIONS 035), so leaving mid-day loses the
## day so far: Back to the title and Quit ask first. New game is Ctrl+N's
## difficulty menu, which already says Esc goes back to the game.
##
## SaveSystem opens it (next to Ctrl+N), only when nothing else has the game
## paused, so Esc still closes shops, the almanac and conversations first.
##

const LEAVE_WARNING := "The game saves each night, when you sleep. Anything done since this morning will be lost."


func _show_main() -> void:
	_page("Paused", true)
	_hint.text = "Space / Enter: choose     Esc: resume"
	_button("Resume", "Back to the game.", close)
	_button("Settings", "Music and sound volume, window or full screen.", _show_settings)
	_button("Controls", "Which key does what.", _show_controls)
	_button("New game", "Start again on the first morning of spring (Ctrl+N). Your saved game is kept until you first sleep in the new one.", _new_game)
	_button("Title screen", "Leave this day and go back to the title. " + LEAVE_WARNING,
			func() -> void: _confirm("Go back to the title?\n" + LEAVE_WARNING, "Go to the title", _to_title))
	_button("Quit", "Close the game. " + LEAVE_WARNING,
			func() -> void: _confirm("Close the game?\n" + LEAVE_WARNING, "Quit", _quit_game))
	_focus_first()


func _on_escape_at_main() -> void:
	Audio.play(&"menu")
	close()


func _new_game() -> void:
	close()
	SaveSystem.ask_for_new_game()


## Back to the boot scene, which loads the save again and shows the title.
func _to_title() -> void:
	close()
	get_tree().change_scene_to_file(SaveSystem.BOOT_SCENE)
