class_name LocationDef
extends Resource
##
## LocationDef — one place the player can be: the farm now, the town in Stage 7.
##
## A location is just an id and the scene that shows it. All of its *state*
## lives in GameState (the farm's in FarmData), never in the scene, so the scene
## can be thrown away when the player leaves and rebuilt when they come back.
##
## Adding a location is a new scene plus a new .tres here, listed in
## data/game_rules.tres. LocationManager needs no change.
##

@export var id: StringName
@export var display_name: String

## The scene's path, not the scene itself. A PackedScene field would load every
## location's scene (and its art) the moment the game starts, and would make a
## loop: rules -> location -> farm scene -> scripts that read the rules. A path
## is only loaded when the player actually goes there.
@export_file("*.tscn") var scene_path: String

## --- Buildings -----------------------------------------------------------------
## A location that is a room entered through a door on another location's map
## (a shop, in Stage 7) says where that door is. The outside location builds
## the building from these, so adding a shop never edits the town's code.

## The location whose map has this room's door; empty for a location that
## isn't a building.
@export var outside: StringName = &""

## The door's cell on that map, and the picture of the building. The picture's
## bottom-middle sits on the bottom of the door cell, so the door is the
## middle tile of its bottom row (80×64 for the shops: five tiles wide, with a
## 32px doorway).
@export var door_cell: Vector2i
@export var exterior: Texture2D

## Set for a shop interior: who runs it and what it offers.
@export var shop: ShopDef
