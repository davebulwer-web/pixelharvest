class_name CrabPotRules
extends Resource
##
## CrabPotRules — the numbers behind crab pots (DECISIONS 065): what baits
## one, what turns up in it, and how long it takes.
##
## A crab pot is made at the workbench (Tam's plans) and dropped off the
## Cove's pier. With bait in it, it fills overnight; the next day (or any day
## after) E on it hauls it up and empties it into the bag, and it's baited
## again from the bag if there's anything to bait it with. What it catches is
## settled by dice seeded with the pot's cell and the day it was baited, so
## hauling it up after a reload gives the same thing.
##
## One file, data/crab_pot_rules.tres, which game_rules.tres points at, so
## tuning the pots never means touching code (rule 6).
##
## Must not use the GameState autoload: game_rules.tres preloads this file,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

## What baits a pot, in the order it's taken from the bag: the first of these
## the bag has is used up. Wren's bait, and the rockpools' winkles, mussels
## and shrimps, which crabs like just as well.
@export var bait: Array[ItemDef] = []

## How many days a baited pot takes to fill: 1 means it's ready the next
## morning.
@export var days_to_fill: int = 1

## What a full pot holds, by weight against the others (10 common, 1 rare).
## One of these, rolled when it's hauled up.
@export var catches: Dictionary[ItemDef, int] = {}

## The chance of a second thing in the pot as well (rolled the same way).
@export_range(0.0, 1.0, 0.05) var second_catch_chance: float = 0.2

## The item a pot is in the bag (data/tools/), given back when an empty pot
## is pulled up with nothing to bait it.
@export var pot_item: StringName = &"crab_pot"

## Energy to haul a pot up, empty it and bait it again (paid only when it's
## hauled, not to look at it or bait an empty one).
@export var haul_energy: float = 2.0


## The first item in `bait` that `bag` has, or null.
func bait_in(bag: Inventory) -> ItemDef:
	for each in bait:
		if each != null and bag != null and bag.count(each) > 0:
			return each
	return null


## What the pot at `cell`, baited on day `baited_day`, has in it: a list of
## items (one, now and then two). The same every time it's asked.
func catch_for(cell: Vector2i, baited_day: int) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([cell, baited_day, "crab_pot"])
	var first := _roll(dice)
	if first != null:
		result.append(first)
	if dice.randf() < second_catch_chance:
		var second := _roll(dice)
		if second != null:
			result.append(second)
	return result


func _roll(dice: RandomNumberGenerator) -> ItemDef:
	var total := 0
	for item: ItemDef in catches:
		total += maxi(0, catches[item])
	if total <= 0:
		return null
	var roll := dice.randi_range(1, total)
	for item: ItemDef in catches:
		roll -= maxi(0, catches[item])
		if roll <= 0:
			return item
	return null
