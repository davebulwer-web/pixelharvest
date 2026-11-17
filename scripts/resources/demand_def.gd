class_name DemandDef
extends Resource
##
## DemandDef — how a buyer takes being flooded with one thing (DECISIONS 063).
##
## Every buyer (the shipping bin, Marlow's counter, Rosa's stall, Mabel's
## bakery) pays its full rate for the first `full_price_count` of an item it
## buys in a day. After that each further one pays `drop_per_extra` less of
## the full rate than the one before, never below `lowest_rate` of it. By the
## morning the buyer has sold it all on and pays full price again.
##
## So 20 parsnips all go to the bin at full price, but 80 of them are better
## split between the bin, Marlow and Rosa: the same harvest earns more for the
## walk. Each buyer counts separately, and each item separately, so a mixed
## crop isn't hurt at all.
##
## The sums are here, on the data, so the bin, the shop menu and the tests
## all use the same ones. Nothing in this file may touch an autoload: it is
## loaded with game_rules.tres, before the autoloads exist (DECISIONS 021).
##

## How many of one item the buyer takes at full price in a day.
@export var full_price_count: int = 20

## How much less each one after that pays, as a share of the full rate:
## 0.02 is 2% less for each further one.
@export_range(0.0, 1.0, 0.005) var drop_per_extra: float = 0.02

## The least the buyer ever pays, as a share of the full rate.
@export_range(0.0, 1.0, 0.05) var lowest_rate: float = 0.5


## The share of the full rate paid for one more of an item when `already`
## have been bought today (so the first is already = 0).
func rate_for(already: int) -> float:
	if already < full_price_count:
		return 1.0
	var extra := already - full_price_count + 1
	return maxf(lowest_rate, 1.0 - drop_per_extra * extra)


## What `amount` more of an item fetch together, at `full` gold each, when
## `already` have been bought today. Each is rounded on its own and never
## pays less than 1 gold, so a cheap thing still sells.
static func total_for(demand: DemandDef, full: int, already: int, amount: int) -> int:
	if full <= 0 or amount <= 0:
		return 0
	if demand == null:
		return full * amount
	var total := 0
	for n in amount:
		total += maxi(1, roundi(full * demand.rate_for(already + n)))
	return total


## True if one more of an item pays less than full price, with `already`
## bought today.
static func is_flooded(demand: DemandDef, already: int) -> bool:
	return demand != null and demand.rate_for(already) < 1.0
