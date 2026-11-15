class_name SellGoal
extends QuestGoal
##
## SellGoal — "sell 200g worth of produce", however it's sold: into the
## shipping bin (counted when it goes in, EventBus.items_shipped) or across a
## counter, indoors or at a market stall (items_sold_to_shop). `amount` is gold.
##


func describe() -> String:
	return "Sell %dg worth of produce (the shipping bin, a shop or the market)" % amount


func counts(event: StringName, args: Array) -> int:
	match event:
		&"items_shipped":  # (count, value)
			return args[1]
		&"items_sold_to_shop":  # (item_id, amount, gold)
			return args[2]
	return 0


func progress_text(done: int) -> String:
	return "%dg / %dg" % [mini(done, amount), amount]
