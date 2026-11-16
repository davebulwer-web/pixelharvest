class_name ObjectDef
extends Resource
##
## ObjectDef — something that stands on a map tile: a tree, the shipping bin,
## a sprinkler on the farm; a fountain, a bench or a lamp post in town.
##
## FarmTile only records the id (`object_id`); this says what that id means —
## the scene that shows it, whether the player can pick it back up, and
## whether it waters the ground around it each morning. The farm scene used
## to have a hardcoded list of object scenes; now a new kind of object is a
## .tres in data/objects/ and a scene, nothing else (rule 3). The town uses
## the same files for its decoration (TownLayout.OBJECTS), so a winter
## picture for any of them is one line in a SeasonTheme's object_sprites.
##

@export var id: StringName
@export var display_name: String

## Instanced at the bottom-middle of the object's tile.
@export var scene: PackedScene

## What the player gets back for picking it up with E. Empty means it can't
## be picked up (trees, the shipping bin).
@export var item: ItemDef

## Tiles this object waters every morning, as steps from its own tile:
## (0, -1) is the tile above. Empty for anything that isn't a sprinkler.
@export var water_offsets: Array[Vector2i] = []

## Crows keep away from every crop within this many tiles (a circle round
## this tile; DECISIONS 045). 0 for anything that doesn't scare them. The
## scarecrow's is 8.
@export var protects_radius: int = 0

## A storm can't flatten a tall crop within this many tiles (a square round
## this tile, so 1 is the eight tiles touching it; DECISIONS 047). 0 for
## anything that gives no shelter. The garden fence's is 1.
@export var shelters_radius: int = 0

## --- Making things (DECISIONS 057) -------------------------------------------
## An object that makes something by itself over the days, like the bee hive
## and its honey. FarmData counts the days overnight (run_makers); what's
## made waits on the object's tile until the player collects it with E. A
## full object makes no more until it's emptied.

## What it makes (honey). Null for everything that makes nothing.
@export var makes: ItemDef

## How many nights it takes to make a batch.
@export var makes_every_days: int = 0

## How many it makes in a batch.
@export var makes_amount: int = 1

## The seasons it works in (bees sleep through winter). Empty: every season.
## Under glass (the greenhouse) it works all year.
@export var makes_in_seasons: Array[StringName] = []

## A flower within this many tiles (a square round it) adds `flower_bonus`
## to each batch: bees with flowers to visit make more honey. 0: flowers
## make no difference.
@export var flower_radius: int = 0
@export var flower_bonus: int = 0

## True for an object that counts as a flower to the bees (the flower bed).
## Flowering crops (an item tagged &"flower") count without this.
@export var counts_as_flower: bool = false
