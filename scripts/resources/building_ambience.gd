class_name BuildingAmbience
extends Resource
##
## BuildingAmbience — where a building's chimneys and windows are in its
## picture, so its chimneys smoke and its windows light up after dark
## (DECISIONS 088). One file per building in data/ambience/buildings/, named
## by the building's location id (bakery.tres for the bakery).
##
## Positions are in pixels of the building's picture (LocationDef.exterior),
## counted from its top-left corner, as an image editor shows them. A new
## building gets smoke and lit windows by adding a file like these; no code.
##

## The LocationDef id of the building this is for.
@export var location_id: StringName

## The top middle of each chimney: smoke rises from here.
@export var chimneys: Array[Vector2i] = []

## Each window's box (x, y, width, height). After dark the glass inside it
## (its blue and pale pixels, not the frame) glows a warm lamp-lit yellow.
@export var windows: Array[Rect2i] = []
