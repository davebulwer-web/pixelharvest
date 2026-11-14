class_name UpgradeEffect
extends Resource
##
## UpgradeEffect — what owning an upgrade does. The base class does nothing;
## each kind of upgrade is a small script in scripts/upgrades/ that overrides
## just the method it cares about.
##
## Two kinds of effect, deliberately kept apart:
##
##   - Lasting bonuses (tool tier, maximum energy) are *asked for* whenever
##     they're needed: GameState adds up what every owned upgrade says. Nothing
##     about them is stored except "this upgrade is owned", so changing the
##     numbers in a .tres file changes existing games too.
##   - One-off changes to the world (clearing a field) happen once, in
##     on_bought(). They change FarmData, and the farm is saved, so they're
##     never repeated.
##
## A new *kind* of upgrade (say, a bigger bag) adds a method here and a script
## in scripts/upgrades/. A new upgrade of an existing kind is only data.
##


## The tier this upgrade gives the tool with `tool_id`, or 0 if it's not
## about that tool.
func tool_tier(_tool_id: StringName) -> int:
	return 0


## Energy added to the daily maximum.
func max_energy_bonus() -> float:
	return 0.0


## Ground that stays locked (thicket) until this upgrade is bought. The
## starting farm is built with it overgrown. An empty Rect2i means none.
func locked_area() -> Rect2i:
	return Rect2i()


## False if buying this now would do nothing (a field already cleared, for
## example). The shop doesn't offer upgrades that would do nothing.
func is_useful() -> bool:
	return true


## Make any one-off change to the world. Called once, when bought.
func on_bought(_upgrade: UpgradeDef) -> void:
	pass
