class_name GameRules
extends Resource
##
## GameRules — the starting conditions and global balance numbers for a new game.
##
## Rule 6 says no balance numbers in scripts, and that includes "how much gold
## do you start with". They live in data/game_rules.tres, where they can be
## changed in the inspector without touching code. The difficulty chosen at
## new game (DifficultyDef, DECISIONS 040) scales some of them; it never
## replaces them.
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

## --- The clock (DECISIONS 035) ---------------------------------------------
## Times are minutes after midnight, so 6 AM is 360. A day that runs past
## midnight keeps counting: 2 AM the next morning is 26 × 60 = 1560.

## When every day starts: the time you wake up.
@export var day_start_minutes: int = 360

## When the day ends if you're still up. You collapse, like running out of
## energy, and wake at home. Energy is meant to run out first on a busy day;
## this is what stops a day with energy to spare lasting for ever.
@export var day_end_minutes: int = 1560

## The clock moves in 10-minute steps; this is how many real seconds each one
## takes while the game is running (it stops in menus and conversations).
## At 7 seconds, 6 AM to 2 AM takes 14 real minutes.
@export var seconds_per_ten_minutes: float = 7.0

## From this time on, the HUD warns that it's late (a message once, and the
## clock turns red-ish). Midnight.
@export var late_warning_minutes: int = 1440

## --- Difficulty (DECISIONS 040) -------------------------------------------

## The difficulties offered at new game, in the order the menu lists them.
@export var difficulties: Array[DifficultyDef] = []

## The one the menu starts on, and what older saves (from before difficulty
## existed) and anything else that doesn't say are played at.
@export var default_difficulty: StringName = &"standard"


## The difficulty with id `id`, or null if there's no such one here.
func find_difficulty(id: StringName) -> DifficultyDef:
	for each in difficulties:
		if each.id == id:
			return each
	return null


## default_difficulty, or the first listed if that id isn't listed. With none
## listed at all, a plain DifficultyDef (every multiplier 1.0) so the game
## still works, exactly as it did before difficulty existed.
func standard_difficulty() -> DifficultyDef:
	var found := find_difficulty(default_difficulty)
	if found != null:
		return found
	if not difficulties.is_empty():
		return difficulties[0]
	var plain := DifficultyDef.new()
	plain.id = default_difficulty
	plain.display_name = "Standard"
	return plain
