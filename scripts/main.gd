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
##   ├── SpawnPoints (Marker2Ds where LocationManager can put an arriving player:
##   │               "default", "from_town" just inside the gate, and one
##   │               "from_<id>" in front of each building's door, made here)
##   ├── TileCursor (outline on the tile the player is facing; drawn under entities)
##   ├── Entities   (y-sorted — player, trees and crops sort against each other
##   │               by their node origin, which for all of them sits at their base)
##   ├── Effects    (FarmEffects: bursts of dirt and water, the harvest popping
##   │               up, camera jolts — drawn over Entities; DECISIONS 042)
##   ├── Weather    (holds the season's overlay, e.g. winter: snow falling on a
##   │               CanvasLayer over the world, under the HUD)
##   ├── Daylight   (scenes/daylight.tscn: tints the world by the clock — dusk,
##   │               night — and by the season's light_tint; DECISIONS 036)
##   └── Hud        (scenes/hud.tscn, shared with the town — CanvasLayer 2, fixed to
##                   the screen, not the world)
##
## The way to the town is the gap at the west end of the path (FarmLayout.TOWN_GATE):
## an ExitZone is added there, and walking into it goes to the town.
##
## The farmhouse (Stage 7) is a Building like the town's shops: a LocationDef
## whose door is on the farm. Walking into its door goes inside, where the bed
## is. The ground under it is BUILDING terrain in FarmData (FarmLayout), so no
## tool can reach it.
##

const TILE_PX := 16
const SOURCE_ID := GroundTiles.SOURCE_ID

## Weeds' picture (DECISIONS 045), unless the season has its own: a
## SeasonTheme's object_sprites can give &"weeds" a seasonal look, as it does
## for trees.
const WEEDS_TEXTURE: Texture2D = preload("res://assets/sprites/farm/weeds.png")
const WEEDS_SKIN_ID := &"weeds"

## A wilting crop's tint: drained and browned (DECISIONS 045). Only a look;
## FarmTile.is_wilted() is the truth.
const WILTED_TINT := Color(0.9, 0.62, 0.32)

## Where the town is, and which spawn point in the town the farm gate leads to.
const TOWN_ID := &"town"
const TOWN_ARRIVAL := &"from_farm"


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

## cell -> the Sprite2D showing weeds there. A view, like the crops.
var _weed_sprites: Dictionary = {}

## cell -> the Crow standing there this morning (FarmData.crows_landed).
var _crows: Dictionary = {}


func _ready() -> void:
	_add_buildings()
	_place_player()
	_add_town_gate()
	_apply_season_theme()
	_draw_all()
	_place_objects()
	_apply_season_overlay()
	_place_crows()
	EventBus.tile_tilled.connect(_redraw_cell)
	EventBus.tile_watered.connect(func(cell: Vector2i) -> void:
		_redraw_cell(cell)
		_redraw_crop(cell)  # a wilting crop perks up as soon as it's watered
	)
	EventBus.tile_cleared.connect(_redraw_cell)
	EventBus.weeds_sprouted.connect(_redraw_weeds)
	EventBus.weeds_pulled.connect(_redraw_weeds)
	EventBus.crop_planted.connect(func(cell: Vector2i, _id: StringName) -> void:
		_redraw_crop(cell)
		_squash_crop(cell)
	)
	EventBus.crop_grew.connect(func(cell: Vector2i, _stage: int) -> void: _redraw_crop(cell))
	EventBus.crop_harvested.connect(func(cell: Vector2i, _id: StringName, _n: int) -> void:
		_redraw_crop(cell)
		_squash_crop(cell)  # a crop that grows back stays, and gets a shake
	)
	EventBus.crop_died.connect(func(cell: Vector2i, _id: StringName, _cause: StringName) -> void: _redraw_crop(cell))
	EventBus.object_placed.connect(func(cell: Vector2i, _id: StringName) -> void:
		_redraw_cell(cell)
		_place_object(cell)
	)
	EventBus.object_removed.connect(func(cell: Vector2i, _id: StringName) -> void: _remove_object(cell))
	# A field bought: its thicket is grass now. Rare enough to redraw it all.
	EventBus.plot_unlocked.connect(func(_id: StringName) -> void: _draw_all())
	# Overnight, many cells change at once (all the soil dries), so rather
	# than a signal per cell the morning simply redraws the whole farm.
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void:
		_draw_all()
		_place_crows()
	)
	EventBus.season_changed.connect(func(_s: int) -> void:
		_apply_season_theme()
		_draw_all()
		_reskin_objects()
		_apply_season_overlay()
	)

	print("--- Pixel Harvest · Stage 11 ---")
	print("WASD/arrows move. Space uses the item on the highlighted tile(s).")
	print("Tab / Q move along the hotbar: tools, seeds, sprinklers.")
	print("E harvests a ready crop, ships produce at the bin, or picks up a sprinkler")
	print("or a decoration. Decorations (Marlow's store) go down with Space, like sprinklers.")
	print("Walk out of the gate at the west end of the path to reach the town: seeds,")
	print("supplies and upgrades are bought from the shopkeepers there. E talks to them.")
	print("Go to bed in the farmhouse (E at the bed) to end the day; the bin sells")
	print("overnight and sprinklers water at dawn. You wake up at home.")
	print("Seasons last %d days. Seeds only go in during their own seasons, and crops"
			% GameState.RULES.days_per_season)
	print("still in the ground when their season ends die overnight.")
	print("The game saves every morning and loads on launch. Ctrl+N starts a new game.")
	print("Each night shows a summary of the day: Space to carry on. M mutes the sound.")
	print("Crops left unwatered for two nights wilt, and on a third they die. From spring")
	print("day 6 weeds come up (E pulls them, the hoe digs them out); from day 15 crows")
	print("take unguarded crops. A scarecrow guards every crop within 8 tiles.")
	print("-------------------------------")


func _process(_delta: float) -> void:
	# The cursor follows wherever the player is facing, so it's always clear
	# which tiles Space will act on — three or nine with an upgraded tool.
	_cursor.set_cells(_player.target_cells())


## Every building with its door on the farm (the farmhouse), and a spawn point
## in front of each door for coming back out.
func _add_buildings() -> void:
	for def in LocationManager.buildings_on(LocationManager.FARM_ID):
		_entities.add_child(Building.create(def))
		var marker := Marker2D.new()
		marker.name = "from_%s" % def.id
		marker.position = Vector2(def.door_cell.x * TILE_PX + TILE_PX / 2.0, (def.door_cell.y + 2) * TILE_PX - 2)
		$SpawnPoints.add_child(marker)


## The way out to the town: the gate cells at the west end of the path.
func _add_town_gate() -> void:
	var top_left: Vector2i = FarmLayout.TOWN_GATE[0]
	var rect := Rect2(top_left * TILE_PX, Vector2(TILE_PX, TILE_PX * FarmLayout.TOWN_GATE.size()))
	add_child(ExitZone.create(rect, TOWN_ID, TOWN_ARRIVAL))


## Put the player at the spawn point LocationManager asked for, if any.
## Arriving from the town names "from_town", just inside the gate.
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
	SeasonLook.apply_ground(_ground)


func _draw_all() -> void:
	for cell: Vector2i in GameState.farm.cells():
		_redraw_cell(cell)
		_redraw_crop(cell)
		_redraw_weeds(cell)


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
	sprite.modulate = WILTED_TINT if t.is_wilted(GameState.wilt_after()) else Color.WHITE


## Make the weeds at `cell` match FarmData: show them, or take them away.
## They stand in the y-sorted Entities a hair behind the tile's crop (one
## pixel up), so the tufts show either side of it rather than over it.
func _redraw_weeds(cell: Vector2i) -> void:
	var t: FarmTile = GameState.farm.tile(cell)
	var sprite: Sprite2D = _weed_sprites.get(cell)
	if not t.weeds:
		if sprite != null:
			sprite.queue_free()
			_weed_sprites.erase(cell)
		return
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.position = cell_base(cell) - Vector2(0, 1)
		sprite.offset = Vector2(0, -WEEDS_TEXTURE.get_height() / 2.0 + 1)
		_entities.add_child(sprite)
		_weed_sprites[cell] = sprite
	sprite.texture = _weeds_texture()


## This season's weeds, or the everyday ones.
func _weeds_texture() -> Texture2D:
	var theme := GameState.current_season_theme()
	var seasonal: Texture2D = theme.object_sprites.get(WEEDS_SKIN_ID) if theme != null else null
	return seasonal if seasonal != null else WEEDS_TEXTURE


## A crow on every cell crows took a crop from last night, until it's
## scared off (DECISIONS 045).
func _place_crows() -> void:
	for cell: Vector2i in GameState.farm.crows_landed:
		if is_instance_valid(_crows.get(cell)):
			continue
		var crow := Crow.create(cell, cell_base(cell), _player)
		_entities.add_child(crow)
		_crows[cell] = crow


## A quick squash and stretch of the crop at `cell`, if there's one left:
## something just happened to it. Only the picture moves (DECISIONS 042).
func _squash_crop(cell: Vector2i) -> void:
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		return
	sprite.scale = Vector2(1.3, 0.7)
	sprite.create_tween().tween_property(sprite, ^"scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _redraw_cell(cell: Vector2i) -> void:
	GroundTiles.draw(_ground, cell, _atlas_for(cell))


## The one place that decides what a FarmTile looks like. The season decides
## which tileset these coordinates point into (_apply_season_theme), never
## which coordinates are used.
func _atlas_for(cell: Vector2i) -> Vector2i:
	var t: FarmTile = GameState.farm.tile(cell)
	if t.tilled:
		return GroundTiles.TILLED_WET if t.watered else GroundTiles.TILLED
	match t.terrain:
		FarmTile.Terrain.CLIFF:
			return GroundTiles.CLIFF
		FarmTile.Terrain.WATER:
			return GroundTiles.WATER
		FarmTile.Terrain.PATH:
			return GroundTiles.path_for(cell)
		FarmTile.Terrain.THICKET:
			return GroundTiles.THICKET
	# GRASS, and BUILDING: grass shows round the edges of a building's picture.
	return GroundTiles.grass_for(cell)


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
## season has one (SeasonLook).
func _skin_object(node: Node, object_id: StringName) -> void:
	SeasonLook.skin_object(node, object_id)


## Replace the screen overlay (winter's snow) with this season's, or none.
func _apply_season_overlay() -> void:
	SeasonLook.apply_overlay(_weather)
