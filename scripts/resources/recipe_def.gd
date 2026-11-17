class_name RecipeDef
extends Resource
##
## RecipeDef — how to cook one dish at the farmhouse stove (DECISIONS 056),
## or make one thing at the workbench (DECISIONS 063): what goes in, and what
## comes out. One .tres in data/recipes/ per recipe; ContentDB finds them.
##
## Where it's made is `made_at`: &"stove" (a dish, `dish`) or &"workbench"
## (anything else, `item`: a fence, a scarecrow, bait). Both kinds are known
## the same way and kept in the same list (GameState.recipes), so a workbench
## plan is taught by a request exactly as a dish is, and saved the same way.
##
## A recipe is something the farmer *knows*, not something they carry: Mabel
## teaches the first three, her recipe book more, Wren one. Which are known
## is kept in GameState.recipes (saved, by id), with how many times each has
## been cooked, for the almanac later. This file can change freely.
##
## What goes in is a list of particular things (2 tomatoes) and, optionally,
## some of a kind (any fish, any 3 fruit), found by the items' tags, so a new
## fish is good for a fish pie without touching the recipe. The kind is taken
## cheapest first, so a pike isn't used where a minnow will do.
##
## Cooking is free and instant: no energy, no time. Its cost is the produce
## that could have been sold instead, which is the trade the stage is about
## (food for energy, not food for gold). Making something at the workbench is
## the same: its cost is the stone, timber and fibre that went in.
##
## Nothing in this file may touch an autoload (it is plain data): it's given
## the bag to look in.
##

## The places something can be made: the farmhouse stove and the farm's
## workbench.
const PLACES: Array[StringName] = [&"stove", &"workbench"]

@export var id: StringName

## Where it's made: one of PLACES.
@export var made_at: StringName = &"stove"

## The dish it makes, at the stove: a ToolDef with an EatAction, in data/dishes/.
@export var dish: ToolDef

## What it makes at the workbench, when it isn't a dish: a decoration, bait,
## a bag of mulch. Any item.
@export var item: ItemDef

## A recipe can be known as soon as an unlock is earned, rather than taught by
## a request: mending the workbench teaches the old farmer's first plans.
## Null: only a request teaches it (QuestDef.reward_recipes).
@export var taught_by_unlock: UnlockDef

## How many helpings one cooking makes.
@export var makes: int = 1

## Particular things that go in, and how many of each.
@export var ingredients: Dictionary[ItemDef, int] = {}

## And some of a kind: anything whose tags include this (&"fish",
## &"mushroom", &"fruit"). &"" for nothing of a kind.
@export var any_tag: StringName = &""

## How many of that kind.
@export var any_count: int = 0

## What to call one of that kind: "fish", "mushroom", "fruit".
@export var any_what: String = ""


## What one making of it gives: the dish, or the workbench's item.
func product() -> ItemDef:
	return dish if dish != null else item


## The product's name, which is what the farmer calls the recipe.
func display_name() -> String:
	var made := product()
	return made.display_name if made != null else String(id)


## True for a workbench plan rather than a dish.
func is_plan() -> bool:
	return made_at == &"workbench"


## True if `bag` holds everything that goes in.
func can_cook(bag: Inventory) -> bool:
	return missing(bag) == ""


## What `bag` is still short of, in words ("1 tomato and any fish"), or ""
## if nothing.
func missing(bag: Inventory) -> String:
	var parts: Array[String] = []
	for item: ItemDef in ingredients:
		var short := ingredients[item] - bag.count(item)
		if short > 0:
			parts.append("%d %s" % [short, QuestGoal.plural(item.display_name, short)])
	var short_of_kind := any_count - _kind_in(bag)
	if any_tag != &"" and short_of_kind > 0:
		parts.append(_kind_words(short_of_kind))
	return _join(parts)


## Everything that goes in, with how many `bag` has of each:
## "2 potatoes (have 3), any fish (have 0, the cheapest go in first)".
func ingredients_text(bag: Inventory) -> String:
	var parts: Array[String] = []
	for item: ItemDef in ingredients:
		var need: int = ingredients[item]
		parts.append("%d %s (have %d)" % [need, QuestGoal.plural(item.display_name, need), bag.count(item)])
	if any_tag != &"" and any_count > 0:
		parts.append("%s (have %d, the cheapest go in first)" % [_kind_words(any_count), _kind_in(bag)])
	return ", ".join(parts)


## Take everything that goes in out of `bag`. Only call after can_cook().
## Of a kind, the cheapest go first.
func take_from(bag: Inventory) -> void:
	for item: ItemDef in ingredients:
		bag.remove(item, ingredients[item])
	var still := any_count if any_tag != &"" else 0
	for item in kind_in_bag(bag):
		if still <= 0:
			break
		var take := mini(still, bag.count(item))
		bag.remove(item, take)
		still -= take


## The things of `any_tag` in `bag` that may go in, cheapest first. Ones
## listed by name in `ingredients` are left out, so they aren't counted twice.
func kind_in_bag(bag: Inventory) -> Array[ItemDef]:
	var found: Array[ItemDef] = []
	if any_tag == &"":
		return found
	for item in bag.items():
		if item.has_tag(any_tag) and not ingredients.has(item):
			found.append(item)
	# By price, then by name, so the same one is always picked first.
	found.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.sell_price != b.sell_price:
			return a.sell_price < b.sell_price
		return String(a.id) < String(b.id))
	return found


func _kind_in(bag: Inventory) -> int:
	var total := 0
	for item in kind_in_bag(bag):
		total += bag.count(item)
	return total


## "any fish", "any 3 fruit".
func _kind_words(count: int) -> String:
	var what := any_what if any_what != "" else String(any_tag)
	return "any %s" % what if count == 1 else "any %d %s" % [count, QuestGoal.plural(what, count)]


func _join(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
