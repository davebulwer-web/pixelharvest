class_name Scenery
extends Node
##
## Scenery — puts Dave's scenery into a map when it opens (DECISIONS 082).
##
## Dave drags pictures into scenery/<map>.tscn in the Godot editor (its root
## is a SceneryLayer, which explains the groups). Each outdoor map calls
## Scenery.add_to() at the end of its _ready(), and this node then:
##
## - adds the scene to the map: OnTheGround just above the ground and under
##   everyone, Standing and Solid among the people and objects (sorted by
##   their feet, like the farmer), Overhead over everyone;
## - gives each picture in Solid a small block at its foot that the farmer
##   bumps into (townsfolk walk through it: they don't collide);
## - plays animation strips (a picture named ..._4f.png, 4 frames side by
##   side; ..._pingpong_3f.png goes there and back); a picture named
##   ..._on_off_2f.png (string lights) shows its lit frame after dark;
## - swaps a seasonal picture for this season's (oak_summer.png becomes
##   oak_winter.png in winter when that file is beside it);
## - takes a new backdrop (Ctrl+B, only when the game is run from the editor):
##   a picture of the whole map without the farmer, the day's light or the
##   scenery, saved as scenery/backdrops/<map>.png for the editor to show.
##
## The scenery is only looks: nothing about it is saved and no rule reads it,
## so a missing or broken scene leaves the map exactly as it was.
##

const DIR := "res://scenery/"
const BACKDROP_DIR := SceneryLayer.BACKDROP_DIR
const TILE_PX := SceneryLayer.TILE_PX
## Drawn over people, like PackLook's bunting (DECISIONS 081).
const OVERHEAD_Z := 20
## Seconds per frame: two-frame pictures (grass, lanterns) sway slowly.
const FRAME_SECONDS := 0.2
const TWO_FRAME_SECONDS := 0.5
## When string lights are lit (minutes after midnight): 19:30 to 06:30.
const LIT_FROM := 1170
const LIT_UNTIL := 390
## The farmer bumps into a block this tall at a Solid picture's foot.
const FOOT_HEIGHT := 6.0
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const GROUPS: Array[StringName] = [&"OnTheGround", &"Standing", &"Solid", &"Overhead"]

var map_id: StringName = &""
var _map: Node2D
var _entities: Node2D
## The scene Dave made, once it's in the map (null if there isn't one).
var _layer: Node2D
## Its Standing and Solid groups, which live among the map's entities.
var _among: Array[Node2D] = []
## Every picture in it, for the season swap.
var _pictures: Array[Sprite2D] = []
## The animated ones: {sprite, frames, seconds, pingpong, lights, phase}.
var _moving: Array[Dictionary] = []
var _clock := 0.0
var _taking := false


## Add map `map_id`'s scenery to `map`, sorting Standing and Solid among
## `entities` (the map's y-sorted node). Safe to call when there's none.
static func add_to(map: Node2D, entities: Node2D, id: StringName) -> Scenery:
	var scenery := Scenery.new()
	scenery.name = "Scenery"
	scenery.map_id = id
	scenery._map = map
	scenery._entities = entities
	map.add_child(scenery)
	scenery._load()
	return scenery


func _load() -> void:
	var path := DIR + "%s.tscn" % map_id
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Dave's scenery: %s didn't load (a picture missing from assets/scenery/?)" % path)
		return
	_layer = packed.instantiate() as Node2D
	if _layer == null:
		return
	_layer.name = "DavesScenery"
	_map.add_child(_layer)
	# Just before Entities: drawn after the ground, before everyone standing.
	_map.move_child(_layer, _entities.get_index())
	var standing := _group(&"Standing")
	var solid := _group(&"Solid")
	# A picture dropped straight onto the root counts as Standing.
	for child in _layer.get_children():
		if child is CanvasItem and not GROUPS.has(StringName(child.name)):
			child.reparent(standing)
	for node in _layer.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		_pictures.append(sprite)
		_season(sprite)
		_animate(sprite)
	for node in solid.find_children("*", "Sprite2D", true, false):
		_make_solid(node as Sprite2D)
	# Standing and Solid join the map's y-sort: a y-sorted node inside a
	# y-sorted node sorts its children with everyone else's, by their feet.
	for group: Node2D in [standing, solid]:
		group.y_sort_enabled = true
		group.reparent(_entities)
		_among.append(group)
	_group(&"Overhead").z_index = OVERHEAD_Z
	EventBus.season_changed.connect(_on_season_changed)


## One of the scene's groups, made empty if Dave deleted it.
func _group(group_name: StringName) -> Node2D:
	var group := _layer.get_node_or_null(NodePath(String(group_name))) as Node2D
	if group == null:
		group = Node2D.new()
		group.name = group_name
		_layer.add_child(group)
	return group


func _on_season_changed(_season_index: int) -> void:
	for sprite in _pictures:
		if is_instance_valid(sprite):
			_season(sprite)


## oak_summer.png -> oak_winter.png, when this season's picture is there.
func _season(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.texture.resource_path.is_empty():
		return
	var theme := GameState.current_season_theme()
	if theme == null:
		return
	var now := String(theme.id)
	var path := sprite.texture.resource_path
	var file := path.get_file()
	for season in SEASONS:
		if season == now or not file.contains(season):
			continue
		var other := path.get_base_dir().path_join(file.replace(season, now))
		if ResourceLoader.exists(other):
			sprite.texture = load(other) as Texture2D
			var frames := SceneryLayer.frames_in(sprite.texture)
			sprite.hframes = frames
			sprite.frame = 0
		return


func _animate(sprite: Sprite2D) -> void:
	var frames := SceneryLayer.frames_in(sprite.texture)
	if frames < 2:
		return
	if sprite.hframes != frames:
		sprite.hframes = frames
	var file := sprite.texture.resource_path.get_file()
	var seconds := TWO_FRAME_SECONDS if frames == 2 else FRAME_SECONDS
	_moving.append({
		"sprite": sprite,
		"frames": frames,
		"seconds": seconds,
		"pingpong": file.contains("pingpong"),
		"lights": file.contains("on_off"),
		# Each starts at its own point, so a row of buoys doesn't bob as one.
		"phase": randf() * seconds * frames,
	})


func _process(delta: float) -> void:
	if _moving.is_empty():
		return
	_clock += delta
	var lit := GameState.minutes >= LIT_FROM or GameState.minutes < LIT_UNTIL
	for moving: Dictionary in _moving:
		var sprite: Sprite2D = moving["sprite"]
		if not is_instance_valid(sprite):
			continue
		var frames: int = moving["frames"]
		if moving["lights"]:
			# The packs draw these lit first, then unlit.
			sprite.frame = 0 if lit else 1
			continue
		var step := int((_clock + moving["phase"]) / moving["seconds"])
		if moving["pingpong"]:
			var span := frames * 2 - 2
			step %= span
			sprite.frame = step if step < frames else span - step
		else:
			sprite.frame = step % frames


## A block at the picture's foot, the width of the picture less a little, so
## the farmer bumps into it like a fence post rather than its whole picture.
func _make_solid(sprite: Sprite2D) -> void:
	var size := SceneryLayer.frame_size(sprite)
	if size == Vector2.ZERO:
		return
	var foot := RectangleShape2D.new()
	foot.size = Vector2(maxf(size.x - 4.0, 4.0), minf(FOOT_HEIGHT, size.y))
	var bottom := sprite.offset.y + (size.y / 2.0 if sprite.centered else size.y)
	var middle := sprite.offset.x + (0.0 if sprite.centered else size.x / 2.0)
	var shape := CollisionShape2D.new()
	shape.shape = foot
	shape.position = Vector2(middle, bottom - foot.size.y / 2.0)
	var body := StaticBody2D.new()
	body.name = "Foot"
	body.add_child(shape)
	sprite.add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"scenery_backdrop") and OS.has_feature("editor") and not _taking:
		get_viewport().set_input_as_handled()
		_take_backdrop()


## Photograph the whole map at its true size into scenery/backdrops/, for the
## scenery scene to show behind Dave's pictures. A second viewport looks at
## the same world as the screen, so nothing has to move; the farmer, the
## day's light, the weather and the scenery itself are hidden for the moment
## it takes.
func _take_backdrop() -> void:
	var ground := _map.get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return
	_taking = true
	var cells := ground.get_used_rect()
	var area := Rect2i(cells.position * TILE_PX, cells.size * TILE_PX)
	var hidden: Array[CanvasItem] = []
	for node in _hide_for_backdrop():
		if node.visible:
			node.visible = false
			hidden.append(node)
	var camera := SubViewport.new()
	camera.size = area.size
	camera.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# In the tree first: a viewport can only swap worlds once it's in one.
	add_child(camera)
	camera.world_2d = get_viewport().world_2d
	camera.canvas_transform = Transform2D(0.0, Vector2(-area.position))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := camera.get_texture().get_image()
	camera.queue_free()
	for node in hidden:
		node.visible = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKDROP_DIR))
	var picture := BACKDROP_DIR + "%s.png" % map_id
	var error := image.save_png(ProjectSettings.globalize_path(picture))
	var where := FileAccess.open(BACKDROP_DIR + "%s.json" % map_id, FileAccess.WRITE)
	if where != null:
		where.store_string(JSON.stringify({"origin": [area.position.x, area.position.y]}))
		where.close()
	_taking = false
	var words := "Backdrop saved: %s" % picture if error == OK else "Backdrop not saved (error %d)" % error
	print(words)
	_say(words)


func _hide_for_backdrop() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	var farmer := _entities.get_node_or_null("Player") as CanvasItem
	if farmer != null:
		nodes.append(farmer)
	for node in _map.find_children("*", "CanvasModulate", true, false):
		nodes.append(node as CanvasItem)
	var weather := _map.get_node_or_null("Weather")
	if weather != null:
		for node in weather.get_children():
			if node is CanvasItem:
				nodes.append(node)
	var cursor := _map.get_node_or_null("TileCursor") as CanvasItem
	if cursor != null:
		nodes.append(cursor)
	if _layer != null:
		nodes.append(_layer)
		nodes.append_array(_among)
	return nodes


## A line on screen for a moment (the backdrop's done).
func _say(words: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var label := Label.new()
	label.text = words
	label.position = Vector2(8, 300)  # above the hotbar, clear of the HUD
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(label)
	add_child(layer)
	get_tree().create_timer(3.0).timeout.connect(layer.queue_free)
