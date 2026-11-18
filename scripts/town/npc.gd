class_name Npc
extends StaticBody2D
##
## Npc — a character standing in a place, who answers E.
##
## Like the shipping bin it joins the "interactable" group, so the player's E
## key needs no special case for people. All an Npc does is announce, on
## EventBus, that it was spoken to; what that leads to (a shop menu, a
## request) is up to whoever listens. This node holds a picture, a place to
## stand and which tiles count as "talking to me" — nothing else.
##
## The origin is the bottom-middle of the cell the character stands on.
##
## Walking (DECISIONS 067): PeopleHere hands an Npc a path, cell by cell, and
## it walks it at the townsfolk's pace, then says arrived. While walking it
## doesn't block the farmer (its body is switched off, so nobody gets stuck
## in a doorway), and it can still be talked to on whatever cell it's on.
## There are no walk cycles yet (Stage 24): the picture bobs and turns to
## face the way it's going.
##

const TILE_PX := 16

## Matches the player's sprite: a 56×56 frame with the feet 19px below centre.
const SPRITE_OFFSET := Vector2(0, -19)

## How high a request marker floats above the feet, in pixels.
const MARKER_HEIGHT := 54

var npc_id: StringName = &""

## The cells that count as facing this character. Behind a counter the
## character can't be walked up to, so the counter's cells count too.
var talk_cells: Array[Vector2i] = []

## Said when a walk ends (DECISIONS 067).
signal arrived

## The rest of the walk, in pixels, and the pace, in pixels a second.
var _path: Array[Vector2] = []
var _speed: float = 40.0
var _walked: float = 0.0


static func create(id: StringName, texture: Texture2D, cell: Vector2i) -> Npc:
	var npc := Npc.new()
	npc.name = String(id).capitalize().replace(" ", "")
	npc.npc_id = id
	npc.position = Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)
	npc.talk_cells = [cell]

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.offset = SPRITE_OFFSET
	npc.add_child(sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	npc.add_child(shape)
	return npc


func _ready() -> void:
	add_to_group(&"interactable")


## Give this character a small "!" or "?" floating over their head, bobbing
## gently, for requests (DECISIONS 038). Empty, and so invisible, until the
## scene sets its text from Quests.marker_for(). Townsfolk in town and
## shopkeepers behind a counter or stall wear the same one (DECISIONS 044).
func add_quest_marker() -> Label:
	return quest_marker_on(self, MARKER_HEIGHT)


## The same marker on anything standing on a map, floating `height` pixels
## above its base: the notice board wears one for its daily job (DECISIONS 050).
static func quest_marker_on(node: Node2D, height: int) -> Label:
	var marker := Label.new()
	marker.name = "QuestMarker"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(16, 14)
	marker.position = Vector2(-8, -height)
	UiStyle.style_label(marker, 12, UiStyle.HIGHLIGHT)
	node.add_child(marker)
	var bob := marker.create_tween().set_loops()
	bob.tween_property(marker, ^"position:y", -height - 2.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(marker, ^"position:y", float(-height), 0.5).set_trans(Tween.TRANS_SINE)
	return marker


func occupies(cell: Vector2i) -> bool:
	return cell in talk_cells


## The cell this character is standing on now.
func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_PX), floori((position.y - 1.0) / TILE_PX))


## Walk through `points` (each the bottom-middle of a cell, in the parent's
## coordinates) at `speed` pixels a second, then say arrived. A new walk
## replaces one under way.
func walk(points: Array[Vector2], speed: float) -> void:
	_path = points.duplicate()
	_speed = maxf(speed, 1.0)
	_set_solid(_path.is_empty())
	if _path.is_empty():
		arrived.emit()


func is_walking() -> bool:
	return not _path.is_empty()


func _physics_process(delta: float) -> void:
	if _path.is_empty():
		return
	var step := _speed * delta
	_walked += step
	while step > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0]
		var to_go := position.distance_to(target)
		if absf(target.x - position.x) > 0.5:
			var sprite := get_node_or_null(^"Sprite") as Sprite2D
			if sprite != null:
				sprite.flip_h = target.x < position.x
		if to_go <= step:
			position = target
			step -= to_go
			_path.remove_at(0)
		else:
			position += (target - position) / to_go * step
			step = 0.0
	talk_cells = [cell()]
	_bob()
	if _path.is_empty():
		_set_solid(true)
		arrived.emit()


## A little up-and-down while walking, in place of walk cycles.
func _bob() -> void:
	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	var lift := 0.0 if _path.is_empty() else -absf(sin(_walked / 6.0)) * 2.0
	sprite.offset = SPRITE_OFFSET + Vector2(0, roundf(lift))


func _set_solid(solid: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred(&"disabled", not solid)


func interact() -> void:
	EventBus.npc_talked_to.emit(npc_id)
