extends StaticBody2D
##
## TideBoard — the board on the Cove's quay that gives today's tides
## (DECISIONS 064): face it and press E. Like the Lane's signpost, but its
## words are worked out from the date and the clock (Tides), not written on
## the scene.
##

const TILE_PX := 16


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX) == cell


func interact() -> void:
	var lows: Array[String] = []
	for low in Tides.lows_on(GameState.day_number()):
		lows.append(Clock.format(low))
	if lows.is_empty():
		return
	EventBus.message_posted.emit("Tide board: low tide %s. %s" % [" and ".join(lows), Tides.now_text()])
