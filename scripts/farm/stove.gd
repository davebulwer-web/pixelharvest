class_name Stove
extends StaticBody2D
##
## Stove — the farmhouse's kitchen (DECISIONS 056). Face it and press E to
## cook what you know.
##
## It's an "interactable" like the bed: the player finds it in the cell ahead
## and calls interact(). It doesn't cook anything itself; it asks to be
## `used`, and the farmhouse opens the cooking menu (CookMenu). That keeps
## the menu, which is a screen, out of a thing that stands in the room.
##
## The stove is always there, but cold until Mabel's lessons open the
## kitchen (GameState.kitchen_open): until then E says who might teach you.
## Opening it happens in town, so by the time you're home the room has been
## built afresh with the stove lit.
##

const TILE_PX := 16

## E at a lit stove.
signal used

var cell: Vector2i
var _sprite: Sprite2D


## A stove standing on `stove_cell`, shown with `lit` once the kitchen is
## open and `cold` before. The picture can be taller than a tile (its chimney
## runs up the wall); only the bottom tile is solid.
static func create(lit: Texture2D, cold: Texture2D, stove_cell: Vector2i) -> Stove:
	var stove := Stove.new()
	stove.name = "Stove"
	stove.cell = stove_cell
	stove.position = Vector2(stove_cell.x * TILE_PX + TILE_PX / 2.0, (stove_cell.y + 1) * TILE_PX)
	var texture := lit if GameState.kitchen_open() else cold
	stove._sprite = Sprite2D.new()
	stove._sprite.texture = texture
	stove._sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	stove.add_child(stove._sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE_PX - 2, TILE_PX / 2.0)
	shape.shape = box
	shape.position = Vector2(0, -box.size.y / 2.0)
	stove.add_child(shape)
	return stove


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(other: Vector2i) -> bool:
	return other == cell


func interact() -> void:
	if not GameState.kitchen_open():
		EventBus.message_posted.emit("The old stove is cold. Mabel the baker could show you how to cook")
		return
	if GameState.known_recipes(&"stove").is_empty():
		EventBus.message_posted.emit("The stove's lit, but you don't know any recipes yet")
		return
	used.emit()
