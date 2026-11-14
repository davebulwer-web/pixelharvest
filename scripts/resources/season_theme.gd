class_name SeasonTheme
extends Resource
##
## SeasonTheme — how the world looks in one season (DECISIONS 005).
##
## Only the look. Which crops grow when is a property of the crop (Stage 6),
## not of the theme.
##
## The rule that makes swapping safe: every season's ground tileset has the
## SAME atlas layout — grass at the same coordinates, tilled soil at the same
## coordinates, and so on — differing only in the pixels. That's exactly what
## image-to-image from one base tileset produces. So the farm can swap the
## tileset and redraw, and every tile lands in the right place.
##
## Tree and prop textures join this in Stage 6 alongside the seasonal art.
##

@export var id: StringName
@export var display_name: String
@export var ground_tileset: TileSet
