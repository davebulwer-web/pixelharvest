class_name InteriorLook
extends RefCounted
##
## InteriorLook — the rooms you walk into (the four shops, the farmhouse,
## the tavern: DECISIONS 083; the townsfolk's homes: 084) furnished from the
## Cozy Interiors pack,
## built by art/build_interior_look.py into assets/packs/interiors/. That
## folder is kept out of git (the pack's licence; the repository is public),
## so on a copy without it nothing here changes anything.
##
## Only looks: each room gets one baked picture of its walls, floor and rugs
## laid over our tiles, and the pack's furniture, lights and wall hangings as
## pieces standing in it. Where a pack piece stands in for one of ours (the
## shop counter, the bed, the bar ...) our sprite is hidden and everything it
## does stays: its collision, E at it, the keeper behind it. A few new pieces
## along the walls are solid, so you can't walk through a barrel; none is
## where anyone needs to stand or walk. Nothing is saved.
##
## Ctrl+R in a room flips it, to compare (never saved). If a room's size or
## door ever stops matching what the pictures were built for, the room is left
## as ours rather than shown wrong.
##

const DIR := "res://assets/packs/interiors/"
const DATA := DIR + "interior_look.json"
const TILE_PX := 16
## Hanging lights are drawn over people, as the pack asks.
const ABOVE_Z := 20
## Windows show their night picture from 7 PM until 6 AM.
const NIGHT_FROM := 19 * 60
const NIGHT_UNTIL := 6 * 60

static var on := true

static var _data: Dictionary = {}
static var _loaded := false


## Whether the interiors have been built on this copy of the game.
static func has_pack() -> bool:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(DATA):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
			if parsed is Dictionary:
				_data = parsed
	return not _data.is_empty()


## Furnish `room` (the room's root node, whose y-sorted things are under
## `entities`) as the pack's room `key`, if it was built for a room of `size`
## with its door on `door` (the door's two cells' x).
static func dress(room: Node2D, entities: Node2D, key: StringName, size: Vector2i, door: Array) -> void:
	if not has_pack():
		return
	var spec: Dictionary = _data.get("rooms", {}).get(String(key), {})
	if spec.is_empty():
		return
	if Vector2i(spec["size"][0], spec["size"][1]) != size or int(spec["door"][0]) != int(door[0]):
		push_warning("InteriorLook: %s has changed shape since its pictures were built; showing ours" % key)
		return

	var holder := Node2D.new()
	holder.name = "InteriorLook"
	room.add_child(holder)
	holder.add_child(_Switch.new())

	# The walls and floor: one picture over our tiles, under everything else.
	var background := Sprite2D.new()
	background.name = "Room"
	background.texture = load(DIR + spec["background"])
	background.centered = false
	background.position = Vector2(-TILE_PX, -TILE_PX)
	background.z_index = -1
	background.add_to_group(&"interior_look")
	holder.add_child(background)

	var night := GameState.minutes >= NIGHT_FROM or GameState.minutes < NIGHT_UNTIL
	for item: Dictionary in spec.get("pieces", []):
		var piece := _make_piece(item, night)
		if piece != null:
			piece.add_to_group(&"interior_look")
			entities.add_child(piece)

	# Ours that the pack's pieces stand in for: hidden while it's on.
	var hide: Array = spec.get("hide", [])
	for sprite in _sprites_under(entities):
		if sprite.texture != null and sprite.texture.resource_path in hide:
			sprite.add_to_group(&"interior_look_ours")
	_show()


static func _sprites_under(node: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D:
			out.append(child)
		out.append_array(_sprites_under(child))
	return out


## One piece: its picture's bottom-left on its cell's bottom-left, lifted by
## `lift` pixels (things on the wall), animated if it's a strip.
static func _make_piece(item: Dictionary, night: bool) -> Node2D:
	var file: String = item["picture"]
	if night and item.has("night"):
		file = item["night"]
	var tex := load(DIR + file) as Texture2D
	if tex == null:
		return null
	var width := float(item.get("width", tex.get_width()))
	var lift := float(item.get("lift", 0))
	var frames := int(item.get("frames", 1))
	var cell := Vector2(item["cell"][0], item["cell"][1])

	var body: Node2D
	if item.get("solid", false):
		# Solid along its foot: one row, or `depth` rows for something deep
		# (a bed, a wardrobe: DECISIONS 084).
		var depth := float(item.get("depth", 1)) * TILE_PX
		var solid := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(width, depth)
		shape.shape = box
		shape.position = Vector2(0, -depth / 2.0)
		solid.add_child(shape)
		body = solid
	else:
		body = Node2D.new()
	body.name = "Pack_%s" % file.get_basename()
	body.position = Vector2(cell.x * TILE_PX + width / 2.0, (cell.y + 1) * TILE_PX)
	if item.get("above", false):
		body.z_index = ABOVE_Z

	if frames > 1:
		var sprite_frames := SpriteFrames.new()
		for f in frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(f * width, 0, width, tex.get_height())
			sprite_frames.add_frame(&"default", atlas)
		sprite_frames.set_animation_speed(&"default", float(item.get("fps", 6)))
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sprite_frames
		anim.offset = Vector2(0, -tex.get_height() / 2.0 - lift)
		anim.play(&"default")
		body.add_child(anim)
	else:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 - lift)
		body.add_child(sprite)
	return body


## Show the pack's room or ours, as `on` says. Collision never changes, except
## the few new solid pieces, which go with the look.
static func _show() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"interior_look"):
		node.visible = on
		if node is StaticBody2D:
			(node as StaticBody2D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for node in tree.get_nodes_in_group(&"interior_look_ours"):
		node.visible = not on


## Listens for Ctrl+R while the room is open.
class _Switch extends Node:
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"swap_interior_look"):
			InteriorLook.on = not InteriorLook.on
			InteriorLook._show()
			get_viewport().set_input_as_handled()
