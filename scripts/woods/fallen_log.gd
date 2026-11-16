class_name FallenLog
extends StaticBody2D
##
## FallenLog — a log lying across two tiles in the Woods, for the axe to chop
## into timber (DECISIONS 053). Solid, like a tree's trunk.
##
## It's only the picture and the bump: chopping is the Woods' business (the
## axe asks Woods.choppable_at, and Woods.chop removes this node). E on it
## says what it's for, so a player without an axe knows there's a use.
##
## The origin is the bottom-middle of its two tiles, like everything on a map.
##

const TILE_PX := 16
const SPRITE: Texture2D = preload("res://assets/sprites/woods/fallen_log.png")

## The left-hand of its two cells.
var cell: Vector2i


static func create(at: Vector2i) -> FallenLog:
	var fallen := FallenLog.new()
	fallen.name = "Log_%d_%d" % [at.x, at.y]
	fallen.cell = at
	fallen.position = Vector2((at.x + 1) * TILE_PX, (at.y + 1) * TILE_PX)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = SPRITE
	sprite.offset = Vector2(0, -TILE_PX / 2.0)
	fallen.add_child(sprite)

	# The log itself, not the space above it: walk up to it from any side.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 7)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -5)
	fallen.add_child(collision)
	return fallen


func _ready() -> void:
	add_to_group(&"interactable")


func occupies(at: Vector2i) -> bool:
	return at == cell or at == cell + Vector2i.RIGHT


func interact() -> void:
	var tool := GameState.selected_tool()
	if tool != null and tool.action is ChopAction:
		EventBus.message_posted.emit("Space swings the axe")
	else:
		EventBus.message_posted.emit("A fallen log. An axe would make timber of it")
