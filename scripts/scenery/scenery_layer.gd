@tool
class_name SceneryLayer
extends Node2D
##
## SceneryLayer — the root of one of Dave's scenery scenes, scenery/<map>.tscn
## (DECISIONS 082). Dave opens that scene in the Godot editor and drags
## pictures into it; the game adds them to the map when the map opens
## (Scenery, which does everything at play time). The pictures are only looks:
## nothing about them is saved, and no rule reads them.
##
## The scene's four groups, child nodes of this root:
##   OnTheGround  flat things, always under the farmer: rugs, puddles, flowers
##   Standing     upright things the farmer walks in front of and behind
##   Solid        like Standing, but the farmer bumps into the foot of each one
##   Overhead     always over everyone: bunting, string lights, branches
## A picture dropped straight onto the root counts as Standing.
##
## This script only helps in the editor:
## - it shows the map behind the pictures (the backdrop, a snapshot of the map
##   taken in the game with Ctrl+B; it is never saved into the scene) and the
##   map's edge, so Dave can see where things go;
## - it moves each new picture's origin to its feet (bottom middle), which is
##   what the game sorts people and things by, without moving the picture;
## - a picture named ..._4f.png (4 frames side by side) shows its first frame.
##

## Which map this scenery belongs to: the name of scenery/<map>.tscn, and of
## its backdrop picture.
@export var map_id: StringName = &""
## The map's size in tiles, for the outline when there's no backdrop yet.
@export var map_size: Vector2i = Vector2i(48, 32)

const BACKDROP_DIR := "res://scenery/backdrops/"
const TILE_PX := 16
const EDGE_COLOUR := Color(1.0, 0.85, 0.2, 0.9)
## The meta flag a picture gets once its origin is at its feet, so it's only
## done once (Dave can move the origin back by hand if he wants).
const TIDY_META := &"scenery_tidy"
## "..._4f.png", "..._pingpong_3f.png": a strip of that many frames.
const FRAMES_PATTERN := "_(\\d+)f\\.[A-Za-z0-9]+$"

static var _frames_regex: RegEx

## Where the map is, in pixels (from the backdrop, else map_size).
var _map_rect := Rect2()


## How many frames side by side `texture`'s file name says it has (1 if it
## doesn't say, or the width doesn't divide).
static func frames_in(texture: Texture2D) -> int:
	if texture == null or texture.resource_path.is_empty():
		return 1
	if _frames_regex == null:
		_frames_regex = RegEx.create_from_string(FRAMES_PATTERN)
	var found := _frames_regex.search(texture.resource_path.get_file())
	if found == null:
		return 1
	var frames := int(found.get_string(1))
	if frames < 2 or texture.get_width() % frames != 0:
		return 1
	return frames


## The size of one frame of `sprite`'s picture.
static func frame_size(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.ZERO
	if sprite.region_enabled:
		return sprite.region_rect.size / Vector2(sprite.hframes, sprite.vframes)
	return Vector2(sprite.texture.get_size()) / Vector2(sprite.hframes, sprite.vframes)


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_map_rect = Rect2(Vector2.ZERO, Vector2(map_size * TILE_PX))
	_show_backdrop()
	get_tree().node_added.connect(_on_node_added)
	# Pictures added before this script was here (or by hand) get tidied too.
	for node in find_children("*", "Sprite2D", true, false):
		_tidy(node)
	queue_redraw()


func _exit_tree() -> void:
	if Engine.is_editor_hint() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(_map_rect, EDGE_COLOUR, false, 1.0)


## The snapshot of the map behind everything, if one has been taken. It's an
## internal child: the editor never saves it and it can't be clicked, so it
## works like a locked tracing paper.
func _show_backdrop() -> void:
	var picture := BACKDROP_DIR + "%s.png" % map_id
	var texture: Texture2D = null
	if ResourceLoader.exists(picture):
		texture = load(picture) as Texture2D
	elif FileAccess.file_exists(picture):
		# Just taken and not imported yet: read the file itself.
		var image := Image.load_from_file(ProjectSettings.globalize_path(picture))
		if image != null:
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		return
	var origin := Vector2.ZERO
	var where := BACKDROP_DIR + "%s.json" % map_id
	if FileAccess.file_exists(where):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(where))
		if parsed is Dictionary and parsed.has("origin"):
			origin = Vector2(parsed["origin"][0], parsed["origin"][1])
	var backdrop := Sprite2D.new()
	backdrop.name = "Backdrop"
	backdrop.texture = texture
	backdrop.centered = false
	backdrop.position = origin
	backdrop.z_index = -100
	add_child(backdrop, false, Node.INTERNAL_MODE_FRONT)
	_map_rect = Rect2(origin, texture.get_size())


func _on_node_added(node: Node) -> void:
	if node is Sprite2D and is_ancestor_of(node):
		# Deferred: the editor sets the dropped picture's position after it
		# adds the node.
		_tidy.call_deferred(node)


## Put a picture's origin at its feet and show one frame of a strip, leaving
## the picture where it is on screen.
func _tidy(node: Node) -> void:
	var sprite := node as Sprite2D
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return
	if sprite.has_meta(TIDY_META) or sprite.get_parent() == null:
		return
	var frames := frames_in(sprite.texture)
	if frames > 1 and sprite.hframes == 1:
		sprite.hframes = frames
	var size := frame_size(sprite)
	if sprite.centered:
		sprite.centered = false
		sprite.offset = Vector2(-floorf(size.x / 2.0), -size.y)
		sprite.position.y += floorf(size.y / 2.0)
	sprite.position = sprite.position.round()
	sprite.set_meta(TIDY_META, true)
