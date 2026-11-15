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

## Everything else with a shop price that does a job: sprinklers, for now.
@export var sells_supplies: bool = false

## Decorations for the farm (any item whose action is a PlaceDecorationAction):
## a scarecrow, a lamp post. They do nothing but look nice (DECISIONS 039).
@export var sells_decorations: bool = false

## Which kinds of upgrade are sold here: &"tools", &"energy", &"land".
## Each UpgradeEffect names its own kind (UpgradeEffect.category).
@export var upgrade_categories: Array[StringName] = []

## True if the shop buys produce straight from your bag, for gold now, at
## `produce_pay_rate` of its usual price. The shipping bin pays in full but
## only overnight, which is what keeps it worth using. A market stall can pay
## more than the bin (above 1.0): that's what market day is for (DECISIONS 037).
@export var buys_produce: bool = false
@export_range(0.0, 2.0, 0.05) var produce_pay_rate: float = 0.8

## --- Opening hours (DECISIONS 035) --------------------------------------------
## Minutes after midnight, like game_rules.tres: 9 AM is 540, 5 PM is 1020.
## The door is locked outside these hours; if the shop closes while you're
## inside, you can stay and walk out, but the keeper won't serve you.
## Leave both at 0 for a shop that never closes.
@export var opens_at: int = 0
@export var closes_at: int = 0


## True if the shop keeps hours at all.
func keeps_hours() -> bool:
	return closes_at > opens_at


## True if the shop is open at `minutes` (the time of day). Open from the
## opening time up to, but not including, the closing time.
func is_open_at(minutes: int) -> bool:
	if not keeps_hours():
		return true
	return minutes >= opens_at and minutes < closes_at


## "9 AM – 5 PM", or "always open".
func hours_text() -> String:
	if not keeps_hours():
		return "always open"
	return "%s – %s" % [Clock.format_short(opens_at), Clock.format_short(closes_at)]
