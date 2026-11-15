class_name SheetAnimation
extends Sprite2D
##
## SheetAnimation — a Sprite2D whose picture may be a grid of equal frames
## (left to right, then top to bottom), played on a loop. Used by the town's
## fountain, whose bubbling water is a 3×3 sheet of 48×40 frames.
##
## The grid is worked out from the picture's size every frame rather than set
## once in the scene, because SeasonLook can swap the picture: winter's frozen
## fountain is a single 48×40 frame, so it simply stands still, and spring's
## sheet starts moving again. Nothing about the season is decided here.
##
## Only how the object looks; nothing in the game's state depends on it.
##

## The size of one frame. A picture exactly this size is a still picture.
@export var frame_size := Vector2i(48, 40)
## Frames per second.
@export var fps := 8.0

var _time := 0.0


func _process(delta: float) -> void:
	if texture == null:
		return
	var cols := maxi(1, texture.get_width() / frame_size.x)
	var rows := maxi(1, texture.get_height() / frame_size.y)
	if hframes != cols or vframes != rows:
		frame = 0  # back to a frame that exists in any grid before resizing it
		hframes = cols
		vframes = rows
	var count := cols * rows
	if count <= 1:
		return
	_time += delta
	frame = int(_time * fps) % count
