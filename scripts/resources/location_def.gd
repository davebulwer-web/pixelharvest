class_name LocationDef
extends Resource
##
## LocationDef — one place the player can be: the farm, the Lane, the town,
## the Woods, a shop or the farmhouse.
##
## A location is just an id and the scene that shows it. A home seen only
## from outside (Pip's family's cottage on the Lane; DECISIONS 061) has no
## scene: its door says who lives there instead (`door_words`). All of its *state*
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

## The door's cell on that map, and the picture of the building. The doorway
## is two tiles wide (32 px) in the middle of the picture's bottom row
## (Building). A picture an odd number of tiles wide (the shops' 80 × 64,
## five tiles) is centred on the door cell, so the doorway takes in half of
## each neighbour; one an even number wide (the new size, DECISIONS 061:
## Pip's cottage, 128 × 96) has its doorway on the door cell and the cell to
## its right, so a two-tile path leads straight in. art/STYLE.md has the
## building size rule.
@export var door_cell: Vector2i
@export var exterior: Texture2D

## For a building with no inside (`scene_path` empty): what its door says
## when the player walks up to it, e.g. "Pip's family live here." The door
## stays shut. Homes are seen from outside only for now (ROADMAP 13.2).
@export_multiline var door_words: String = ""


## True for a building that can't be gone into: a home seen from outside.
func has_inside() -> bool:
	return scene_path != ""

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

## --- Ways out (DECISIONS 060) ---------------------------------------------------
## For an outdoor map: the roads from here to the places next door, each a gap
## in the edge, where it leads, and where you stand coming back in that way.
## Exits (scripts/exits.gd) builds them, so a new road is data, not code.
## Buildings don't need these: their door is `door_cell` on their outside.
@export var exits: Array[ExitDef] = []
