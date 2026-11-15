class_name DifficultyDef
extends Resource
##
## DifficultyDef — one way of playing the game, chosen once at new game
## (DECISIONS 040).
##
## Difficulty is data, not code (DESIGN.md): every setting here is a
## multiplier on a number that already lives somewhere else. 1.0 changes
## nothing, so "Standard" is all ones and plays exactly as the game did before
## difficulty existed. Nothing in the game asks "is this Hard?"; it only ever
## asks for the multiplier, so a fourth difficulty is one more .tres file in
## data/difficulties/ and a line in game_rules.tres.
##
## Where each one is applied (one place each):
##   starting gold — GameState.new_game()
##   sell prices   — Economy.sell_price() (the bin, shop counters, market stall)
##   shop prices   — Economy.buy_price() and Economy.upgrade_price()
##   energy        — the player's tool swing (player.gd)
##   grow times    — CropDef.days_to_grow_from(), via FarmData.advance_day()
##
## Must not use the GameState autoload: game_rules.tres preloads these files,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

## Saved in the save file, so don't change it once games use it.
## display_name is free to change.
@export var id: StringName
@export var display_name: String

## A sentence or two for the new-game menu, in the game's voice.
@export_multiline var description: String

## Times game_rules.tres starting_gold.
@export var starting_gold_multiplier: float = 1.0

## Times every produce price: the shipping bin, the general store's counter
## and the market stall (which pays its own rate on top of this).
@export var sell_price_multiplier: float = 1.0

## Times every price in the shops: seeds, supplies, decorations and upgrades.
@export var buy_price_multiplier: float = 1.0

## Times the energy each swing of a tool costs.
@export var energy_cost_multiplier: float = 1.0

## Times the watered days a crop needs to grow (and to regrow). Rounded to
## whole days, never below one day a stage — see CropDef.days_to_grow_from().
@export var grow_time_multiplier: float = 1.0


## `price` times `multiplier`, rounded to whole gold. Something with a price
## never becomes free: it costs at least 1g. 0 stays 0 ("not for sale").
static func scale_price(price: int, multiplier: float) -> int:
	if price <= 0:
		return 0
	return maxi(1, roundi(price * multiplier))


## The gold a new game starts with, from game_rules.tres's amount.
func starting_gold(base: int) -> int:
	return maxi(0, roundi(base * starting_gold_multiplier))


## What this difficulty changes, in plain words, for the new-game menu. Lines
## for settings left at 1.0 are skipped, so Standard says nothing extra.
func summary(base_gold: int) -> Array[String]:
	var lines: Array[String] = ["Start with %dg" % starting_gold(base_gold)]
	_describe(lines, sell_price_multiplier, "Produce sells for %d%% of the usual price")
	_describe(lines, buy_price_multiplier, "Shop prices are %d%% of the usual")
	_describe(lines, energy_cost_multiplier, "Tools use %d%% of the usual energy")
	_describe(lines, grow_time_multiplier, "Crops take %d%% of the usual time to grow")
	return lines


func _describe(lines: Array[String], multiplier: float, text: String) -> void:
	if not is_equal_approx(multiplier, 1.0):
		lines.append(text % roundi(multiplier * 100.0))
