class_name Facing
extends RefCounted
##
## Facing — which way someone faces when moving in a direction, and which of
## their animations to play for it (Stage 24, DECISIONS 074). Shared by the
## farmer (Player) and the townsfolk walking about (Npc), so both follow one
## rule.
##
## Eight facings, named like the animations: down, down_right, right,
## up_right, up, up_left, left, down_left. A character's SpriteFrames may only
## have the four straight ones (every sheet today); then a diagonal shows the
## nearest straight one, chosen exactly as before eight-way facing existed
## (four_way(): the larger part of the movement wins, and a perfect diagonal
## reads as up or down). So the art can arrive person by person, with no code
## change when it does.
##
## Tools always use the straight facing: the cell straight ahead is what a
## hoe acts on, so a diagonal never reaches a corner cell (ROADMAP section
## 15). E tries that cell first too, then reaches round about, all eight ways
## (Player._reach_cells, DECISIONS 079).
##

const STRAIGHT: Dictionary = {
	&"down": Vector2i.DOWN,
	&"up": Vector2i.UP,
	&"left": Vector2i.LEFT,
	&"right": Vector2i.RIGHT,
}

## The eight facings, going clockwise from right (screen y points down), so
## index = the direction's angle in eighths of a turn.
const EIGHT: Array[StringName] = [
	&"right", &"down_right", &"down", &"down_left",
	&"left", &"up_left", &"up", &"up_right",
]


## The nearest of the eight facings to `direction` (not zero).
static func eight_way(direction: Vector2) -> StringName:
	var eighth := roundi(direction.angle() / (TAU / 8.0))
	return EIGHT[posmod(eighth, 8)]


## The nearest of the four straight facings: the larger part of the movement
## wins, and a perfect diagonal reads as up or down (the rule the farmer has
## had since Stage 1).
static func four_way(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"


## The animation to play: "<kind>_<facing>" when `frames` has it, else the
## straight facing's ("walk_down_right", or "walk_down" when there's none).
static func animation(frames: SpriteFrames, kind: String, facing: StringName,
		straight: StringName) -> StringName:
	var wanted := StringName("%s_%s" % [kind, facing])
	if frames != null and frames.has_animation(wanted):
		return wanted
	return StringName("%s_%s" % [kind, straight])
