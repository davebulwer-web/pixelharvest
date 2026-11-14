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
