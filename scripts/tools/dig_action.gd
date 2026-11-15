class_name DigAction
extends ToolAction
##
## Trowel (DECISIONS 048) — digs up the crop in front of you, ripe or not,
## and leaves the soil empty. For a crop you don't want any more: one the
## aphids have got, a perennial in the wrong place, a tree. A giant can't be
## dug: it's picked with E.
##
## A tool of its own rather than something the hoe does on a crop, because
## the hoe's upgrades swing at three or nine tiles at once: hoeing beside a
## row of crops must never dig them up by accident.
##
## A crop dug up before it came up gives its seed back (GameState listens for
## crop_dug_up), so a seed planted in the wrong place costs nothing.
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.can_dig(cell)


func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.dig_up(cell)
