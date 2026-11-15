class_name DonateGoal
extends QuestGoal
##
## DonateGoal — "put 500g towards the new bridge" (DECISIONS 049). `amount`
## is gold. It's ready when the player carries that much, and handing the
## request in takes it (the Quests service does the taking, through
## gold_to_hand_in, because a goal touches no autoload).
##
## Gold, not produce: it's for the requests that ask the farm to pay for
## something the whole town gets (the bridge to the Woods), so the reward is
## what it opens rather than gold back.
##

## What the gold is for, to finish the sentence "Give 500g towards …":
## "the new bridge".
@export var cause: String = ""


func describe() -> String:
	if cause == "":
		return "Give %dg" % amount
	return "Give %dg towards %s" % [amount, cause]


func progress(_recorded: int, _bag: Inventory, gold: int) -> int:
	return gold


func progress_text(done: int) -> String:
	return "%dg / %dg" % [mini(done, amount), amount]


func is_handed_over() -> bool:
	return true


func gold_to_hand_in() -> int:
	return amount
