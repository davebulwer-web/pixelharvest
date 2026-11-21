class_name Ambience
extends Node
##
## Ambience — the little things that move by themselves on the outdoor maps,
## to make the world feel lived in (DECISIONS 088): smoke from the chimneys,
## windows lit after dark, butterflies, songbirds and gulls going over,
## leaves drifting down in autumn, sparkles on the water and the snow,
## ripples on the pond, a fish jumping, fireflies on summer nights.
##
## Decoration only. Nothing here is saved, no rule reads it, nothing can be
## bumped into or picked up, and turning it off (Settings → "Little
## animations", or Ctrl+Y) leaves the game exactly as it was.
##
## Where everything comes from:
## - What moves, where and when: one AmbientEffect file per kind in
##   data/ambience/effects/ (butterflies.tres, falling_leaves.tres ...).
## - Each building's chimneys and windows: data/ambience/buildings/<id>.tres
##   (BuildingAmbience), in pixels of its picture.
## - Shared numbers (smoke, window glow, a cap on how many): AmbienceRules,
##   data/ambience/ambience_rules.tres.
## - The pictures: the packs' (assets/scenery/ambient/ and creatures/, made by
##   art/build_scenery_library.py, kept out of git) and our own few in
##   assets/sprites/ambient/ (art/build_ambient_art.py). A picture that isn't
##   there means that one thing doesn't play; nothing else changes.
##
## Each map's Scenery.add_to() adds one of these (scripts/scenery/), so it
## arrives with Dave's scenery, on every outdoor map. Cheap by design: things
## only start inside the camera's view, there's a cap on how many move at
## once, they're plain Sprite2Ds moved from this one _process, and they're
## gone when they leave the screen or finish.
##

const RULES_PATH := "res://data/ambience/ambience_rules.tres"
const EFFECTS_DIR := "res://data/ambience/effects/"
const BUILDINGS_DIR := "res://data/ambience/buildings/"
const HALO_PICTURE := "res://assets/sprites/ambient/window_glow.png"
const TILE_PX := 16
## Butterflies, birds and leaves: over the people and things standing, under
## Dave's Overhead scenery and the bunting (z 20).
const ABOVE_Z := 15
## How far a wandering butterfly or firefly strays from where it started.
const WANDER_RANGE := 40.0
## Seconds to fade in and out.
const FADE := 1.2

## Read once per run and shared by every map.
static var _rules: AmbienceRules
static var _effects: Array[AmbientEffect] = []
static var _buildings: Dictionary = {}
static var _pictures: Dictionary = {}
static var _window_masks: Dictionary = {}

var map_id: StringName = &""
var _map: Node2D
var _entities: Node2D
var _ground: TileMapLayer
## Holders for the moving things: on the ground (sparkles, ripples, fish)
## and above everyone standing (butterflies, birds, leaves).
var _low: Node2D
var _high: Node2D
## Smoke and lit windows, on the buildings.
var _fixed: Array[CanvasItem] = []
var _smoke: Array[Sprite2D] = []
## What's moving now: {sprite, effect, frames, age, life, phase, home,
## velocity, heading}.
var _alive: Array[Dictionary] = []
var _clock := 0.0
var _additive: CanvasItemMaterial


## Add the little moving things to `map` (an outdoor map; `entities` is its
## y-sorted node). Safe on any map: with nothing set up for it, nothing moves.
static func add_to(map: Node2D, entities: Node2D, id: StringName) -> Ambience:
	_read_data()
	var ambience := Ambience.new()
	ambience.name = "Ambience"
	ambience.map_id = id
	ambience._map = map
	ambience._entities = entities
	map.add_child(ambience)
	ambience._build()
	return ambience


static func _read_data() -> void:
	if _rules != null:
		return
	_rules = load(RULES_PATH) as AmbienceRules
	if _rules == null:
		_rules = AmbienceRules.new()
	for file_name: String in ResourceLoader.list_directory(EFFECTS_DIR):
		var effect := load(EFFECTS_DIR + file_name) as AmbientEffect
		if effect != null:
			_effects.append(effect)
	for file_name: String in ResourceLoader.list_directory(BUILDINGS_DIR):
		var building := load(BUILDINGS_DIR + file_name) as BuildingAmbience
		if building != null:
			_buildings[building.location_id] = building


## A picture by path, or null if it isn't there (the packs' aren't in git).
static func picture(path: String) -> Texture2D:
	if not _pictures.has(path):
		_pictures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _pictures[path]


func _build() -> void:
	_ground = _map.get_node_or_null(^"Ground") as TileMapLayer
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_low = Node2D.new()
	_low.name = "AmbienceOnTheGround"
	_map.add_child(_low)
	# Just before Entities: over the ground, under everyone standing.
	_map.move_child(_low, _entities.get_index())
	_high = Node2D.new()
	_high.name = "AmbienceAbove"
	_high.z_index = ABOVE_Z
	_map.add_child(_high)
	_dress_buildings(_map)
	Settings.ambience_changed.connect(_show)
	_show(Settings.ambience)


func _show(on: bool) -> void:
	_low.visible = on
	_high.visible = on
	for node in _fixed:
		if is_instance_valid(node):
			node.visible = on
	if not on:
		for alive in _alive:
			(alive["sprite"] as Node).queue_free()
		_alive.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_ambience"):
		get_viewport().set_input_as_handled()
		Settings.set_ambience(not Settings.ambience)
		EventBus.message_posted.emit("Little animations: %s (Ctrl+Y, or Settings)."
				% ("on" if Settings.ambience else "off"))


# --- Chimneys and windows -------------------------------------------------------

## Smoke and night windows on every building of the map that has a file in
## data/ambience/buildings/.
func _dress_buildings(node: Node) -> void:
	for child in node.get_children():
		if child is Building:
			var def: BuildingAmbience = _buildings.get(StringName(child.name))
			if def != null:
				_dress(child as Building, def)
		elif child.get_child_count() > 0 and not child is Ambience:
			_dress_buildings(child)


func _dress(building: Building, def: BuildingAmbience) -> void:
	var sprite := building.get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var texture: Texture2D = sprite.get_meta(&"base_texture", sprite.texture)
	var size := Vector2(texture.get_size())
	# The picture's top-left corner, in the building's own space: it stands
	# on its bottom middle (Building).
	var corner := Vector2(-size.x / 2.0, -size.y)
	var smoke := picture(_rules.smoke_picture)
	if smoke != null:
		var frames := SceneryLayer.frames_in(smoke)
		var frame_height := float(smoke.get_height())
		for chimney in def.chimneys:
			var puff := Sprite2D.new()
			puff.name = "ChimneySmoke"
			puff.texture = smoke
			puff.hframes = frames
			puff.modulate.a = _rules.smoke_opacity
			# The strip's bottom sits just inside the chimney's mouth.
			puff.position = corner + Vector2(chimney) + Vector2(0.5, -frame_height / 2.0 + 5.0)
			puff.set_meta(&"phase", randf() * 3.0)
			building.add_child(puff)
			_smoke.append(puff)
			_fixed.append(puff)
	if def.windows.is_empty():
		return
	var mask := _window_mask(texture, def)
	if mask == null:
		return
	var glow := Sprite2D.new()
	glow.name = "LitWindows"
	glow.texture = mask
	glow.centered = false
	glow.position = corner
	glow.self_modulate = _rules.window_strength
	glow.modulate.a = 0.0  # Daylight sets it, darker by day, lit at night
	glow.add_to_group(Daylight.NIGHT_LIGHTS)
	building.add_child(glow)
	_fixed.append(glow)
	var halo := picture(HALO_PICTURE)
	if halo == null or _rules.window_halo <= 0.0:
		return
	for window in def.windows:
		var light := Sprite2D.new()
		light.name = "WindowHalo"
		light.texture = halo
		light.material = _additive
		light.position = corner + Vector2(window.get_center())
		light.scale = (Vector2(window.size) + Vector2(10, 10)) / Vector2(halo.get_size())
		var c := _rules.window_colour * _rules.window_halo * 2.0
		light.self_modulate = Color(c.r, c.g, c.b, 1.0)
		light.modulate.a = 0.0
		light.add_to_group(Daylight.NIGHT_LIGHTS)
		building.add_child(light)
		_fixed.append(light)


## The building's glass, coloured lamp-light, in a picture its own size:
## inside each window's box, the pixels that are glass (bluish and not dark,
## or already a warm lit colour) and not the frame or the wall.
static func _window_mask(texture: Texture2D, def: BuildingAmbience) -> ImageTexture:
	var key := "%s|%s" % [texture.resource_path, def.location_id]
	if _window_masks.has(key):
		return _window_masks[key]
	var image := texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	var mask := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var lamp := _rules.window_colour
	for window in def.windows:
		var box := window.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var c := image.get_pixel(x, y)
				if _is_glass(c):
					# Lighter glass (the shine on it) burns a little brighter.
					var bright := clampf(0.75 + c.get_luminance() * 0.35, 0.0, 1.0)
					mask.set_pixel(x, y, Color(lamp.r * bright, lamp.g * bright, lamp.b * bright, 1.0))
	var result := ImageTexture.create_from_image(mask)
	_window_masks[key] = result
	return result


static func _is_glass(c: Color) -> bool:
	if c.a < 0.8:
		return false
	var bluish := c.b > c.r + 0.1 and (c.r + c.g + c.b) / 3.0 > 0.37
	var lit := c.r > 0.78 and c.g > 0.5 and c.b < 0.55
	return bluish or lit


# --- The moving things ---------------------------------------------------------

func _process(delta: float) -> void:
	if not Settings.ambience:
		return
	_clock += delta
	for puff in _smoke:
		var frames := puff.hframes
		puff.frame = int((_clock + float(puff.get_meta(&"phase", 0.0))) / _rules.smoke_frame_seconds) % frames
	var view := _view()
	_start_new(delta, view)
	_move(delta, view)


## The part of the world the camera shows.
func _view() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


func _start_new(delta: float, view: Rect2) -> void:
	if _alive.size() >= _rules.most_at_once:
		return
	var theme := GameState.current_season_theme()
	var season: StringName = theme.id if theme != null else &""
	var weather: StringName = GameState.weather.id if GameState.weather != null else &""
	for effect in _effects:
		if randf() >= effect.per_minute * delta / 60.0:
			continue
		if not _plays_now(effect, season, weather) or _count(effect) >= effect.most_at_once:
			continue
		var texture := picture(effect.pictures[randi() % effect.pictures.size()]) \
				if not effect.pictures.is_empty() else null
		if texture == null:
			continue
		_start(effect, texture, view)


func _plays_now(effect: AmbientEffect, season: StringName, weather: StringName) -> bool:
	if not effect.places.is_empty() and not effect.places.has(map_id):
		return false
	if not effect.seasons.is_empty() and not effect.seasons.has(season):
		return false
	if not effect.weather.is_empty() and not effect.weather.has(weather):
		return false
	if effect.not_weather.has(weather):
		return false
	return effect.plays_at(GameState.minutes)


func _count(effect: AmbientEffect) -> int:
	var count := 0
	for alive in _alive:
		if alive["effect"] == effect:
			count += 1
	return count


func _start(effect: AmbientEffect, texture: Texture2D, view: Rect2) -> void:
	match effect.motion:
		AmbientEffect.Motion.FLY_ACROSS:
			# From off one side, across the upper part of the screen.
			var leftwards := randf() < 0.5
			var y := view.position.y + view.size.y * randf_range(0.1, 0.6)
			var x := view.end.x + 16.0 if leftwards else view.position.x - 16.0
			var velocity := Vector2(-effect.speed if leftwards else effect.speed, 0.0)
			for i in effect.flock:
				var spot := Vector2(x + (12.0 * i if leftwards else -12.0 * i),
						y + randf_range(-6.0, 6.0) + (4.0 if i % 2 == 1 else 0.0))
				_add(effect, texture, spot, velocity, 60.0)
		AmbientEffect.Motion.FALL:
			var spot := Vector2(view.position.x + randf() * view.size.x,
					view.position.y + randf() * view.size.y * 0.6)
			_add(effect, texture, spot, Vector2(0.0, effect.speed), effect.lifetime * randf_range(0.8, 1.2))
		_:
			var spot := _spot(effect, view)
			if spot == Vector2.INF:
				return
			var life := effect.lifetime * randf_range(0.8, 1.2) \
					if effect.motion == AmbientEffect.Motion.WANDER else 0.0
			_add(effect, texture, spot, Vector2.RIGHT.rotated(randf() * TAU) * effect.speed, life)


## A spot on the right kind of ground, somewhere on screen; Vector2.INF if a
## few tries find none (no water in view, say).
func _spot(effect: AmbientEffect, view: Rect2) -> Vector2:
	var inner := view.grow(-8.0)
	for _try in 12:
		var spot := inner.position + Vector2(randf() * inner.size.x, randf() * inner.size.y)
		if effect.ground == AmbientEffect.Ground.ANY:
			return spot
		if _ground == null:
			return Vector2.INF
		var cell := _ground.local_to_map(_ground.to_local(spot))
		if not _ground_is(cell, effect.ground):
			continue
		if effect.motion == AmbientEffect.Motion.ONCE and effect.ground != AmbientEffect.Ground.GRASS:
			# On water, keep the whole splash on water: water either side too.
			if not (_ground_is(cell + Vector2i.LEFT, effect.ground)
					and _ground_is(cell + Vector2i.RIGHT, effect.ground)):
				continue
		return _ground.to_global(_ground.map_to_local(cell)) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	return Vector2.INF


func _ground_is(cell: Vector2i, ground: AmbientEffect.Ground) -> bool:
	if _ground.get_cell_source_id(cell) != GroundTiles.SOURCE_ID:
		return false
	var coords := _ground.get_cell_atlas_coords(cell)
	match ground:
		AmbientEffect.Ground.GRASS:
			return coords == GroundTiles.GRASS or coords == GroundTiles.GRASS_ALT \
					or coords.y == GroundTiles.GRASS_DETAIL_ROW
		AmbientEffect.Ground.POND:
			return coords == GroundTiles.WATER
		AmbientEffect.Ground.SEA:
			return coords == GroundTiles.SEA
		AmbientEffect.Ground.WATER:
			return coords == GroundTiles.WATER or coords == GroundTiles.SEA
	return true


func _add(effect: AmbientEffect, texture: Texture2D, spot: Vector2, velocity: Vector2, life: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var frames := SceneryLayer.frames_in(texture)
	sprite.hframes = frames
	sprite.position = spot
	# Wanderers and fallers fade in; the rest show at once.
	var fades := effect.motion == AmbientEffect.Motion.WANDER or effect.motion == AmbientEffect.Motion.FALL
	sprite.modulate.a = 0.0 if fades else effect.opacity
	sprite.flip_h = velocity.x < 0.0 and effect.motion == AmbientEffect.Motion.FLY_ACROSS
	if effect.glows:
		sprite.material = _additive
		sprite.self_modulate = Color(2.2, 2.2, 1.6)
	(_high if effect.above else _low).add_child(sprite)
	_alive.append({
		"sprite": sprite, "effect": effect, "frames": frames, "age": 0.0, "life": life,
		"phase": randf() * 10.0, "home": spot, "velocity": velocity,
	})


func _move(delta: float, view: Rect2) -> void:
	var gone: Array[Dictionary] = []
	for alive in _alive:
		var sprite: Sprite2D = alive["sprite"]
		var effect: AmbientEffect = alive["effect"]
		var frames: int = alive["frames"]
		alive["age"] += delta
		var age: float = alive["age"]
		var step := int(age / effect.frame_seconds)
		if effect.motion == AmbientEffect.Motion.ONCE:
			if step >= frames:
				gone.append(alive)
				continue
			sprite.frame = step
			continue
		sprite.frame = (step + int(alive["phase"] * 10.0)) % frames
		var velocity: Vector2 = alive["velocity"]
		match effect.motion:
			AmbientEffect.Motion.WANDER:
				# Turn a little this way and that, and back home if it strays.
				velocity = velocity.rotated(sin(age * 1.3 + alive["phase"]) * 2.0 * delta)
				var home: Vector2 = alive["home"]
				if sprite.position.distance_to(home) > WANDER_RANGE:
					velocity = velocity.lerp((home - sprite.position).normalized() * effect.speed, 2.0 * delta)
				alive["velocity"] = velocity
				sprite.position += velocity * delta
			AmbientEffect.Motion.FALL:
				var sway := sin(age * 1.6 + alive["phase"]) * effect.speed
				sprite.position += Vector2(sway + effect.speed * 0.35, velocity.y) * delta
			AmbientEffect.Motion.FLY_ACROSS:
				sprite.position += velocity * delta
				sprite.position.y += sin(age * 3.0 + alive["phase"]) * 3.0 * delta
				if not view.grow(48.0).has_point(sprite.position) or age > alive["life"]:
					gone.append(alive)
				continue
		var life: float = alive["life"]
		if age >= life:
			gone.append(alive)
			continue
		var fade := minf(minf(age, life - age) / FADE, 1.0)
		sprite.modulate.a = effect.opacity * fade
	for alive in gone:
		(alive["sprite"] as Node).queue_free()
		_alive.erase(alive)
