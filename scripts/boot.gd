extends Node
##
## Boot — the first scene the game runs. It shows nothing; it decides where
## the player should be and sends them there.
##
## First it asks SaveSystem to load the save, if there is one. If there isn't
## (or it can't be read), it asks which difficulty to play at (DifficultyMenu,
## DECISIONS 040) and starts a new game at that. Then it sends the player to
## wherever the game says they are. Stage 9's title screen slots in here too.
## Keeping this out of the farm scene means the farm never has to know how the
## game started.
##

func _ready() -> void:
	if SaveSystem.load_or_new_game():
		# Deferred: changing scene from inside the _ready of the scene being
		# replaced is not allowed, so wait until this frame's setup is done.
		LocationManager.go_to.call_deferred(GameState.location)
		return
	var menu := DifficultyMenu.new()
	menu.chosen.connect(_start)
	add_child(menu)


func _start(difficulty: DifficultyDef) -> void:
	GameState.new_game(difficulty)
	LocationManager.go_to(GameState.location)
