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


## Swap `ground` to the current season's tileset. The tileset layouts match
## (season_theme.gd), so tiles already placed keep their meaning.
static func apply_ground(ground: TileMapLayer) -> void:
	var theme := GameState.current_season_theme()
	if theme != null and theme.ground_tileset != null:
		ground.tile_set = theme.ground_tileset
	# Its soft edges (DECISIONS 072) draw from the same tileset.
	var edges := GroundEdges.of(ground)
	if edges != null:
		edges.follow_tileset()


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
	var theme := GameState.current_season_theme()
	var seasonal: Texture2D = theme.object_sprites.get(object_id) if theme != null else null
	sprite.texture = seasonal if seasonal != null else sprite.get_meta(&"base_texture")


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
