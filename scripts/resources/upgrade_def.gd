class_name UpgradeDef
extends Resource
##
## UpgradeDef — something bought once that makes the farm better for good: a
## better hoe, more energy, a new field (DECISIONS 024).
##
## Upgrades aren't items: they never sit in the bag, so they don't extend
## ItemDef. The shop lists them beside the seeds, Economy sells them, and
## GameState remembers which ones the player owns. What an upgrade actually
## *does* is its `effect`, an UpgradeEffect embedded in the same .tres — the
## same shape as a tool and its ToolAction. Adding a fourth energy upgrade, a
## fourth field or a better watering can is a new .tres file, no code.
##

@export var id: StringName
@export var display_name: String

## One line for the shop, saying what it does.
@export_multiline var description: String = ""

## 16×16, shown in the shop.
@export var icon: Texture2D

## Gold, read through Economy.upgrade_price() so Stage 8 can adjust it.
@export var price: int = 0

## Must be owned before this one is offered, e.g. the wide hoe before the
## great hoe. Empty means it's on offer from the start.
@export var requires: UpgradeDef

## Not offered until this is earned (DECISIONS 043). Null: no wait.
@export var requires_unlock: UnlockDef

@export var effect: UpgradeEffect
