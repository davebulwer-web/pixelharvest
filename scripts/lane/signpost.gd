extends StaticBody2D
##
## Signpost — a sign that says something when you face it and press E: the
## Lane's signpost at the top of the cliff path (DECISIONS 060). What it says
## is set on the scene (`words`), so another sign is another scene, not code.
##
## Like the shipping bin, it joins the "interactable" group, so the player's
## E key needs nothing new.
##

const TILE_PX := 16

@export_multiline var words: String = ""


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX) == cell


func interact() -> void:
	if words != "":
		EventBus.message_posted.emit(words)
