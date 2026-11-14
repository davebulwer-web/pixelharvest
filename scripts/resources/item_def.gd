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
