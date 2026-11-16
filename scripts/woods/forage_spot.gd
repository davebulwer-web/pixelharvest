class_name ForageSpot
extends Node2D
##
## ForageSpot — something wild lying on one tile, waiting to be picked up with
## E: a mushroom, a handful of berries (DECISIONS 052).
##
## Like the shipping bin it joins the "interactable" group, so the player's E
## key needs nothing new. It isn't solid: you can walk over a mushroom, and
## pick it up facing it. Picking it is GameState's (it goes in the bag and is
## remembered for the rest of the day); this node is only the picture.
##
## The origin is the bottom-middle of its tile, like everything on a map.
##

const TILE_PX := 16

var location_id: StringName
var cell: Vector2i
var forage: ForageDef


static func create(where: StringName, at: Vector2i, what: ForageDef) -> ForageSpot:
	var spot := ForageSpot.new()
	spot.name = "Forage_%d_%d" % [at.x, at.y]
	spot.location_id = where
	spot.cell = at
	spot.forage = what
	spot.position = Vector2(at.x * TILE_PX + TILE_PX / 2.0, (at.y + 1) * TILE_PX)

	# A soft shadow under it, so it sits on the grass rather than floating.
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.22)
	var points := PackedVector2Array()
	for k in 12:
		var angle := TAU * k / 12.0
		points.append(Vector2(cos(angle) * 5.0, -2.0 + sin(angle) * 1.6))
	shadow.polygon = points
	spot.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = what.icon
	sprite.offset = Vector2(0, -8)
	spot.add_child(sprite)
	return spot


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(at: Vector2i) -> bool:
	return at == cell


func interact() -> void:
	GameState.forage(location_id, cell, forage)
	queue_free()
