class_name AllotmentBeds
extends Node
##
## AllotmentBeds — draws the allotment beds on the Lane as the Allotments
## service says they are (DECISIONS 062): weeds to pull, a holder's crop on
## dry soil to water, a bed gone back to grass to dig over, and what's been
## done today. A view only, like the farm's crops: it owns nothing, and
## redraws whenever a job is taken, worked, paid or runs out.
##
## The ground of each bed tile is redrawn on the Lane's Ground layer; weeds
## and crops are sprites among the Lane's y-sorted entities. Each weed is
## also something E can pull (AllotmentWeed), so weeding by hand needs
## nothing from the player but the usual E.
##

const TILE_PX := 16
const WEEDS_TEXTURE: Texture2D = preload("res://assets/sprites/farm/weeds.png")
const WEEDS_SKIN_ID := &"weeds"

var _ground: TileMapLayer
var _entities: Node2D

## cell -> the sprite on it (a weed or a crop), so a redraw can clear them.
var _sprites: Dictionary = {}  # Vector2i -> Node2D


static func create(ground: TileMapLayer, entities: Node2D) -> AllotmentBeds:
	var beds := AllotmentBeds.new()
	beds.name = "AllotmentBeds"
	beds._ground = ground
	beds._entities = entities
	return beds


func _ready() -> void:
	EventBus.allotment_worked.connect(func(_p: int, _w: StringName, _c: Vector2i) -> void: redraw())
	EventBus.quest_started.connect(func(_id: StringName) -> void: redraw())
	EventBus.quest_completed.connect(func(_id: StringName) -> void: redraw())
	EventBus.quest_expired.connect(func(_id: StringName, _t: String) -> void: redraw())
	redraw()


## Every bed tile, drawn afresh.
func redraw() -> void:
	for cell: Vector2i in _sprites:
		_sprites[cell].queue_free()
	_sprites.clear()
	for plot in range(1, Allotments.bed_count() + 1):
		var crop := Allotments.crop_for(plot)
		for cell in Allotments.bed_cells(plot):
			_draw_cell(cell, Allotments.look_at(cell), crop)


func _draw_cell(cell: Vector2i, look: StringName, crop: CropDef) -> void:
	match look:
		Allotments.LOOK_ROUGH:
			GroundTiles.draw(_ground, cell, GroundTiles.grass_for(cell))
		Allotments.LOOK_WATERED:
			GroundTiles.draw(_ground, cell, GroundTiles.TILLED_WET)
		_:
			GroundTiles.draw(_ground, cell, GroundTiles.TILLED)
	if look == Allotments.LOOK_WEEDS:
		var weed := AllotmentWeed.new()
		weed.cell = cell
		weed.position = _base_of(cell) - Vector2(0, 1)
		var texture := _weeds_texture()
		weed.texture = texture
		weed.offset = Vector2(0, -texture.get_height() / 2.0 + 1)
		_add(cell, weed)
	elif (look == Allotments.LOOK_DRY or look == Allotments.LOOK_WATERED) and crop != null:
		var sprite := Sprite2D.new()
		sprite.texture = crop.sprite_sheet
		sprite.hframes = crop.growth_stages + 1
		# Nearly ready: a holder's crop, well along.
		sprite.frame = maxi(crop.growth_stages - 1, 0)
		sprite.position = _base_of(cell)
		sprite.offset = Vector2(0, -crop.sprite_sheet.get_height() / 2.0)
		_add(cell, sprite)


func _add(cell: Vector2i, node: Node2D) -> void:
	_entities.add_child(node)
	_sprites[cell] = node


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


## This season's weeds, or the everyday ones (as the farm draws them).
func _weeds_texture() -> Texture2D:
	var theme := GameState.current_season_theme()
	var seasonal: Texture2D = theme.object_sprites.get(WEEDS_SKIN_ID) if theme != null else null
	return seasonal if seasonal != null else WEEDS_TEXTURE
