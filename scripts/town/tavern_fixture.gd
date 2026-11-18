class_name TavernFixture
extends StaticBody2D
##
## TavernFixture — something on the Wheatsheaf's back wall you face and press
## E at (DECISIONS 068): Nell's chalkboard and the dartboard. Like the notice
## board, it's only the thing's presence (its picture and which cells count
## as facing it); the tavern's room says what happens (`used`).
##

const TILE_PX := 16

## Pressed E while facing it.
signal used

## The cells that count as facing it: the wall cells it hangs on.
var cells: Array[Vector2i] = []


## A fixture showing `texture`, hung on the wall with its bottom edge at the
## bottom of `cells`' row, centred across them.
static func create(fixture_name: String, texture: Texture2D, wall_cells: Array[Vector2i]) -> TavernFixture:
	var fixture := TavernFixture.new()
	fixture.name = fixture_name
	fixture.cells = wall_cells
	var left := wall_cells[0]
	fixture.position = Vector2(left.x * TILE_PX + wall_cells.size() * TILE_PX / 2.0, (left.y + 1) * TILE_PX)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	fixture.add_child(sprite)
	return fixture


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(cell: Vector2i) -> bool:
	return cell in cells


func interact() -> void:
	used.emit()
