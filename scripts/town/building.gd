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
## A shop with opening hours (DECISIONS 035) also has a closed door: a solid
## block across the top of the doorway, switched on whenever the shop is
## shut. It stops the player short of the doorway so they stay in front of
## the building instead of vanishing behind its front. It covers only the top
## of the door cell, so the player still touches the ExitZone below it and
## is told the opening hours.
##

const TILE_PX := 16

## How much of the door cell, from the top, the closed door fills. The rest
## is left so the player's feet can reach the ExitZone and hear it's shut.
const CLOSED_DOOR_DEPTH := 10.0

var _location_id: StringName = &""
var _closed_door: CollisionShape2D

## Where the pictures come from: the open one, and the broken one shown until
## the building is mended (LocationDef.locked_exterior; DECISIONS 057).
var _def: LocationDef


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
	building._def = def
	building._update_picture()

	var half_door := float(TILE_PX)  # half the 32px doorway
	# Left of the doorway, right of it, and the wall above it.
	building._add_wall(Rect2(-width / 2.0, -height, width / 2.0 - half_door, height))
	building._add_wall(Rect2(half_door, -height, width / 2.0 - half_door, height))
	building._add_wall(Rect2(-half_door, -height, half_door * 2.0, height - TILE_PX))

	building.add_child(ExitZone.create(
			Rect2(-half_door, -TILE_PX, half_door * 2.0, TILE_PX), def.id, &"door"))

	building._location_id = def.id
	building._closed_door = building._add_wall(
			Rect2(-half_door, -TILE_PX, half_door * 2.0, CLOSED_DOOR_DEPTH))
	building._closed_door.name = "ClosedDoor"
	building._closed_door.disabled = true
	return building


func _ready() -> void:
	_update_closed_door()
	EventBus.time_changed.connect(func(_minutes: int) -> void: _update_closed_door())
	# A building can also open up mid-day, when a request is handed in (DECISIONS 043).
	EventBus.unlocked.connect(func(_id: StringName) -> void:
		_update_closed_door()
		_update_picture()
	)


## Shut the doorway while the shop is closed, open it while it's open. A
## building waiting for an unlock (DECISIONS 043) is shut until it's earned.
## The farmhouse is never closed.
func _update_closed_door() -> void:
	if _closed_door == null:
		return
	var closed := LocationManager.closed_message(_location_id) != ""
	_closed_door.set_deferred(&"disabled", not closed)


## Show the building's picture: the broken one while it waits to be mended
## (the farm's old greenhouse, until Ivy's request; DECISIONS 057), and
## otherwise the season's own picture for it, by location id (winter's
## farmhouse has a snowy roof), or its usual one. All the same size, so the
## walls fit whichever is showing.
func _update_picture() -> void:
	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null or _def == null:
		return
	var mended := _def.locked_exterior == null or GameState.has_unlock(_def.requires_unlock)
	sprite.set_meta(&"base_texture", _def.exterior if mended else _def.locked_exterior)
	if mended:
		SeasonLook.skin_object(self, _def.id)
	else:
		sprite.texture = _def.locked_exterior


## The cells the building's picture covers, on the map it stands on: centred on
## the door cell, with the door in the bottom row. The farm uses this to keep
## those cells out of the hoe's reach (FarmLayout); nothing is saved from it.
static func footprint(def: LocationDef) -> Rect2i:
	var cells_wide := ceili(def.exterior.get_width() / float(TILE_PX))
	var cells_tall := ceili(def.exterior.get_height() / float(TILE_PX))
	return Rect2i(def.door_cell.x - cells_wide / 2, def.door_cell.y - cells_tall + 1, cells_wide, cells_tall)


func _add_wall(rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	add_child(shape)
	return shape
