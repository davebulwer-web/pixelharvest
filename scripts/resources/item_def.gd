class_name ItemDef
extends Resource
##
## ItemDef — anything that can sit in the player's bag: produce, seeds, tools.
##
## Every item has a name, an icon and two prices. That's all the inventory,
## the shipping bin and the shop ever need to know, so they work on ItemDef and
## never ask which kind of item it is (DECISIONS 023).
##
## Tools and seeds are ToolDefs, which extend this with what happens when you
## use them. Produce (what a harvest gives you) is a plain ItemDef, in
## data/produce/.
##

@export var id: StringName
@export var display_name: String

## One line for the shop, saying what it's for. Optional: seeds describe
## themselves from their crop (grow time, sell price) when this is empty.
@export_multiline var description: String = ""

## 16×16, shown in the hotbar and the shop.
@export var icon: Texture2D

## Gold the shipping bin pays for one. 0 means the bin won't take it, which is
## how tools and seeds stay out of the bin without a special case.
@export var sell_price: int = 0

## Gold the shop charges for one. 0 means the shop doesn't sell it.
@export var buy_price: int = 0

## Shop ids (ShopDef.id) that are the only places selling this, such as a
## market stall's rare seeds (DECISIONS 037). Empty, the usual rule applies:
## any shop whose switches cover it (seeds at the seed shop, and so on).
@export var sold_only_by: Array[StringName] = []

## Hidden from every shop until this is earned (DECISIONS 043): Hollis's
## potato seeds wait for the mayor's first request. Null: on sale from the
## start. Only the shops look at it; an item given as a reward is still given.
@export var requires_unlock: UnlockDef

## Words that say what kind of thing this is, for rules that care about a
## kind rather than one item (DECISIONS 047): &"flower" for the sunflower,
## which bees (Stage 17), the flower show (Stage 18) and the pests (they
## spread slower near flowers) look for. Empty for most items.
@export var tags: Array[StringName] = []


## True if this item has the tag `tag` (&"flower").
func has_tag(tag: StringName) -> bool:
	return tag in tags
