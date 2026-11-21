class_name AmbientEffect
extends Resource
##
## AmbientEffect — one kind of little moving thing that comes and goes by
## itself on the outdoor maps: butterflies, a sparkle on the water, a leaf
## drifting down, a gull going over (DECISIONS 088). Ambience
## (scripts/ambience/ambience.gd) reads every file in data/ambience/effects/
## and plays it where and when this file says.
##
## Decoration only: nothing here is saved, and no rule reads it. Copying one
## of these files and pointing it at another picture is how a new one is
## added; no code to change. The picture is a strip of frames side by side,
## named like Dave's scenery's (..._4f.png is 4 frames).
##

## How the thing moves.
enum Motion {
	## Plays its strip once on a spot of the right ground, then goes
	## (a sparkle, a ripple, a fish jumping).
	ONCE,
	## Hovers about a spot, drifting this way and that, for a while
	## (butterflies, fireflies).
	WANDER,
	## Crosses the screen from one side to the other, high up (birds).
	FLY_ACROSS,
	## Drifts slowly down and sideways from above, then fades (leaves).
	FALL,
}

## What kind of ground the spot is on. ANY is anywhere on the map.
enum Ground { ANY, GRASS, POND, SEA, WATER }

@export var id: StringName

## The pictures, any one picked each time (butterflies come in five colours).
## Paths as text on purpose: the packs' pictures aren't in git, and a missing
## one just means this effect doesn't play, rather than the file not loading.
@export var pictures: PackedStringArray = []

@export var motion: Motion = Motion.ONCE
@export var ground: Ground = Ground.ANY

## The maps it plays on (farm, lane, town, woods, cove). Empty: all of them.
@export var places: Array[StringName] = []
## The seasons it plays in (spring, summer, autumn, winter). Empty: all.
@export var seasons: Array[StringName] = []
## Only in this weather (sunny, rain, storm, heatwave, snow, frost). Empty:
## any weather not in `not_weather`.
@export var weather: Array[StringName] = []
@export var not_weather: Array[StringName] = []

## The hours it plays, in minutes after midnight (6 AM is 360, 8 PM is
## 1200). `from` later than `until` wraps past midnight (fireflies: 1230 to
## 240 is 8:30 PM to 4 AM). Both 0: all day and night.
@export var from_minute: int = 0
@export var until_minute: int = 0

## How many start a minute, on average, while the farmer is on that map.
@export var per_minute: float = 6.0
## No more than this many at once.
@export var most_at_once: int = 3
## How many come together (a few songbirds fly in a little flock).
@export var flock: int = 1

## Seconds each frame shows.
@export var frame_seconds: float = 0.12
## How fast it moves, in pixels a second (WANDER, FLY_ACROSS, FALL).
@export var speed: float = 12.0
## How long a WANDER or FALL one stays, in seconds (a little more or less).
@export var lifetime: float = 20.0

## Drawn as light (added to what's under it), so it shows at night: fireflies.
@export var glows: bool = false
## Drawn over the people and things standing (butterflies, birds, leaves)
## rather than on the ground under them (sparkles, ripples, fish).
@export var above: bool = true
## How see-through it is: 1 is solid.
@export_range(0.1, 1.0, 0.05) var opacity: float = 1.0


## True if it plays at `minute` (minutes after midnight; past 1440 wraps).
func plays_at(minute: int) -> bool:
	if from_minute == until_minute:
		return true
	var m := minute % 1440
	if from_minute < until_minute:
		return m >= from_minute and m < until_minute
	return m >= from_minute or m < until_minute
