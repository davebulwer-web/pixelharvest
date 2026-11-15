class_name Building
extends StaticBody2D
##
## Building — a building's front on a map (a shop in town, the farmhouse on
## the farm): its picture, solid walls, and a
## door you walk into.
##
## Made entirely from a LocationDef (its exterior picture and door cell), so
## the town's code never names a shop. The node's origin is the bottom-middle
## of the door cell, like every other thing standing on a map (main.gd,
## cell_base), which makes the picture's bottom edge sit on the ground and
## lets the player walk behind a roof but in front of a doorstep.
##
## The picture is solid except the doorway, which is two tiles wide (32px, the
## door cell and half of each neighbour): wide enough that the player doesn't
## have to line up to the pixel. That gap is the ExitZone into the shop.
##

const TILE_PX := 16


static func create(def: LocationDef) -> Building:
	var building := Building.new()
	building.name = String(def.id)
	building.position = Vector2(def.door_cell.x * TILE_PX + TILE_PX / 2.0, (def.door_cell.y + 1) * TILE_PX)

	var texture := def.exterior
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.offset = Vector2(0, -height / 2.0)
	building.add_child(sprite)

	var half_door := float(TILE_PX)  # half the 32px doorway
	# Left of the doorway, right of it, and the wall above it.
	building._add_wall(Rect2(-width / 2.0, -height, width / 2.0 - half_door, height))
	building._add_wall(Rect2(half_door, -height, width / 2.0 - half_door, height))
	building._add_wall(Rect2(-half_door, -height, half_door * 2.0, height - TILE_PX))

	building.add_child(ExitZone.create(
			Rect2(-half_door, -TILE_PX, half_door * 2.0, TILE_PX), def.id, &"door"))
	return building


## The cells the building's picture covers, on the map it stands on: centred on
## the door cell, with the door in the bottom row. The farm uses this to keep
## those cells out of the hoe's reach (FarmLayout); nothing is saved from it.
static func footprint(def: LocationDef) -> Rect2i:
	var cells_wide := ceili(def.exterior.get_width() / float(TILE_PX))
	var cells_tall := ceili(def.exterior.get_height() / float(TILE_PX))
	return Rect2i(def.door_cell.x - cells_wide / 2, def.door_cell.y - cells_tall + 1, cells_wide, cells_tall)


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	add_child(shape)
