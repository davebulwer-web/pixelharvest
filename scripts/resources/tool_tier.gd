class_name ToolTier
extends Resource
##
## ToolTier — one improved version of a tool: what it's called, how much
## ground one swing covers, and what that swing costs (DECISIONS 024).
##
## A ToolDef lists its tiers in order. Tier 0 is the tool as it comes (its own
## name and energy_cost, one tile); tier 1 is the first entry in the list, and
## so on. The player owns a tier by buying the upgrade that grants it.
##
## The area is a rectangle that starts at the tile in front of the player and
## runs away from them: `length` tiles forward, `width` tiles across, centred.
##   1 × 1  the tile in front           (tier 0, implicit)
##   3 × 1  three tiles in a line       (length 3, width 1)
##   3 × 3  a square of nine            (length 3, width 3)
##

## Shown on the hotbar and in the shop, e.g. "Wide hoe".
@export var display_name: String

## Energy for one swing, however many of the tiles it covers it actually
## changes. Making a wide swing cheaper *per tile* is the whole point of an
## upgrade: 9 tiles for 9 energy beats 9 tiles for 18.
@export var energy_cost: float = 1.0

@export_range(1, 9) var length: int = 1
@export_range(1, 9) var width: int = 1
