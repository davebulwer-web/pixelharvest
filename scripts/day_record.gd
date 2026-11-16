class_name DayRecord
extends RefCounted
##
## DayRecord — one day's tally, kept by DayReport and shown by DaySummary
## (DECISIONS 042). Plain numbers, so the summary screen only has to show it.
##

var day: int
var season: int
var year: int
## Produce item id -> how many were picked.
var harvested: Dictionary[StringName, int] = {}
var planted: int = 0
## Tiles watered by the player. Sprinklers water overnight and aren't counted.
var watered: int = 0
## Gold in: every coin that came in, and of that, how much was from the
## shipping bin overnight and from shop counters and market stalls.
var gold_in: int = 0
var bin_sales: int = 0
var shop_sales: int = 0
## Gold out: seeds, decorations, upgrades.
var spent: int = 0
## Requests handed in today, by QuestDef id.
var quests_done: Array[StringName] = []
## Requests that ran out tonight, by title (DECISIONS 050): orders are
## cleared away by morning, so their names are kept rather than their ids.
var quests_expired: Array[String] = []
## What opened up, by UnlockDef id: from requests handed in during the day,
## and from the calendar overnight (DECISIONS 043).
var unlocked: Array[StringName] = []
## Patches of weeds pulled or hoed out (DECISIONS 045).
var weeds_pulled: int = 0
## Crops lost overnight, by cause (&"season", &"thirst", &"crows", &"frost")
## -> count.
var lost: Dictionary[StringName, int] = {}
## The crops crows took overnight, by crop id, for the morning's news.
var taken_by_crows: Array[StringName] = []
## Giants that grew overnight, by crop id (DECISIONS 048).
var giants: Array[StringName] = []
## Fish landed, by fish id -> how many (DECISIONS 054).
var caught: Dictionary[StringName, int] = {}
## What hives (or anything else that makes things) made overnight, by item
## id -> how many are waiting to be collected (DECISIONS 057).
var made: Dictionary[StringName, int] = {}
## Gold in the purse when the night's sales were done.
var gold_at_end: int = 0


## Whatever came in that wasn't a sale: request rewards.
func other_income() -> int:
	return maxi(0, gold_in - bin_sales - shop_sales)


func income() -> int:
	return gold_in


## Gold gained (or lost) over the day, the night's bin sales included.
func net() -> int:
	return income() - spent


## True if nothing at all happened worth listing.
func is_quiet() -> bool:
	return harvested.is_empty() and planted == 0 and watered == 0 \
			and income() == 0 and spent == 0 and quests_done.is_empty() and unlocked.is_empty() \
		and quests_expired.is_empty() \
		and weeds_pulled == 0 and lost.is_empty() and giants.is_empty() and caught.is_empty()
