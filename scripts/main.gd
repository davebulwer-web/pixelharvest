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
##   │               "default", "from_lane" just inside the gate (made by
##   │               Exits, DECISIONS 060), and one "from_<id>" in front of
##   │               each building's door, made here)
##   ├── TileCursor (outline on the tile the player is facing; drawn under entities)
##   ├── Entities   (y-sorted — player, trees and crops sort against each other
##   │               by their node origin, which for all of them sits at their base)
##   ├── Effects    (FarmEffects: bursts of dirt and water, the harvest popping
##   │               up, camera jolts — drawn over Entities; DECISIONS 042)
##   ├── Weather    (holds the season's overlay and today's weather's, e.g. rain
##   │               or snow falling on a CanvasLayer over the world, under the
##   │               HUD; DECISIONS 046)
##   ├── Daylight   (scenes/daylight.tscn: tints the world by the clock — dusk,
##   │               night — and by the season's light_tint; DECISIONS 036)
##   ├── Hud        (scenes/hud.tscn, shared with the town — CanvasLayer 2, fixed to
##   │               the screen, not the world)
##   └── Dialogue   (the dialogue box, as in town: what a find while clearing
##                   says, DECISIONS 061)
##
## The way off the farm is the gap at the west end of the path: since Stage 19
## it leads to the Lane, and from there to the town (DECISIONS 060). Where it
## is and where it goes is the farm's LocationDef's `exits`; Exits adds the
## zone and the spawn point for coming back.
##
## The farmhouse (Stage 7) is a Building like the town's shops: a LocationDef
## whose door is on the farm. Walking into its door goes inside, where the bed
## is. The ground under it is BUILDING terrain in FarmData (FarmLayout), so no
## tool can reach it. The old greenhouse (DECISIONS 057) is another.
##
## The greenhouse's room is drawn by greenhouse.gd, which extends this script:
## its plot is a FarmData too, so the crops, soil, objects and weeds are drawn
## by the same code here. Everything reads `plot` (the farm's FarmData here,
## the greenhouse's there), and the few things that differ indoors (the
## surroundings, the season's look, the weather, the crows) are the
## functions greenhouse.gd replaces.
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

## A crop asleep out of its season (garlic in winter, a perennial; DECISIONS
## 047): greyed, so it reads as alive but resting.
const RESTING_TINT := Color(0.66, 0.68, 0.74)

## What a trellis crop (CropDef.solid) blocks: about the width of a tile and
## most of its depth, so the player can't stand half inside the trellis.
const SOLID_CROP_SIZE := Vector2(14, 10)

## What a tree (a solid crop bigger than a tile: the apple tree) blocks: just
## its trunk, so the player can walk behind its leaves (DECISIONS 048).
const TRUNK_SIZE := Vector2(10, 8)

## Aphids on a crop (DECISIONS 048): a picture laid over the crop's tile.
const PESTS_TEXTURE: Texture2D = preload("res://assets/sprites/farm/aphids.png")


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

## cell -> the Sprite2D showing fed soil there (DECISIONS 058): the
## fertiliser's soil_look, flat on the ground. A view, like the crops.
var _feed_sprites: Dictionary = {}

## Where fed soil's pictures go: just above the ground and below everything
## standing on it, so crops, weeds and the player all draw over it.
var _feed_layer: Node2D

## The tiles this scene draws: the farm's (DECISIONS 057: the greenhouse
## scene gives its own plot instead, through _plot()).
var plot: FarmData


func _ready() -> void:
	plot = _plot()
	_feed_layer = Node2D.new()
	_feed_layer.name = "FedSoil"
	add_child(_feed_layer)
	move_child(_feed_layer, _ground.get_index() + 1)
	_build_surroundings()
	_place_player()
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
	EventBus.soil_fed.connect(func(cell: Vector2i, _id: StringName) -> void: _redraw_cell(cell))
	# The axe chopped thicket here: it's grass now (DECISIONS 053).
	EventBus.wood_chopped.connect(func(where: StringName, cell: Vector2i, _what: StringName, _id: StringName, _n: int) -> void:
		if where == &"farm":
			_redraw_cell(cell)
	)
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
	EventBus.crop_dug_up.connect(func(cell: Vector2i, _id: StringName, _seed: bool) -> void: _redraw_crop(cell))
	EventBus.pests_spread.connect(_redraw_crop)
	EventBus.pests_cleared.connect(_redraw_crop)
	EventBus.object_placed.connect(func(cell: Vector2i, _id: StringName) -> void:
		_redraw_cell(cell)
		_place_object(cell)
	)
	EventBus.object_removed.connect(func(cell: Vector2i, _id: StringName) -> void: _remove_object(cell))
	# Something turned up while clearing the new ground (DECISIONS 061).
	EventBus.found_while_clearing.connect(_show_find)
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
	# Rain, snow: today's weather's overlay goes with the season's (DECISIONS 046).
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _apply_season_overlay())
	_print_help()


## The FarmData this scene shows. The greenhouse gives its own.
func _plot() -> FarmData:
	return GameState.farm


## What surrounds the plot: on the farm, its buildings and the gate to the
## Lane. The greenhouse builds its room instead.
func _build_surroundings() -> void:
	_add_buildings()
	Exits.add(self, LocationManager.find(LocationManager.FARM_ID), $SpawnPoints)


## The keys, printed to Godot's Output panel when the farm opens.
func _print_help() -> void:
	print("--- Pixel Harvest · Stage 20 (early days, session 2) ---")
	print("WASD/arrows move. Space uses the item on the highlighted tile(s).")
	print("Tab / Q move along the hotbar: tools, seeds, sprinklers.")
	print("E harvests a ready crop, ships produce at the bin, or picks up a sprinkler")
	print("or a decoration. Decorations (Marlow's store) go down with Space, like sprinklers.")
	print("Walk out of the gate at the west end of the path onto the Lane, and along it")
	print("to the town: seeds, supplies and upgrades are bought from the shopkeepers there.")
	print("E talks to them. E picks up what's growing in the Lane's hedgerows.")
	print("The farm's new ground (east and south) is overgrown: the hoe breaks up stones,")
	print("E pulls up brambles and nettles (or the sickle cuts them), and the axe digs out")
	print("stumps. Clearing gives stone, fibre and timber, and leaves ground to farm.")
	print("Now and then something turns up while clearing: a seed tin, a page of the old")
	print("farmer's notebook... On the Lane, Pip's family's cottage and Dot's yard are through the hedge gaps.")
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
	print("Weather: rain and storms water the farm for you; a heatwave dries crops out")
	print("twice as fast; autumn ends in frost. Tomorrow's is on the notice board.")
	print("New crops have rules (the seed shop says which): bunches, trellises you can't")
	print("walk through, hardy crops that need no water, watercress beside the pond,")
	print("garlic that sleeps through winter, rhubarb that comes back every year.")
	print("Storms can flatten tall crops (corn, peas, sunflowers) unless a fence is beside them.")
	print("The trowel digs up a crop (a seed not yet up goes back in the bag). From autumn,")
	print("aphids stop crops growing and spread: Marlow's pest spray clears them, flowers")
	print("slow them. A 3 x 3 block of ripe melons or pumpkins may grow into a giant.")
	print("Fennel sells apple saplings: a tree for a 2 x 2 patch of tilled soil.")
	print("Fishing (Wren's rod, from summer): Space at water casts; Space when the float goes")
	print("under; then Space while the marker is over the green. E reels in. In winter, Space")
	print("on the ice cuts a hole, and Space at the hole fishes through it.")
	print("Cooking (Mabel's lessons, from summer): E at the farmhouse stove cooks what you know.")
	print("A dish on the hotbar is eaten with Space, anywhere, for energy.")
	print("The old greenhouse by the farmhouse (mended by Ivy's last request) grows any seed")
	print("in any season. Marlow sells bee hives from summer: E at a hive collects its honey.")
	print("Fertiliser goes on tilled soil with Space: growth feed (Marlow, spring day 22) makes")
	print("seeds come up a stage ahead; mulch (from Ivy) keeps watered soil wet a night longer.")
	print("Brann's sickle (for 30 fibre, autumn) cuts weeds and ripe crops; he makes it wider.")
	print("His last request, in winter, is the brass sprinkler: 24 tiles round.")
	print("On the Lane, Dot has errands to run and the allotment slate has odd jobs, paid on the spot.")
	print("The old workbench by the farmhouse is one leg short: E at it with 3 stones mends it.")
	print("Then E at it makes things from stone, timber and fibre: plans come from people.")
	print("Every buyer pays less once it has had plenty of one thing that day: spread a big")
	print("harvest between the bin, Marlow, Rosa and Mabel. Back to full price by morning.")
	print("Mabel's bakery (from spring day 5, 7 AM - 2 PM) sells food for energy and buys fruit.")
	print("-------------------------------")


func _process(_delta: float) -> void:
	# The cursor follows wherever the player is facing, so it's always clear
	# which tiles Space will act on — three or nine with an upgraded tool.
	_cursor.set_cells(_player.target_cells())


## A find while clearing (DECISIONS 061): what it says, in the dialogue box,
## headed with what it is. Deferred, so the box opens after the swing that
## found it has finished, not in the middle of it. A scene without a box
## (the greenhouse has no debris, but just in case) says it on the HUD.
func _show_find(find_id: StringName, _cell: Vector2i, nth: int) -> void:
	var found := ContentDB.find(find_id)
	if found == null:
		return
	var box := get_node_or_null(^"Dialogue")
	if box != null:
		box.say.call_deferred(found.display_name, found.lines_for(nth))
	else:
		EventBus.message_posted.emit("Found: %s" % found.display_name)


## Every building with its door on the farm (the farmhouse), and a spawn point
## in front of each door for coming back out.
func _add_buildings() -> void:
	for def in LocationManager.buildings_on(LocationManager.FARM_ID):
		_entities.add_child(Building.create(def))
		var marker := Marker2D.new()
		marker.name = "from_%s" % def.id
		marker.position = Building.doorstep(def)
		$SpawnPoints.add_child(marker)


## Put the player at the spawn point LocationManager asked for, if any.
## Arriving from the Lane names "from_lane", just inside the gate.
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
	for cell: Vector2i in plot.cells():
		_redraw_cell(cell)
		_redraw_crop(cell)
		_redraw_weeds(cell)


## Make the crop sprite at `cell` match FarmData: create it, update its growth
## frame, or remove it.
func _redraw_crop(cell: Vector2i) -> void:
	var t: FarmTile = plot.tile(cell)
	if t == null:
		return  # not one of this scene's tiles (a signal from the other plot)
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
		_entities.add_child(sprite)
		_crop_sprites[cell] = sprite
	# A giant or a tree (DECISIONS 048) stands on several tiles: this cell is
	# its front-left corner, so its picture is centred over the whole patch.
	var span := t.span()
	sprite.position = cell_base(cell) + Vector2((span - 1) * TILE_PX / 2.0, 0)
	var sheet := t.crop.giant_sprite if t.giant else t.crop.sprite_sheet
	sprite.texture = sheet
	sprite.hframes = 1 if t.giant else t.crop.growth_stages + 1
	# Lift the sprite so its bottom edge sits on the bottom of the tile.
	sprite.offset = Vector2(0, -sheet.get_height() / 2.0)
	sprite.frame = 0 if t.giant else t.crop_stage
	_set_crop_pests(sprite, t.pests)
	if t.is_wilted(GameState.wilt_after()):
		sprite.modulate = WILTED_TINT
	elif not plot.under_glass and t.crop.rests_during(GameState.season_id()):
		sprite.modulate = RESTING_TINT
	else:
		sprite.modulate = Color.WHITE
	_set_crop_solid(sprite, _solid_size(t))


## How much of the crop on `t` the player bumps into: nothing for most crops;
## a trellis crop once it's come up (DECISIONS 047); a tree's trunk; the
## whole of a giant, bar a pixel round the edge (DECISIONS 048).
func _solid_size(t: FarmTile) -> Vector2:
	if t.giant:
		return Vector2(t.span() * TILE_PX - 2, t.span() * TILE_PX - 4)
	if not t.crop.is_solid_at(t.crop_stage):
		return Vector2.ZERO
	return TRUNK_SIZE if t.span() > 1 else SOLID_CROP_SIZE


## Give the crop sprite a body of `size` the player bumps into, or take it
## away (a zero size). The body is a child of the sprite, so it goes when
## the crop does; one of the wrong size (a crop that went giant) is replaced.
func _set_crop_solid(sprite: Sprite2D, size: Vector2) -> void:
	var body := sprite.get_node_or_null(^"Solid")
	if body != null and body.get_meta(&"size", Vector2.ZERO) != size:
		sprite.remove_child(body)
		body.queue_free()
		body = null
	if size == Vector2.ZERO or body != null:
		return
	body = StaticBody2D.new()
	body.name = "Solid"
	body.set_meta(&"size", size)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	body.add_child(shape)
	sprite.add_child(body)


## Show aphids over the crop sprite, or take them away (DECISIONS 048). A
## child of the sprite, so it goes with the crop; it sits over the tile
## itself, whatever the crop's height.
func _set_crop_pests(sprite: Sprite2D, pests: bool) -> void:
	var overlay := sprite.get_node_or_null(^"Pests")
	if pests and overlay == null:
		overlay = Sprite2D.new()
		overlay.name = "Pests"
		overlay.texture = PESTS_TEXTURE
		overlay.position = Vector2(0, -TILE_PX / 2.0)
		sprite.add_child(overlay)
	elif not pests and overlay != null:
		sprite.remove_child(overlay)
		overlay.queue_free()


## Make the weeds at `cell` match FarmData: show them, or take them away.
## They stand in the y-sorted Entities a hair behind the tile's crop (one
## pixel up), so the tufts show either side of it rather than over it.
func _redraw_weeds(cell: Vector2i) -> void:
	var t: FarmTile = plot.tile(cell)
	if t == null:
		return
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
	for cell: Vector2i in plot.crows_landed:
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
	if not plot.has_cell(cell):
		return
	GroundTiles.draw(_ground, cell, _atlas_for(cell))
	_redraw_feed(cell)


## Show the fertiliser in the soil at `cell`, or take its picture away.
func _redraw_feed(cell: Vector2i) -> void:
	var fed := plot.fertiliser_at(cell)
	var sprite: Sprite2D = _feed_sprites.get(cell)
	if fed == null or fed.soil_look == null:
		if sprite != null:
			sprite.queue_free()
			_feed_sprites.erase(cell)
		return
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = Vector2(cell * TILE_PX)
		_feed_layer.add_child(sprite)
		_feed_sprites[cell] = sprite
	sprite.texture = fed.soil_look


## The one place that decides what a FarmTile looks like. The season decides
## which tileset these coordinates point into (_apply_season_theme), never
## which coordinates are used.
func _atlas_for(cell: Vector2i) -> Vector2i:
	var t: FarmTile = plot.tile(cell)
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
	for cell: Vector2i in plot.cells():
		_place_object(cell)


## Show whatever FarmData says stands at `cell`. What scene that is comes from
## its ObjectDef (data/objects/), so a new kind of object needs no code here.
func _place_object(cell: Vector2i) -> void:
	var t: FarmTile = plot.tile(cell)
	if t == null:
		return
	var object_id: StringName = t.object_id
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
		_skin_object(_object_nodes[cell], plot.tile(cell).object_id)


## Show `node` with the current season's picture for `object_id`, if the
## season has one (SeasonLook).
func _skin_object(node: Node, object_id: StringName) -> void:
	SeasonLook.skin_object(node, object_id)


## Replace the screen overlays with this season's and today's weather's
## (falling rain or snow), or none.
func _apply_season_overlay() -> void:
	SeasonLook.apply_overlay(_weather)
