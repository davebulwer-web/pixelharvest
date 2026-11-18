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
## Where to sell (DECISIONS 063): every buyer pays its own rate (the bin
## 100% overnight, Marlow 80% now, Rosa 125% on market day, Mabel 110% for
## fruit), and every buyer drops its price on one thing once it has had
## plenty of it that day (DemandDef). The bin's count is simply what's in it;
## each counter's is kept here, by buyer and item, and forgotten overnight. It
## isn't saved: the game saves in the morning, when every count is nothing.
##

## What each shop has bought today: shop id -> {item id -> count}.
var _bought_today: Dictionary = {}


func _ready() -> void:
	# day_ended is step 1 of the overnight sequence (time_system.gd), so the
	# bin is settled before the farm grows or the game saves.
	EventBus.day_ended.connect(_on_day_ended)
	# Every morning every buyer pays full price again; so does a new game
	# started part way through a day (Ctrl+N), or a save loaded.
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _bought_today.clear())
	EventBus.new_game_started.connect(func() -> void: _bought_today.clear())
	EventBus.game_loaded.connect(func() -> void: _bought_today.clear())


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
		if upgrade.gift_only:
			continue  # given by a request, never sold (DECISIONS 055)
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


## True if `shop` buys `item` across the counter at all: it buys produce,
## this is a kind it takes (ShopDef.buys_tags), and it has a sell price.
func shop_buys(item: ItemDef, shop: ShopDef) -> bool:
	if shop == null or not shop.takes(item) or sell_price(item) <= 0:
		return false
	# A chalkboard (DECISIONS 068): only today's wanted things, and only
	# until Nell has had her fill of each.
	return not shop.chalkboard or Tavern.takes_today(item, shop)


## How many of `item` from the bag `shop` would buy now: all of them, or,
## at a chalkboard, no more than it still wants today (DECISIONS 068).
func sellable_amount(item: ItemDef, shop: ShopDef) -> int:
	var amount := GameState.inventory.count(item)
	if shop != null and shop.chalkboard:
		amount = mini(amount, Tavern.left_today(item, shop))
	return amount


## What `shop` pays for one of `item` at its full rate: the usual price times
## the shop's rate, never less than 1 for something sellable.
func full_store_price(item: ItemDef, shop: ShopDef) -> int:
	if sell_price(item) <= 0:
		return 0
	return maxi(1, roundi(sell_price(item) * shop.produce_pay_rate))


## What `shop` pays for the next one of `item` across the counter today: its
## full rate, or less once it has had plenty of them today (DemandDef).
func store_price(item: ItemDef, shop: ShopDef) -> int:
	return DemandDef.total_for(shop.demand, full_store_price(item, shop), bought_today(item, shop), 1)


## What `shop` would pay for `amount` of `item` together, now.
func store_total(item: ItemDef, shop: ShopDef, amount: int) -> int:
	return DemandDef.total_for(shop.demand, full_store_price(item, shop), bought_today(item, shop), amount)


## How many of `item` `shop` has bought today.
func bought_today(item: ItemDef, shop: ShopDef) -> int:
	var counts: Dictionary = _bought_today.get(shop.id, {})
	return int(counts.get(item.id, 0))


## True if `shop` has had so many of `item` today that it pays less for more.
func shop_flooded(item: ItemDef, shop: ShopDef) -> bool:
	return DemandDef.is_flooded(shop.demand, bought_today(item, shop))


## Sell everything the player carries of `item` to `shop` (or as many as a
## chalkboard still wants), for gold now.
## Returns the gold paid, 0 if the shop doesn't buy it or there was none.
func sell_to_shop(item: ItemDef, shop: ShopDef) -> int:
	var amount := sellable_amount(item, shop)
	if amount <= 0 or not shop_buys(item, shop):
		return 0
	var gold := store_total(item, shop, amount)
	GameState.inventory.remove(item, amount)
	var counts: Dictionary = _bought_today.get(shop.id, {})
	counts[item.id] = int(counts.get(item.id, 0)) + amount
	_bought_today[shop.id] = counts
	GameState.add_gold(gold)
	EventBus.items_sold_to_shop.emit(item.id, amount, gold)
	return gold


## Move everything sellable from the bag into the shipping bin. Returns how
## many items went in.
func ship_all() -> int:
	var shipped := 0
	# What this lot adds to tonight's pay, after the bin's drop for plenty.
	var before := bin_value()
	for item in GameState.inventory.items():
		if sell_price(item) <= 0:
			continue
		var amount := GameState.inventory.count(item)
		GameState.inventory.remove(item, amount)
		GameState.shipping_bin.add(item, amount)
		shipped += amount
	EventBus.items_shipped.emit(shipped, bin_value() - before)
	return shipped


## What the bin will pay tonight, at today's prices: full price for the
## first so many of each thing, less for the rest (GameRules.bin_demand).
func bin_value() -> int:
	var value := 0
	for item in GameState.shipping_bin.items():
		value += bin_pays(item, GameState.shipping_bin.count(item))
	return value


## What the bin pays tonight for `count` of `item` in it.
func bin_pays(item: ItemDef, count: int) -> int:
	return DemandDef.total_for(GameState.RULES.bin_demand, sell_price(item), 0, count)


## True if the bin already holds so many of `item` that more pays less.
func bin_flooded(item: ItemDef) -> bool:
	return DemandDef.is_flooded(GameState.RULES.bin_demand, GameState.shipping_bin.count(item))


func _on_day_ended(_day: int) -> void:
	var earned := bin_value()
	GameState.shipping_bin.clear()
	if earned > 0:
		GameState.add_gold(earned)
		EventBus.shipment_sold.emit(earned)
