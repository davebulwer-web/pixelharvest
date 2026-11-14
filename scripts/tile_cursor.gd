extends Node2D
##
## TileCursor — a thin outline on the tile the player will act on.
##
## Drawn in code rather than as a sprite because it's a UI aid, not art, and
## a 1px rectangle doesn't warrant an asset. Position is set by the farm scene;
## this only knows how to draw itself at its own origin.
##

const TILE_PX := 16
## The lightest colour in art/palette.png, so it stays on-palette.
const OUTLINE := Color8(255, 231, 216, 200)


func _draw() -> void:
	draw_rect(Rect2(0.5, 0.5, TILE_PX - 1, TILE_PX - 1), OUTLINE, false, 1.0)
