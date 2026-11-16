class_name LureDef
extends ItemDef
##
## LureDef — a lure: something an angler keeps in the bag and ties on when
## the season's right (DECISIONS 055). Wren's winter lure is the first.
##
## Unlike bait, a lure is never used up. While it's in the bag and today's
## season is one of its `seasons`, every cast waits `wait_multiplier` times
## as long (0.5: a bite twice as soon), and any bait stays in its tin. The
## fishing rules list the lures there are (FishingRules.lures), as they list
## the bait.
##
## It is an item like any other (name, icon, price), so it sits in the bag
## and can be sold. Kept in data/produce/ with the bait.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## The seasons it works in, by id. Empty: all year.
@export var seasons: Array[StringName] = []

## How long the float waits with it on, as a multiple of the usual wait.
@export var wait_multiplier: float = 0.5


## True if it does anything on a day of `season_id`.
func works_in(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons
