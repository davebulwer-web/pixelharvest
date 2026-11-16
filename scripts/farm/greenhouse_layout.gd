class_name GreenhouseLayout
extends RefCounted
##
## GreenhouseLayout — the shape of the room inside the farm's greenhouse, and
## the plot it holds (DECISIONS 057).
##
## The room, in cells (the back wall is the top two rows):
##
##       wall top  . . . . . . . . . .
##       wall face ░ ░ ░ ░ ░ ░ ░ ░ ░ ░       y 0-1
##       walkway                              y 2
##       walkway ▓ ▓ ▓ ▓ ▓ ▓ ▓ ▓ walkway      y 3-8: the plot, x 1-8
##       walkway                              y 9
##       door ──────── ▒▒ ────────            y 10 (x 4-5)
##
## The plot is 8 tiles wide and 6 deep (ROADMAP's "6 × 8"), with a walkway all
## round it so every tile can be reached from the side as well as from above.
## Only the plot is in the FarmData: the walkway, the walls and the door are
## the room's, drawn by the greenhouse scene, and no tool can touch them.
##
## Like FarmLayout, this builds a fresh plot for a new game. After that the
## plot lives in GameState and the save, like the farm.
##

const ROOM := Vector2i(10, 10)
const PLOT := Rect2i(1, 3, 8, 6)
const DOOR_CELLS: Array[int] = [4, 5]


## A new, empty plot: every tile dug over and ready for seed, so the first
## visit is planting, not hoeing. Under glass, so it ignores the seasons.
static func build_default() -> FarmData:
	var plot := FarmData.new(PLOT.size)
	plot.under_glass = true
	for y in range(PLOT.position.y, PLOT.end.y):
		for x in range(PLOT.position.x, PLOT.end.x):
			var t := FarmTile.new()
			t.tilled = true
			plot.set_tile(Vector2i(x, y), t)
	return plot
