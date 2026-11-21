class_name SeasonLook
extends RefCounted
##
## SeasonLook — how the current season dresses an outdoor location: its ground
## tileset, its seasonal pictures for objects, and its overlays: the
## season's, if it has one, and today's weather's (rain, snow; DECISIONS 046).
##
## The farm and the town both ask this, so each stays free of season rules.
## Everything here changes only how a place looks, never what is in it
## (DECISIONS 005, 025).
##


## TEST (DECISIONS 076): a second look for the ground, built from the Cozy
## Village & Farm asset pack by art/build_cozy_ground.py into this folder.
## The folder is kept out of git (the pack's licence), so on a copy without it
## nothing changes. Each season's cozy tileset has exactly our layout, so it
## swaps in like a season does.
const COZY_DIR := "res://assets/tilesets/cozy/"

## Whether to show the cozy ground when it's there. Ctrl+G flips it while
## playing (GroundEdges), so the two looks can be compared on the spot. Never
## saved: it's only how the ground looks.
static var cozy_ground := true

## TEST (DECISIONS 078): calmer cliffs (the pack's raised ground with an earth
## face) and calmer paving (big flagstones), built by art/build_calm_test.py
## into the same folder as calm_tileset_<season>.tres. Only over the cozy
## ground. Ctrl+K flips it while playing. Never saved.
static var calm_test := true

## TEST (DECISIONS 080): the Cove's harbour from the Coast, Beach & Fishing
## pack (quay wall, pier on posts, breakwater, rock shelf), built by
## art/build_harbour_test.py as harbour_tileset_<season>.tres. Over the calm
## look only. Ctrl+H flips it while playing. Never saved.
static var harbour_test := true


## Swap `ground` to the current season's tileset. The tileset layouts match
## (season_theme.gd), so tiles already placed keep their meaning.
static func apply_ground(ground: TileMapLayer) -> void:
	var theme := GameState.current_season_theme()
	var tiles := _ground_tileset(theme)
	if tiles != null:
		ground.tile_set = tiles
	# Its soft edges (DECISIONS 072) draw from the same tileset.
	var edges := GroundEdges.of(ground)
	if edges != null:
		edges.follow_tileset()


## The season's ground tileset: the cozy one if it's switched on and built,
## else the season's own.
static func _ground_tileset(theme: SeasonTheme) -> TileSet:
	if theme == null:
		return null
	if cozy_ground and calm_test and harbour_test:
		var harbour := COZY_DIR + "harbour_tileset_%s.tres" % theme.id
		if ResourceLoader.exists(harbour):
			return load(harbour) as TileSet
	if cozy_ground and calm_test:
		var calm := COZY_DIR + "calm_tileset_%s.tres" % theme.id
		if ResourceLoader.exists(calm):
			return load(calm) as TileSet
	if cozy_ground:
		var path := COZY_DIR + "ground_tileset_%s.tres" % theme.id
		if ResourceLoader.exists(path):
			return load(path) as TileSet
	return theme.ground_tileset


## Whether the cozy ground has been built on this copy of the game.
static func has_cozy_ground() -> bool:
	return ResourceLoader.exists(COZY_DIR + "ground_tileset_spring.tres")


## Whether the calm test (DECISIONS 078) has been built on this copy.
static func has_calm_test() -> bool:
	return ResourceLoader.exists(COZY_DIR + "calm_tileset_spring.tres")


## Whether the harbour test (DECISIONS 080) has been built on this copy.
static func has_harbour_test() -> bool:
	return ResourceLoader.exists(COZY_DIR + "harbour_tileset_spring.tres")


## Show `node` with the current season's picture for `object_id`, if the
## season has one, or else the picture its scene was built with — remembered
## on the sprite the first time, so winter's snowy tree can turn back into
## spring's green one. The node needs a Sprite2D child called "Sprite".
static func skin_object(node: Node, object_id: StringName) -> void:
	var sprite := node.get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	if not sprite.has_meta(&"base_texture"):
		sprite.set_meta(&"base_texture", sprite.texture)
	if not sprite.has_meta(&"base_offset"):
		sprite.set_meta(&"base_offset", sprite.offset)
	var theme := GameState.current_season_theme()
	var seasonal: Texture2D = theme.object_sprites.get(object_id) if theme != null else null
	sprite.texture = seasonal if seasonal != null else sprite.get_meta(&"base_texture")
	sprite.offset = sprite.get_meta(&"base_offset")
	# TEST (DECISIONS 081): the bought packs' picture, if it's switched on.
	if PackLook.has_pack():
		node.set_meta(&"object_id", object_id)
		node.add_to_group(&"pack_skinned")
		_pack_skin(node, sprite, object_id)


## The packs' picture for `object_id` over ours, standing on the same spot:
## its bottom edge where ours was.
static func _pack_skin(node: Node, sprite: Sprite2D, object_id: StringName) -> void:
	if PackLook.joins(object_id) and node is Node2D:
		PackLook.join(node, sprite, object_id)
		return
	var pack := PackLook.texture_for(object_id)
	var base: Texture2D = sprite.get_meta(&"base_texture")
	if pack == null or base == null:
		return
	sprite.texture = pack
	sprite.offset.y += (base.get_height() - pack.get_height()) / 2.0


## Replace whatever is under `weather` with this season's overlay, if any,
## and today's weather's (falling rain, falling snow).
static func apply_overlay(weather: Node) -> void:
	for child in weather.get_children():
		weather.remove_child(child)
		child.queue_free()
	var theme := GameState.current_season_theme()
	if theme != null and theme.overlay != null:
		weather.add_child(theme.overlay.instantiate())
	if GameState.weather != null and GameState.weather.overlay != null:
		weather.add_child(GameState.weather.overlay.instantiate())
