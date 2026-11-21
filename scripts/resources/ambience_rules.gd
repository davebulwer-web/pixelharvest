class_name AmbienceRules
extends Resource
##
## AmbienceRules — the few numbers the little moving things share
## (DECISIONS 088): chimney smoke's picture and pace, how lit windows look,
## and how many things may move at once. One file:
## data/ambience/ambience_rules.tres. Each kind of moving thing has its own
## file in data/ambience/effects/ (AmbientEffect), each building's chimneys
## and windows theirs in data/ambience/buildings/ (BuildingAmbience).
##

## Chimney smoke: a strip of frames rising from the chimney (as text: a pack
## picture, kept out of git; missing means no smoke).
@export var smoke_picture: String = "res://assets/scenery/ambient/chimney_smoke_anim_5f.png"
@export var smoke_frame_seconds: float = 0.2
@export_range(0.1, 1.0, 0.05) var smoke_opacity: float = 0.8

## The glow on a lit window's glass, and how strong it is at full night.
## Above 1 on purpose: the night's dark blue tint darkens it, as with the
## town's lamps (Daylight).
@export var window_colour: Color = Color(1.0, 0.8, 0.42)
@export var window_strength: Color = Color(2.6, 2.0, 1.4)
## A soft halo round each lit window (0 for none).
@export_range(0.0, 1.0, 0.05) var window_halo: float = 0.35

## No more than this many moving things on screen at once, all kinds together.
@export var most_at_once: int = 24
