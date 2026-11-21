extends Node
##
## Boot — the first scene the game runs. It shows nothing itself; it gets the
## game ready and opens the title screen over it.
##
## First it asks SaveSystem to load the save, if there is one. If there isn't
## (or it can't be read), SaveSystem leaves a fresh game at the default
## difficulty. Either way it opens the place the farmer is in, so the title
## screen (TitleScreen, DECISIONS 086) has the real world behind it, paused.
## Continue takes the title away; New game asks the difficulty (DifficultyMenu,
## DECISIONS 040) and starts again.
##
## The Esc menu's "Title screen" comes back here, which loads the save again.
## Keeping this out of the farm scene means the farm never has to know how the
## game started.
##

func _ready() -> void:
	var loaded := SaveSystem.load_or_new_game()
	# Deferred: changing scene from inside the _ready of the scene being
	# replaced is not allowed, so wait until this frame's setup is done.
	_open.call_deferred(loaded)


func _open(loaded: bool) -> void:
	# The title is added to the root, not to this scene, so it stays when
	# this scene is replaced by the farmer's place.
	var title := TitleScreen.new()
	title.save_was_unreadable = not loaded and SaveSystem.load_problem != ""
	get_tree().root.add_child(title)
	LocationManager.go_to(GameState.location)
