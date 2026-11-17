class_name SickleAction
extends ToolAction
##
## Sickle (DECISIONS 058) — cuts weeds and picks ripe crops. On its own it
## does one tile, no better than E; its worth is in its tiers (the wide and
## great sickle, from Brann), which cut a row or a square in one swing, as
## the hoe's do.
##
## Weeds are pulled as E pulls them (FarmData.pull_weeds; GameState gives the
## fibre on weeds_pulled). A ripe crop is announced as cut (crop_cut) and
## GameState picks it into the bag, rolling the dice for bunches and seeds
## exactly as E does: a tool can't use GameState itself (tool_action.gd).
## Unripe crops are left alone, so a wide swing across a mixed bed is safe.
##

func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return farm.has_weeds(cell) or clears_at(farm, cell) or farm.can_harvest(cell)


## Brambles and nettles on the farm's new ground (DECISIONS 060) are cut
## like weeds: a wide sickle clears a row of them in one swing.
func apply(farm: FarmData, cell: Vector2i) -> void:
	farm.pull_weeds(cell)
	if clears_at(farm, cell):
		farm.clear_debris(cell)
	if farm.can_harvest(cell):
		EventBus.crop_cut.emit(cell)
