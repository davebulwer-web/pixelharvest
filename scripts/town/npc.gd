class_name Npc
extends StaticBody2D
##
## Npc — a character standing in a place, who answers E.
##
## Like the shipping bin it joins the "interactable" group, so the player's E
## key needs no special case for people. All an Npc does is announce, on
## EventBus, that it was spoken to; what that leads to (a shop menu, later a
## quest) is up to whoever listens. This node holds a picture, a place to
## stand and which tiles count as "talking to me" — nothing else.
##
## The origin is the bottom-middle of the cell the character stands on.
##

const TILE_PX := 16

## Matches the player's sprite: a 56×56 frame with the feet 19px below centre.
const SPRITE_OFFSET := Vector2(0, -19)

var npc_id: StringName = &""

## The cells that count as facing this character. Behind a counter the
## character can't be walked up to, so the counter's cells count too.
var talk_cells: Array[Vector2i] = []


static func create(id: StringName, texture: Texture2D, cell: Vector2i) -> Npc:
	var npc := Npc.new()
	npc.name = String(id).capitalize().replace(" ", "")
	npc.npc_id = id
	npc.position = Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)
	npc.talk_cells = [cell]

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.offset = SPRITE_OFFSET
	npc.add_child(sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	npc.add_child(shape)
	return npc


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return cell in talk_cells


func interact() -> void:
	EventBus.npc_talked_to.emit(npc_id)
