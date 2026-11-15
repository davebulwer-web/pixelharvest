class_name PlaceDecorationAction
extends PlaceObjectAction
##
## Puts a decoration down on the farm: a scarecrow, a lamp post, a bale of hay.
## Placing works exactly like a sprinkler (PlaceObjectAction): Space puts it on
## open grass in front of you, E picks it back up into the bag.
##
## Why a class of its own when it does nothing different: it's how the game
## tells a decoration apart from a useful object, the way seeds are told apart
## by PlantAction. Economy sends items with this action only to shops that
## sell decorations (ShopDef.sells_decorations), so a new decoration turns up
## at Marlow's and not at the blacksmith's, with no list to keep (DECISIONS 039).
## A decoration's ObjectDef has no water_offsets: it is only there to be looked at.
##
