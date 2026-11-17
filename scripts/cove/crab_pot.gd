class_name CrabPot
extends Node2D
##
## CrabPot — a crab pot's float on the sea off the Cove's pier (DECISIONS
## 065): a picture of what GameState says is there, and E to use it.
##
## The pot itself is GameState's (where, and the day it was baited; saved).
## This node only shows it: a slack float for an empty pot, a float on a
## taut line for one baited and fishing, and a float with a flag up once it
## has had its night and is ready to haul. Like a forage spot it joins the
## "interactable" group, so E needs nothing new; GameState.use_crab_pot
## decides what E does, and the Cove redraws this from crab_pot_changed.
##
## The origin is the bottom-middle of its tile, like everything on a map.
##

const TILE_PX := 16

const EMPTY: Texture2D = preload("res://assets/sprites/cove/crab_pot_empty.png")
const SET: Texture2D = preload("res://assets/sprites/cove/crab_pot_set.png")
const READY: Texture2D = preload("res://assets/sprites/cove/crab_pot_ready.png")

var location_id: StringName
var cell: Vector2i

var _sprite: Sprite2D


static func create(where: StringName, at: Vector2i) -> CrabPot:
	var pot := CrabPot.new()
	pot.name = "CrabPot_%d_%d" % [at.x, at.y]
	pot.location_id = where
	pot.cell = at
	pot.position = Vector2(at.x * TILE_PX + TILE_PX / 2.0, (at.y + 1) * TILE_PX)
	pot._sprite = Sprite2D.new()
	pot._sprite.name = "Sprite"
	pot._sprite.offset = Vector2(0, -8)
	pot.add_child(pot._sprite)
	pot.refresh()
	# A gentle bob on the swell.
	var bob := pot._sprite.create_tween().set_loops()
	bob.tween_property(pot._sprite, ^"position:y", -1.0, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(pot._sprite, ^"position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	return pot


func _ready() -> void:
	add_to_group(&"interactable")


## Show the pot as it is now: empty, baited, or ready to haul.
func refresh() -> void:
	if GameState.crab_pot_ready(location_id, cell):
		_sprite.texture = READY
	elif GameState.crab_pot_baited_on(location_id, cell) > 0:
		_sprite.texture = SET
	else:
		_sprite.texture = EMPTY


## Which picture is showing, for tests: &"empty", &"set" or &"ready".
func look() -> StringName:
	if _sprite.texture == READY:
		return &"ready"
	return &"set" if _sprite.texture == SET else &"empty"


func occupies(at: Vector2i) -> bool:
	return at == cell


func interact() -> void:
	GameState.use_crab_pot(location_id, cell)
