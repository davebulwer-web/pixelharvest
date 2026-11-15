extends StaticBody2D
##
## ShippingBin — the box at the end of the path. Face it and press E to put
## all your produce in; it sells overnight (see economy.gd).
##
## This node is only the bin's *presence* on the farm: its picture, its
## collision, and answering the interact key. What's in it lives in
## GameState.shipping_bin, and where it stands lives in FarmData, so the farm
## scene can be rebuilt without losing either.
##
## It joins the "interactable" group. The player doesn't know what a shipping
## bin is: on E it looks for an interactable on the tile it's facing and calls
## interact(). Stage 7's doors and shopkeepers join the same group the same
## way, so the player's code won't change for them.
##

const TILE_PX := 16


func _ready() -> void:
	add_to_group(&"interactable")
	EventBus.items_shipped.connect(_on_items_shipped)


## True if the bin stands on `cell`. The node's origin is the bottom-middle of
## its tile (see main.gd, cell_base), so step 1px up to land inside it.
func occupies(cell: Vector2i) -> bool:
	return Vector2i((position - Vector2(0, 1)) / TILE_PX) == cell


func interact() -> void:
	Economy.ship_all()


## Something went in: the bin squashes down and springs back, as if the lid
## had shut on it (DECISIONS 042). Only the picture moves, never the body.
func _on_items_shipped(count: int, _value: int) -> void:
	if count == 0:
		return
	var sprite := $Sprite as Sprite2D
	sprite.scale = Vector2(1.2, 0.8)
	sprite.create_tween().tween_property(sprite, ^"scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
