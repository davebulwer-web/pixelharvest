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

## The tune that plays here, looping (DECISIONS 042). A building left empty
## plays its outside's tune: the shops have the town's, the farmhouse the
## farm's, so walking indoors doesn't restart the music.
@export var music: AudioStream

## --- Buildings -----------------------------------------------------------------
## A location that is a room entered through a door on another location's map
## (a shop or the farmhouse, in Stage 7) says where that door is. The outside location builds
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

## --- Opening up (DECISIONS 043) -------------------------------------------------
## A building whose door stays locked until this is earned: Brann's forge, shut
## until he's back from the city. Null: open from the start (opening hours
## still apply). The building stands on the map either way.
@export var requires_unlock: UnlockDef

## What the player is told at the locked door. Empty: "<name> is shut."
@export var locked_message: String = ""

## --- Foraging (DECISIONS 052) -----------------------------------------------------
## How many spots get something wild each morning (a mushroom, berries), out of
## the spots the location's map offers. 0: no foraging here.
@export var forage_per_day: int = 0

## --- Timber (DECISIONS 053) -------------------------------------------------------
## How many fallen logs lie about each morning, for the axe, out of the places
## the location's map offers. 0: none here.
@export var fallen_logs_per_day: int = 0

## --- A building waiting to be mended (DECISIONS 057) ----------------------------
## The picture shown while requires_unlock hasn't been earned: the farm's old
## greenhouse, broken until Ivy's request mends it. Null: the building looks
## the same locked or not (Brann's forge).
@export var locked_exterior: Texture2D
