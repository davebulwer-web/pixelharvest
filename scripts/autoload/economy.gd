extends Node
##
## Economy — buying and selling: the shops, upgrades and the shipping bin.
##
## GameState holds the gold and the items; this file holds the rules for
## turning one into the other. Every price in the game is read through
## buy_price() and sell_price() below, never straight off an item, so that
## market days and the difficulty have exactly one place to adjust prices.
## The difficulty (DECISIONS 040) scales them here; a market stall's own rate
## goes on top, in store_price().
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
	return DifficultyDef.scale_price(item.buy_price, GameState.difficulty.buy_price_multiplier)


func sell_price(item: ItemDef) -> int:
	return DifficultyDef.scale_price(item.sell_price, GameState.difficulty.sell_price_multiplier)


func upgrade_price(upgrade: UpgradeDef) -> int:
	return DifficultyDef.scale_price(upgrade.price, GameState.difficulty.buy_price_multiplier)


## What `shop` has on its shelves: seed packets and supplies, per its switches
## (ShopDef), cheapest first. Decided from ContentDB's whole stock, so new
## crops and tools appear in the right shop with no file here edited. Things
## waiting for an unlock stay off the shelves until it's earned (DECISIONS 043).
func shop_stock(shop: ShopDef) -> Array[ItemDef]:
	var stock: Array[ItemDef] = []
	for item in ContentDB.shop_stock():
		if not GameState.has_unlock(item.requires_unlock):
			continue
		# Some things are sold only by particular shops (a market stall's
		# rare seeds); they skip the switches below entirely.
		if not item.sold_only_by.is_empty():
			if shop.id in item.sold_only_by:
				stock.append(item)
			continue
		if is_seed(item):
			if shop.sells_seeds:
				stock.append(item)
		elif is_decoration(item):
			if shop.sells_decorations:
				stock.append(item)
		elif shop.sells_supplies:
			stock.append(item)
	return stock


## True for a packet of seeds: anything whose action plants a crop.
func is_seed(item: ItemDef) -> bool:
	return item is ToolDef and item.action is PlantAction


## True for something put on the farm just for the look of it (DECISIONS 039).
func is_decoration(item: ItemDef) -> bool:
	return item is ToolDef and item.action is PlaceDecorationAction


## The upgrades on offer right now, cheapest first: not yet owned, whatever
## they require already owned, any unlock they wait for earned, and they'd
## actually do something. So the great
## hoe appears only once the wide hoe is bought, and each upgrade line shows
## one step at a time. With a `shop`, only the kinds that shop sells; with
## none (tests, tools), every kind.
func upgrades_on_offer(shop: ShopDef = null) -> Array[UpgradeDef]:
	var offer: Array[UpgradeDef] = []
	for upgrade in ContentDB.upgrades():
		if GameState.has_upgrade(upgrade):
			continue
		if upgrade.requires != null and not GameState.has_upgrade(upgrade.requires):
			continue
		if not GameState.has_unlock(upgrade.requires_unlock):
			continue
		if upgrade.effect == null or not upgrade.effect.is_useful():
			continue
		if shop != null and upgrade.effect.category() not in shop.upgrade_categories:
			continue
		offer.append(upgrade)
	return offer


## Buy an upgrade. Returns false, changing nothing, if it isn't on offer or
## the player can't afford it. (Which shop sells it is the menu's business:
## it only ever lists what its own shop offers.)
func buy_upgrade(upgrade: UpgradeDef) -> bool:
	if not upgrade in upgrades_on_offer():
		return false
	var cost := upgrade_price(upgrade)
	if not GameState.try_spend_gold(cost):
		return false
	GameState.add_upgrade(upgrade)
	EventBus.upgrade_bought.emit(upgrade.id, cost)
	return true


## Buy `amount` of `item` from the shop. Returns false, changing nothing, if
## the shop doesn't sell it or the player can't afford it.
func buy(item: ItemDef, amount: int = 1) -> bool:
	var cost := buy_price(item) * amount
	if buy_price(item) <= 0 or not GameState.try_spend_gold(cost):
		return false
	GameState.inventory.add(item, amount)
	EventBus.item_bought.emit(item.id, amount, cost)
	return true


## What `shop` pays for one of `item` across the counter: the usual price
## times the shop's rate, never less than 1 for something sellable.
func store_price(item: ItemDef, shop: ShopDef) -> int:
	if sell_price(item) <= 0:
		return 0
	return maxi(1, roundi(sell_price(item) * shop.produce_pay_rate))


## Sell everything the player carries of `item` to `shop`, for gold now.
## Returns the gold paid, 0 if the shop doesn't buy or there was none.
func sell_to_shop(item: ItemDef, shop: ShopDef) -> int:
	var amount := GameState.inventory.count(item)
	if not shop.buys_produce or amount <= 0 or sell_price(item) <= 0:
		return 0
	var gold := store_price(item, shop) * amount
	GameState.inventory.remove(item, amount)
	GameState.add_gold(gold)
	EventBus.items_sold_to_shop.emit(item.id, amount, gold)
	return gold


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
