extends Node
##
## Boot — the first scene the game runs. It shows nothing; it decides where
## the player should be and sends them there.
##
## Today that's always GameState.location from a new game. In Stage 3 this is
## where "is there a save? load it" goes, and Stage 9's title screen slots in
## here too. Keeping the decision out of the farm scene means the farm never
## has to know how the game started.
##

func _ready() -> void:
	# Deferred: changing scene from inside the _ready of the scene being
	# replaced is not allowed, so wait until this frame's setup is done.
	LocationManager.go_to.call_deferred(GameState.location)
