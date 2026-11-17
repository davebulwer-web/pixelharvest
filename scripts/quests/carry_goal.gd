class_name CarryGoal
extends DeliverGoal
##
## CarryGoal — "take this parcel to Hollis" (DECISIONS 062): a delivery of
## something you were given to carry. Taking the request puts `item` in the
## bag (on_taken), and handing it in takes it out again, as any delivery. If
## it runs out, the parcel goes back to whoever gave it (on_expired), so a
## late parcel doesn't sit in the bag for ever.
##
## Who it's handed to is the request's business (QuestDef.hand_in_to), not
## the goal's: a goal never knows who it's for.
##


func describe() -> String:
	var word := item.display_name.to_lower() if item != null else "parcel"
	return "Deliver the %s" % word


func on_taken(bag: Inventory) -> void:
	if item != null and bag != null:
		bag.add(item, amount)


func on_expired(bag: Inventory) -> void:
	if item != null and bag != null:
		bag.remove(item, mini(amount, bag.count(item)))
