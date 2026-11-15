class_name SeasonTheme
extends Resource
##
## SeasonTheme — one season of the calendar: its name, and how the world looks
## while it lasts (DECISIONS 005, 021, 025).
##
## GameRules.seasons lists these in calendar order; GameState.season is an
## index into that list. Which crops grow when is NOT here: each crop lists the
## season ids it grows in (CropDef.seasons), so adding a crop never means
## editing four season files.
##
## The rule that makes swapping safe: every season's ground tileset has the
## SAME atlas layout — grass at the same coordinates, tilled soil at the same
## coordinates, and so on — differing only in the pixels. That's exactly what
## image-to-image from one base tileset produces. So the farm can swap the
## tileset and redraw, and every tile lands in the right place.
##

## Crops name seasons by this id (&"spring"), so it must not change once
## crops refer to it. display_name is free to change.
@export var id: StringName
@export var display_name: String

@export var ground_tileset: TileSet

## Different pictures for objects this season, by object id — for
## example &"tree" -> a bare or snowy tree. Buildings are looked up by their
## location id the same way (&"farmhouse" -> the snowy-roofed house), and their
## seasonal picture must be the same size as the normal one. The object's scene must have a
## Sprite2D called "Sprite" (they all do). Anything not listed keeps the
## picture its scene was built with.
@export var object_sprites: Dictionary[StringName, Texture2D] = {}

## Optional scene added to the farm and town while this season lasts, such as
## winter's falling snow (scenes/snowfall.tscn). Empty for none.
@export var overlay: PackedScene

## A colour the whole outdoor world is multiplied by this season — white for
## none, a pale blue for winter's chill. Daylight combines it with the time
## of day's colour (DECISIONS 036), since a scene can only have one tint.
@export var light_tint: Color = Color.WHITE
