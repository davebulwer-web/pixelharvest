class_name DeliverGoal
extends QuestGoal
##
## DeliverGoal — "bring me 5 parsnips". Done when the bag holds `amount` of
## `item`; handing the request in takes them out of the bag.
##
## It doesn't listen to anything: it looks in the bag, so produce grown before
## the request was made counts too, and selling them before handing in undoes it.
##

@export var item: ItemDef


func describe() -> String:
	return "Bring %d %s" % [amount, plural(item.display_name if item != null else "?", amount)]


func progress(_recorded: int, bag: Inventory, _gold: int) -> int:
	return bag.count(item) if item != null and bag != null else 0


func is_handed_over() -> bool:
	return true


func hand_in(bag: Inventory) -> void:
	bag.remove(item, amount)
