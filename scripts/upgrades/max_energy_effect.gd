class_name MaxEnergyEffect
extends UpgradeEffect
##
## More energy every day. GameState adds this to the starting maximum from
## game_rules.tres whenever it works out the player's maximum.
##

@export var amount: float = 20.0


func max_energy_bonus() -> float:
	return amount
