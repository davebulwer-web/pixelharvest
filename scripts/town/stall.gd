class_name Stall
extends StaticBody2D
##
## Stall — a market stall standing on a map for the day: its picture and a
## solid counter (DECISIONS 037).
##
## Made entirely from a StallDef. The keeper is a separate Npc, built by
## keeper_for(), so the map can y-sort the two: the keeper stands one row
## behind the counter and shows through the stall's open middle. As at a shop
## counter indoors, you can't reach the keeper, so facing any of the counter's
## three cells counts as talking to them.
##
## The origin is the bottom-middle of the stall's cell, like everything else
## standing on a map.
##

const TILE_PX := 16

## How tall the solid part is, from the bottom: the counter, not the awning.
const COUNTER_DEPTH := 14.0


static func create(def: StallDef) -> Stall:
	var stall := Stall.new()
	stall.name = "Stall_%s" % def.shop.id
	stall.position = Vector2(def.cell.x * TILE_PX + TILE_PX / 2.0, (def.cell.y + 1) * TILE_PX)

	if def.picture != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = def.picture
		sprite.offset = Vector2(0, -def.picture.get_height() / 2.0)
		stall.add_child(sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(3 * TILE_PX, COUNTER_DEPTH)
	shape.shape = box
	shape.position = Vector2(0, -COUNTER_DEPTH / 2.0)
	stall.add_child(shape)
	return stall


## The keeper behind the counter, answering E on any of its three cells.
static func keeper_for(def: StallDef) -> Npc:
	var keeper := Npc.create(def.shop.id, def.shop.keeper_sprite, def.cell + Vector2i.UP)
	keeper.talk_cells.clear()
	for dx in [-1, 0, 1]:
		keeper.talk_cells.append(def.cell + Vector2i(dx, 0))
	return keeper
