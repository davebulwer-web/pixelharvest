class_name DeliverEachGoal
extends QuestGoal
##
## DeliverEachGoal — "grow me one of every spring crop and bring them in"
## (DECISIONS 049): one of each of `items`. Done when the bag holds at least
## one of every one; handing in takes one of each.
##
## `amount` isn't used: how many are needed is the length of the list, so
## adding a crop to the list is the only edit. Like DeliverGoal it looks in
## the bag rather than listening, so it counts what was grown before the
## request was made, and the reminder says which are still missing. It can
## also want one more thing from a second list, any of them (`and_one_of`).
##

## One of each of these is wanted.
@export var items: Array[ItemDef] = []

## And one more thing, any one of these (DECISIONS 055): Ivy's planting
## wants the autumn crops and a fish, whichever fish. Handing in takes the
## first one in the list the bag has, so list the cheapest first. Empty:
## nothing more.
@export var and_one_of: Array[ItemDef] = []

## What to call that one more thing: "a fish".
@export var and_one_of_what: String = ""


func needed() -> int:
	return items.size() + (1 if not and_one_of.is_empty() else 0)


func describe() -> String:
	if and_one_of.is_empty():
		return "Bring one each of %s" % list_names(items)
	return "Bring one each of %s, and %s" % [list_names(items), _extra_name()]


func progress(_recorded: int, bag: Inventory, _gold: int) -> int:
	if bag == null:
		return 0
	var have := items.filter(func(item: ItemDef) -> bool: return item != null and bag.count(item) > 0).size()
	if _extra_in(bag) != null:
		have += 1
	return have


func still_needed(bag: Inventory) -> String:
	var missing: Array[String] = []
	for item in items:
		if item == null or bag == null or bag.count(item) == 0:
			missing.append(item.display_name.to_lower() if item != null else "?")
	if not and_one_of.is_empty() and (bag == null or _extra_in(bag) == null):
		missing.append(_extra_name())
	if missing.size() <= 1:
		return "".join(missing)
	return ", ".join(missing.slice(0, missing.size() - 1)) + " and " + missing[-1]


func is_handed_over() -> bool:
	return true


func hand_in(bag: Inventory) -> void:
	for item in items:
		if item != null:
			bag.remove(item, 1)
	var extra := _extra_in(bag)
	if extra != null:
		bag.remove(extra, 1)


## The first of `and_one_of` the bag holds, or null.
func _extra_in(bag: Inventory) -> ItemDef:
	for item in and_one_of:
		if item != null and bag.count(item) > 0:
			return item
	return null


func _extra_name() -> String:
	if and_one_of_what != "":
		return and_one_of_what
	var names: Array[String] = []
	for item in and_one_of:
		names.append(item.display_name.to_lower() if item != null else "?")
	return "a " + " or ".join(names)
