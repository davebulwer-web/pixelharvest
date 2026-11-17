class_name AllotmentWeed
extends Sprite2D
##
## AllotmentWeed — one weed on an allotment bed that a job wants pulled
## (DECISIONS 062). Drawn by AllotmentBeds; E on it pulls it by hand
## (Allotments.pull_by_hand), as E pulls weeds on the farm.
##

const TILE_PX := 16

var cell: Vector2i


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(at: Vector2i) -> bool:
	return at == cell


func interact() -> void:
	Allotments.pull_by_hand(cell)
