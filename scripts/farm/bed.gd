class_name Bed
extends StaticBody2D
##
## Bed — where the day ends. Face it and press E, and TimeSystem runs the night.
##
## It's an "interactable" like the shipping bin: the player doesn't know what a
## bed is, it just finds something that occupies the cell ahead and calls
## interact(). The picture is one tile wide and two tall, head against the wall,
## and both tiles count, so the player can come at it from the side or the foot.
##

const TILE_PX := 16

## The two cells the bed covers: the head (top) and the foot.
var cells: Array[Vector2i] = []


## A bed whose foot is on `foot_cell`, shown with `texture`.
static func create(texture: Texture2D, foot_cell: Vector2i) -> Bed:
	var bed := Bed.new()
	bed.name = "Bed"
	var cells_tall := ceili(texture.get_height() / float(TILE_PX))
	for row in cells_tall:
		bed.cells.append(foot_cell - Vector2i(0, row))
	# Origin at the bottom-middle of the foot cell, like everything that stands
	# on a map, so it Y-sorts with the player.
	bed.position = Vector2(foot_cell.x * TILE_PX + TILE_PX / 2.0, (foot_cell.y + 1) * TILE_PX)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	bed.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE_PX, cells_tall * TILE_PX)
	shape.shape = box
	shape.position = Vector2(0, -box.size.y / 2.0)
	bed.add_child(shape)
	return bed


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return cell in cells


func interact() -> void:
	TimeSystem.end_day()
