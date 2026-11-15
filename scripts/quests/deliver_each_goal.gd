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
## request was made, and the reminder says which are still missing.
##

## One of each of these is wanted.
@export var items: Array[ItemDef] = []


func needed() -> int:
	return items.size()


func describe() -> String:
	return "Bring one each of %s" % list_names(items)


func progress(_recorded: int, bag: Inventory, _gold: int) -> int:
	if bag == null:
		return 0
	return items.filter(func(item: ItemDef) -> bool: return item != null and bag.count(item) > 0).size()


func still_needed(bag: Inventory) -> String:
	if bag == null:
		return list_names(items)
	var missing: Array[ItemDef] = []
	missing.assign(items.filter(func(item: ItemDef) -> bool: return item == null or bag.count(item) == 0))
	return list_names(missing)


func is_handed_over() -> bool:
	return true


func hand_in(bag: Inventory) -> void:
	for item in items:
		if item != null:
			bag.remove(item, 1)
