class_name ContestRival
extends Resource
##
## ContestRival — someone else who enters a contest (DECISIONS 059): who
## they are, what they bring, and how well it can score. Their score is
## rolled between `min_score` and `max_score` each time, with the day's dice.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## "Mrs Pell", "the vicar".
@export var name: String

## What they enter, as it's read out: "a sweet pea", "a perch".
@export var entry: String

@export var min_score: int = 0
@export var max_score: int = 0
