extends Node2D
##
## Farm — the farm scene: draws FarmData and holds the things standing on it.
## It's one location among (eventually) several; LocationManager opens it.
##
## Since Stage 2 this script owns no game state at all. It reads the farm from
## GameState, paints it once on load, then listens on EventBus and repaints
## single cells as they change. If this scene were thrown away and rebuilt
## (as it will be every time the player comes back from town in Stage 7),
## the farm would look exactly the same, because the truth lives in FarmData.
##
## Scene structure matters for depth:
##
##   Farm
##   ├── Ground     (TileMapLayer, z_index -1, NOT y-sorted — always underfoot)
##   ├── SpawnPoints (Marker2Ds where LocationManager can put an arriving player)
##   ├── TileCursor (outline on the tile the player is facing; drawn under entities)
##   ├── Entities   (y-sorted — player, trees and crops sort against each other
##   │               by their node origin, which for all of them sits at their base)
##   ├── Weather    (holds the season's overlay, e.g. winter: a cold tint on the
##   │               world, and snow falling on a CanvasLayer over it, under the HUD)
##   └── Hud        (CanvasLayer, layer 2 — fixed to the screen, not the world)
##

const TILE_PX := 16
const SOURCE_ID := 0

# Atlas coordinates into the season's ground tileset (assets/tilesets/ground_<season>.png)
const TILE_GRASS := Vector2i(0, 0)
const TILE_GRASS_ALT := Vector2i(1, 0)
const TILE_PATH := Vector2i(2, 0)
const TILE_TILLED := Vector2i(3, 0)
const TILE_TILLED_WET := Vector2i(4, 0)
const TILE_WATER := Vector2i(5, 0)
const TILE_CLIFF := Vector2i(7, 0)
const TILE_THICKET := Vector2i(8, 0)

## Roughly how much of the grass uses the variant tile. Purely cosmetic, which
## is why it's here and not in FarmData: which grass tile a cell shows is a
## drawing decision, not a fact about the farm.
const GRASS_VARIATION := 0.18


@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _cursor: Node2D = $TileCursor
@onready var _weather: Node = $Weather

## cell -> the Sprite2D showing the crop there. Purely a view cache: it can
## always be rebuilt from FarmData, and is, every morning.
var _crop_sprites: Dictionary = {}

## cell -> the node showing the object there (tree, bin, sprinkler). Also only
## a view: what stands where is in FarmData.
var _object_nodes: Dictionary = {}


func _ready() -> void:
	_place_player()
	_apply_season_theme()
	_draw_all()
	_place_objects()
	_apply_season_overlay()
	EventBus.tile_tilled.connect(_redraw_cell)
	EventBus.tile_watered.connect(_redraw_cell)
	EventBus.tile_cleared.connect(_redraw_cell)
	EventBus.crop_planted.connect(func(cell: Vector2i, _id: StringName) -> void: _redraw_crop(cell))
	EventBus.crop_grew.connect(func(cell: Vector2i, _stage: int) -> void: _redraw_crop(cell))
	EventBus.crop_harvested.connect(
		func(cell: Vector2i, _id: StringName, _n: int) -> void: _redraw_crop(cell)
	)
	EventBus.crop_died.connect(func(cell: Vector2i, _id: StringName) -> void: _redraw_crop(cell))
	EventBus.object_placed.connect(func(cell: Vector2i, _id: StringName) -> void:
		_redraw_cell(cell)
		_place_object(cell)
	)
	EventBus.object_removed.connect(func(cell: Vector2i, _id: StringName) -> void: _remove_object(cell))
	# A field bought: its thicket is grass now. Rare enough to redraw it all.
	EventBus.plot_unlocked.connect(func(_id: StringName) -> void: _draw_all())
	# Overnight, many cells change at once (all the soil dries), so rather
	# than a signal per cell the morning simply redraws the whole farm.
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _draw_all())
	EventBus.season_changed.connect(func(_s: int) -> void:
		_apply_season_theme()
		_draw_all()
		_reskin_objects()
		_apply_season_overlay()
	)

	print("--- Pixel Harvest · Stage 6 ---")
	print("WASD/arrows move. Space uses the item on the highlighted tile(s).")
	print("Tab / Q move along the hotbar: tools, seeds, sprinklers.")
	print("E harvests a ready crop, ships produce at the bin, or picks up a sprinkler.")
	print("B opens the shop: seeds, sprinklers, and upgrades (tools, energy, fields).")
	print("Enter sleeps; the bin sells overnight and sprinklers water at dawn.")
	print("Seasons last %d days. Seeds only go in during their own seasons, and crops"
			% GameState.RULES.days_per_season)
	print("still in the ground when their season ends die overnight.")
	print("The game saves every morning and loads on launch. Ctrl+N starts a new game.")
	print("-------------------------------")


func _process(_delta: float) -> void:
	# The cursor follows wherever the player is facing, so it's always clear
	# which tiles Space will act on — three or nine with an upgraded tool.
	_cursor.set_cells(_player.target_cells())


## Put the player at the spawn point LocationManager asked for, if any.
## Arriving from the town (Stage 7) will name the farm gate, for example.
func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	if point == &"":
		return
	var marker := get_node_or_null(NodePath("SpawnPoints/%s" % point)) as Marker2D
	if marker == null:
		push_warning("Farm has no spawn point '%s'" % point)
		return
	_player.position = marker.position


## Swap the ground to this season's tileset. Every season's tileset shares one
## atlas layout (see season_theme.gd), so the redraw that follows puts every
## tile back in the right place with the new season's pixels.
func _apply_season_theme() -> void:
	var theme := GameState.current_season_theme()
	if theme != null and theme.ground_tileset != null:
		_ground.tile_set = theme.ground_tileset


func _draw_all() -> void:
	for cell: Vector2i in GameState.farm.cells():
		_redraw_cell(cell)
		_redraw_crop(cell)


## Make the crop sprite at `cell` match FarmData: create it, update its growth
## frame, or remove it.
func _redraw_crop(cell: Vector2i) -> void:
	var t: FarmTile = GameState.farm.tile(cell)
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if t.has_crop() and t.crop.sprite_sheet == null:
		# A content mistake, not a code one: say which crop, and carry on
		# rather than crash. The crop still grows; it just can't be seen.
		push_warning("Crop '%s' has no sprite_sheet set" % t.crop.id)
		return
	if not t.has_crop():
		if sprite != null:
			sprite.queue_free()
			_crop_sprites.erase(cell)
		return
	if sprite == null:
		sprite = Sprite2D.new()
		# Crops live with the player and trees so they Y-sort against them:
		# walk above a tall crop and you're hidden behind it.
		sprite.position = cell_base(cell)
		_entities.add_child(sprite)
		_crop_sprites[cell] = sprite
	var sheet := t.crop.sprite_sheet
	sprite.texture = sheet
	sprite.hframes = t.crop.growth_stages + 1
	# Lift the sprite so its bottom edge sits on the bottom of the tile.
	sprite.offset = Vector2(0, -sheet.get_height() / 2.0)
	sprite.frame = t.crop_stage


func _redraw_cell(cell: Vector2i) -> void:
	_ground.set_cell(cell, SOURCE_ID, _atlas_for(cell))


## The one place that decides what a FarmTile looks like. The season decides
## which tileset these coordinates point into (_apply_season_theme), never
## which coordinates are used.
func _atlas_for(cell: Vector2i) -> Vector2i:
	var t: FarmTile = GameState.farm.tile(cell)
	if t.tilled:
		return TILE_TILLED_WET if t.watered else TILE_TILLED
	match t.terrain:
		FarmTile.Terrain.CLIFF:
			return TILE_CLIFF
		FarmTile.Terrain.WATER:
			return TILE_WATER
		FarmTile.Terrain.PATH:
			return TILE_PATH
		FarmTile.Terrain.THICKET:
			return TILE_THICKET
	# hash() gives the same answer for the same cell every run, so the grass
	# pattern is stable without storing anything.
	if float(hash(cell) % 1000) / 1000.0 < GRASS_VARIATION:
		return TILE_GRASS_ALT
	return TILE_GRASS


## Where a cell's bottom edge sits — the anchor for anything standing on it.
func cell_base(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, float((cell.y + 1) * TILE_PX))


func _place_objects() -> void:
	for cell: Vector2i in GameState.farm.cells():
		_place_object(cell)


## Show whatever FarmData says stands at `cell`. What scene that is comes from
## its ObjectDef (data/objects/), so a new kind of object needs no code here.
func _place_object(cell: Vector2i) -> void:
	var object_id: StringName = GameState.farm.tile(cell).object_id
	if object_id == &"":
		return
	var object_def := ContentDB.object(object_id)
	if object_def == null or object_def.scene == null:
		push_warning("Farm has an object '%s' with no scene to show it" % object_id)
		return
	_remove_object(cell)
	var node: Node2D = object_def.scene.instantiate()
	node.position = cell_base(cell)
	_entities.add_child(node)
	_object_nodes[cell] = node
	_skin_object(node, object_id)


func _remove_object(cell: Vector2i) -> void:
	var node: Node2D = _object_nodes.get(cell)
	if node != null:
		node.queue_free()
		_object_nodes.erase(cell)


# --- Seasons -----------------------------------------------------------------
# The ground tileset is swapped in _apply_season_theme above. Objects and the
# screen overlay are below. All three only change how the farm looks: nothing
# about what's on it.

## Give every object on the farm this season's picture.
func _reskin_objects() -> void:
	for cell: Vector2i in _object_nodes:
		_skin_object(_object_nodes[cell], GameState.farm.tile(cell).object_id)


## Show `node` with the current season's picture for `object_id`, if the
## season has one, or else the picture its scene was built with — which is
## remembered on the sprite the first time, so winter's snowy tree can turn
## back into spring's green one.
func _skin_object(node: Node, object_id: StringName) -> void:
	var sprite := node.get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	if not sprite.has_meta(&"base_texture"):
		sprite.set_meta(&"base_texture", sprite.texture)
	var theme := GameState.current_season_theme()
	var seasonal: Texture2D = theme.object_sprites.get(object_id) if theme != null else null
	sprite.texture = seasonal if seasonal != null else sprite.get_meta(&"base_texture")


## Replace the screen overlay (winter's snow) with this season's, or none.
func _apply_season_overlay() -> void:
	for child in _weather.get_children():
		child.queue_free()
	var theme := GameState.current_season_theme()
	if theme != null and theme.overlay != null:
		_weather.add_child(theme.overlay.instantiate())
