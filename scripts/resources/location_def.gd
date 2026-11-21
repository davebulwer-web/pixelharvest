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

## A tune of this place's own, looping (DECISIONS 042). Left empty, a building
## plays its outside's tune, and a place with none plays the season's music
## (SeasonTheme.music, DECISIONS 066), which is what every place does since
## Dave's seasonal tunes: this is for somewhere that should sound different
## all year round, like a tavern one day.
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
## stays shut. A home you can go into (DECISIONS 084) says them too, when
## its door is shut outside visiting hours and nobody's in.
@export_multiline var door_words: String = ""


## True for a building that can't be gone into: a home seen from outside.
func has_inside() -> bool:
	return scene_path != ""

## --- A home you can go into (DECISIONS 084) -------------------------------------
## The townsfolk's homes are rooms (scenes/home.tscn, scripts/town/home.gd),
## one scene for all of them, shaped by these. A home's door is open in
## visiting hours; outside them it stays shut and knocking brings whoever's in
## to the door, as before the homes had insides (DECISIONS 067).

## The room's size in cells: the floor and the back wall's two-row face
## (y 0-1), not the wall round the edge.
@export var room_size: Vector2i = Vector2i(10, 7)

## The left of the door's two cells, in the room's bottom wall.
@export var room_door_x: int = 4

## Where whoever lives here stands while they're at home.
@export var resident_cell: Vector2i = Vector2i(6, 4)

## Visiting hours, in minutes after midnight: the door opens at `open_from`
## and shuts at `open_until`. -1 for both: never shut (a building that isn't
## a home, like the farmhouse).
@export var open_from: int = -1
@export var open_until: int = -1


## True if a home's door is open at `minute` (always, for one without hours).
func open_at(minute: int) -> bool:
	if open_from < 0 or open_until < 0:
		return true
	return minute >= open_from and minute < open_until

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

## How many of the spots the sea uncovers at low tide get something each
## morning (DECISIONS 064): the Cove's rockpools and sand bar. Only forage
## with `at_low_tide` turns up on them. 0: none.
@export var low_tide_forage_per_day: int = 0

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
