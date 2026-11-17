class_name SetPotAction
extends ToolAction
##
## Crab pot (DECISIONS 065) — lowered into the sea off the Cove's pier.
##
## A pot in the bag is used like a seed (consumed_on_use): Space, facing the
## water beside the pier, and it goes in. Where a pot can go is the map's
## business: the place answers pot_wanted_at(cell) and set_pot(cell) (only
## the Cove has any), so this file never knows where the pier is. From then
## on the pot is GameState's (baited, hauled, saved), and E on it does the
## rest.
##
## Must not use the GameState autoload (tools can be listed in the starting
## kit, which game_rules.tres preloads).
##


## There's no sea on the farm.
func can_use(_farm: FarmData, _cell: Vector2i) -> bool:
	return false


func can_use_away(place: Node, cell: Vector2i) -> bool:
	return place != null and place.has_method(&"pot_wanted_at") and place.pot_wanted_at(cell)


func apply_away(place: Node, cell: Vector2i) -> void:
	if place != null and place.has_method(&"set_pot"):
		place.set_pot(cell)
