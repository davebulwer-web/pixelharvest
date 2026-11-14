extends Node
##
## Economy — buying and selling: the shop and the shipping bin.
##
## GameState holds the gold and the items; this file holds the rules for
## turning one into the other. Every price in the game is read through
## buy_price() and sell_price() below, never straight off an item, so that
## Stage 8's market days and difficulty settings have exactly one place to
## adjust prices.
##
## The shipping bin works like this (DESIGN.md, the core loop):
##   - During the day, interacting with the bin moves every sellable item from
##     the bag into it (anything with a sell price — tools and seeds have none).
##   - When the day ends, before anything else happens overnight, the bin is
##     sold and emptied. The gold is there when the player wakes.
##
## Nothing comes back out of the bin. If that turns out to be annoying in play,
## "take back" is a small addition here.
##


func _ready() -> void:
	# day_ended is step 1 of the overnight sequence (time_system.gd), so the
	# bin is settled before the farm grows or the game saves.
	EventBus.day_ended.connect(_on_day_ended)


func buy_price(item: ItemDef) -> int:
	return item.buy_price


func sell_price(item: ItemDef) -> int:
	return item.sell_price


## Buy `amount` of `item` from the shop. Returns false, changing nothing, if
## the shop doesn't sell it or the player can't afford it.
func buy(item: ItemDef, amount: int = 1) -> bool:
	var cost := buy_price(item) * amount
	if buy_price(item) <= 0 or not GameState.try_spend_gold(cost):
		return false
	GameState.inventory.add(item, amount)
	EventBus.item_bought.emit(item.id, amount, cost)
	return true


## Move everything sellable from the bag into the shipping bin. Returns how
## many items went in.
func ship_all() -> int:
	var shipped := 0
	var value := 0
	for item in GameState.inventory.items():
		if sell_price(item) <= 0:
			continue
		var amount := GameState.inventory.count(item)
		GameState.inventory.remove(item, amount)
		GameState.shipping_bin.add(item, amount)
		shipped += amount
		value += sell_price(item) * amount
	EventBus.items_shipped.emit(shipped, value)
	return shipped


## What the bin will pay tonight, at today's prices.
func bin_value() -> int:
	var value := 0
	for item in GameState.shipping_bin.items():
		value += sell_price(item) * GameState.shipping_bin.count(item)
	return value


func _on_day_ended(_day: int) -> void:
	var earned := bin_value()
	GameState.shipping_bin.clear()
	if earned > 0:
		GameState.add_gold(earned)
		EventBus.shipment_sold.emit(earned)
