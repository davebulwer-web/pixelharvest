class_name GameRules
extends Resource
##
## GameRules — the starting conditions and global balance numbers for a new game.
##
## Rule 6 says no balance numbers in scripts, and that includes "how much gold
## do you start with". They live in data/game_rules.tres, where they can be
## changed in the inspector without touching code. In Stage 8 a DifficultyDef
## will scale these; it will not replace them.
##

@export var starting_gold: int = 0
@export var max_energy: float = 100.0

## What's in the bag at the start of a new game, and how many of each, in
## hotbar order. Adding something to the starting kit is a data change here,
## never a code change.
@export var starting_inventory: Dictionary[ItemDef, int] = {}

## Every place in the world, and where a new game begins.
@export var locations: Array[LocationDef] = []
@export var starting_location: StringName = &"farm"

## Where the bed is: the location the player wakes up in every morning. Going
## to bed there ends the day; running out of energy anywhere else ends it too,
## and the player wakes up here (DECISIONS 033).
@export var home_location: StringName = &"farmhouse"

## The seasons in calendar order. GameState.season is an index into this;
## after the last one the year rolls over and the first comes round again.
@export var seasons: Array[SeasonTheme] = []

## How many days each season lasts. On the night after the last day, the
## season turns and crops that can't grow in the new one die (DECISIONS 025).
## Lower it (to 3, say) to try out the seasons quickly — and put it back.
@export var days_per_season: int = 28
