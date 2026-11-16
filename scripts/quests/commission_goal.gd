class_name CommissionGoal
extends DeliverGoal
##
## CommissionGoal — "bring me 20 timber and 200g for the work" (DECISIONS
## 053): a delivery with a fee. Brann's sprinkler line asks for materials and
## gold together, because he's making something for you.
##
## The items work as in DeliverGoal: whatever's in the bag counts, and
## handing in takes them. The fee works as in DonateGoal: it must be in the
## purse when you hand in, and the Quests service takes it (gold_to_hand_in),
## since a goal touches no autoload. The request is ready only when both are
## there, so progress counts the items, and the reminder says if it's the
## gold that's short.
##

## Gold handed over with the items.
@export var fee: int = 0


func describe() -> String:
	var items := "Bring %d %s" % [amount, plural(item.display_name if item != null else "?", amount)]
	return items + (" and %dg" % fee if fee > 0 else "")


func progress_text(done: int) -> String:
	var name := plural(item.display_name if item != null else "?", amount)
	var text := "%d / %d %s" % [mini(done, amount), amount, name]
	return text + (", and %dg" % fee if fee > 0 else "")


func gold_to_hand_in() -> int:
	return fee
