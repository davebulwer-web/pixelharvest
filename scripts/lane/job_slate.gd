class_name JobSlate
extends StaticBody2D
##
## JobSlate — the allotment holders' slate by their gate on the Lane
## (DECISIONS 062), where odd jobs are chalked up. Face it and press E.
##
## Like the notice board it's only a presence: a picture, something to bump
## into, and answering E by announcing that it was spoken to, as a person
## would be (EventBus.npc_talked_to, with Quests.ALLOTMENTS for its id). The
## Lane says what's on it: the jobs up today, or the one in hand.
##

const TILE_PX := 16
const PICTURE: Texture2D = preload("res://assets/sprites/lane/job_slate.png")

## How high its request marker floats above its base.
const MARKER_HEIGHT := 40


## A slate standing on `cell` (the middle of its two posts).
static func create(cell: Vector2i) -> JobSlate:
	var slate := JobSlate.new()
	slate.name = "JobSlate"
	slate.position = Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)
	var sprite := Sprite2D.new()
	sprite.texture = PICTURE
	sprite.offset = Vector2(0, -PICTURE.get_height() / 2.0 + 1)
	slate.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(26, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	slate.add_child(shape)
	return slate


func _ready() -> void:
	add_to_group(&"interactable")


## Two tiles wide like the notice board: facing its own cell or either
## neighbour counts.
func occupies(cell: Vector2i) -> bool:
	var home := Vector2i((position - Vector2(0, 1)) / TILE_PX)
	return cell.y == home.y and absi(cell.x - home.x) <= 1


func interact() -> void:
	EventBus.npc_talked_to.emit(Quests.ALLOTMENTS)
