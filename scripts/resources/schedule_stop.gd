class_name ScheduleStop
extends Resource
##
## ScheduleStop — one line of someone's day (DECISIONS 067): from this time,
## they're at this place, standing on this cell. "From 2 PM, Mabel is in the
## town square by the bench."
##
## A stop's place is a LocationDef id, either an outdoor map (&"town",
## &"lane", &"cove"), where they stand on `cell` and can be talked to, or a
## building (&"bakery", &"pip_cottage"), where they're indoors: behind the
## counter of a shop you can walk into, or at home, where knocking on the
## door brings them out to talk. An empty place means they're away from the
## valley's maps altogether (the mayor's evenings, until his house is built
## in Stage 22's second session).
##
## Nothing in this file may touch an autoload (it is plain data).
##

## When this stop begins, in minutes after midnight (840 is 2 PM). The
## person stays here until the next stop's time.
@export var at: int = 360

## Where: a LocationDef id, or empty for "away".
@export var place: StringName = &""

## The cell they stand on, on an outdoor place's map. Ignored indoors.
@export var cell: Vector2i

## How the request log says where they are: "by the fountain in town",
## "fishing off the pier". Empty: the place's name is used.
@export var words: String = ""
