extends Node2D
##
## TileCursor — a thin outline on every tile the player will act on: one tile
## normally, three or nine with an upgraded tool.
##
## Drawn in code rather than as a sprite because it's a UI aid, not art, and
## a 1px rectangle doesn't warrant an asset. The farm scene tells it which
## cells to outline each frame; it only redraws when they change.
##

const TILE_PX := 16
## The lightest colour in art/palette.png, so it stays on-palette.
const OUTLINE := Color8(255, 231, 216, 200)

var _cells: Array[Vector2i] = []


func set_cells(cells: Array[Vector2i]) -> void:
	if cells == _cells:
		return
	_cells = cells
	queue_redraw()


func _draw() -> void:
	for cell in _cells:
		var corner := Vector2(cell * TILE_PX)
		draw_rect(Rect2(corner + Vector2(0.5, 0.5), Vector2(TILE_PX - 1, TILE_PX - 1)), OUTLINE, false, 1.0)
