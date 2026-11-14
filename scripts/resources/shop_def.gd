class_name ShopDef
extends Resource
##
## ShopDef — one shop's counter: who runs it, what they say, and what the
## menu behind it offers (DECISIONS 027).
##
## A shop is a LocationDef (the room you walk into, and the door on the town
## map) that points at one of these. The room itself is the shared interior
## scene; only the keeper, the words and the stock differ, so a new shop is
## data: a ShopDef, a LocationDef, a shopkeeper picture and a building picture.
##
## What a shop SELLS is decided by these switches against the whole of
## ContentDB, never by listing items. A new crop's seeds turn up at the seed
## shop with no file here edited (rule 3).
##
## Nothing in this file may touch an autoload: game_rules.tres loads it (via
## the location list) before the autoloads exist (DECISIONS 021). That's why
## the filtering itself lives in Economy.
##

@export var id: StringName
@export var display_name: String

## Who stands behind the counter, and what they look like (a 56×56 frame,
## standing on the same baseline as the farmer).
@export var keeper_name: String
@export var keeper_sprite: Texture2D

## What the keeper says when spoken to. One is picked each day, so the shop
## doesn't repeat itself within a day but isn't random on reloading.
@export var greetings: Array[String] = []

## Seed packets (any item whose action plants a crop).
@export var sells_seeds: bool = false

## Everything else with a shop price: sprinklers, for now.
@export var sells_supplies: bool = false

## Which kinds of upgrade are sold here: &"tools", &"energy", &"land".
## Each UpgradeEffect names its own kind (UpgradeEffect.category).
@export var upgrade_categories: Array[StringName] = []

## True if the shop buys produce straight from your bag, for gold now, at
## `produce_pay_rate` of its usual price. The shipping bin pays in full but
## only overnight, which is what keeps it worth using.
@export var buys_produce: bool = false
@export_range(0.0, 1.0, 0.05) var produce_pay_rate: float = 0.8
