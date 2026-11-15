class_name DeliverAnyGoal
extends QuestGoal
##
## DeliverAnyGoal — "bring me 6 strawberries or blueberries" (DECISIONS 049).
## Done when the bag holds `amount` of the `items` between them, in any mix;
## handing in takes them, first from the item listed first.
##
## Like DeliverGoal it listens to nothing: it looks in the bag, so produce
## grown before the request was made counts too.
##

## The items that will do. Any mix of them counts.
@export var items: Array[ItemDef] = []

## What to call them all, when the list is too long to read out: "vegetables"
## gives "Bring 8 vegetables, any mix" (Rosa's first crate, DECISIONS 050).
## Empty: the items are named.
@export var what: String = ""


func describe() -> String:
	if what != "":
		return "Bring %d %s (any mix)" % [amount, what]
	var names: Array[String] = []
	for item in items:
		names.append(plural(item.display_name if item != null else "?", amount))
	var either := " or ".join(names) if names.size() <= 2 \
			else ", ".join(names.slice(0, names.size() - 1)) + " or " + names[-1]
	return "Bring %d %s" % [amount, either]


func progress(_recorded: int, bag: Inventory, _gold: int) -> int:
	if bag == null:
		return 0
	var total := 0
	for item in items:
		if item != null:
			total += bag.count(item)
	return total


func is_handed_over() -> bool:
	return true


func hand_in(bag: Inventory) -> void:
	var left := amount
	for item in items:
		if item == null or left <= 0:
			continue
		var take := mini(left, bag.count(item))
		if take > 0:
			bag.remove(item, take)
			left -= take
