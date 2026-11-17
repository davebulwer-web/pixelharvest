class_name ExitDef
extends Resource
##
## ExitDef — one way out of an outdoor place to the next (DECISIONS 060): the
## farm's gate to the Lane, the Lane's two ends, the town's road east.
##
## Until Stage 19 every map had its own gate constants and its own few lines
## of code to make the way out (FarmLayout.TOWN_GATE, TownLayout.FARM_GATE…).
## With the Lane, the Cove and the coast road coming, that would be a new
## pair of constants and a new function for every road. Now a way out is
## data on the place's LocationDef (`exits`), and Exits (scripts/exits.gd)
## turns each one into the gap in the edge, the zone that takes you through,
## and the spot where you stand when you come back in.
##
## The names follow one rule, so the two ends of a road never need to name
## each other's spawn points: leaving `here` for `to` arrives at the spawn
## point "from_<here>" in `to`, and every exit makes the spawn point
## "from_<to>" here, at `arrival`.
##

## The place this leads to, by LocationDef id.
@export var to: StringName

## The cells of the gap, just outside the map's edge (x = -1 for the west
## edge, y = the height for the bottom edge…): walking into any of them
## leaves. Two cells, side by side, so the player needn't line up exactly.
## The map draws them as path.
@export var cells: Array[Vector2i] = []

## The cell, just inside the gap, where someone coming in this way stands.
@export var arrival: Vector2i
