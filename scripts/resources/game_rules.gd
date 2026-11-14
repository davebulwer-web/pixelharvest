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

## The seasons in calendar order. GameState.season is an index into this.
## One for now; Stage 6 adds the other three and the season length.
@export var seasons: Array[SeasonTheme] = []
