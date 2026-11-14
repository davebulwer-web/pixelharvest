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

## The tools in the player's hands at the start of a new game, in toolbar order.
## Adding a tool to the starting kit is a data change here, never a code change.
@export var starting_tools: Array[ToolDef] = []
