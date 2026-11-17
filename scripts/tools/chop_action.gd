class_name ChopAction
extends ToolAction
##
## Axe (DECISIONS 053) — chops thicket for timber, one tile a swing.
##
## On the farm it chops the thicket that covers the fields you haven't
## bought: the tile becomes grass you can farm, and you get timber. In the
## Woods it chops the undergrowth at the glades' edges (it grows back when
## the season turns) and the day's fallen logs, which give more.
##
## How much timber each gives is set here, in the axe's .tres, so it can be
## changed in the inspector (rule 6). What timber *is* is `timber`, an
## ItemDef, also in the .tres. Putting it in the bag is GameState's job, on
## EventBus wood_chopped: the farm and the Woods announce what was chopped.
##

## The item chopping gives: timber.
@export var timber: ItemDef

## Timber from one tile of thicket or undergrowth.
@export var timber_from_thicket: int = 1

## Timber from one fallen log in the Woods.
@export var timber_from_log: int = 3


func can_use(farm: FarmData, cell: Vector2i) -> bool:
	return clears_at(farm, cell) or (timber != null and farm.can_chop(cell))


## A stump on the farm's new ground (DECISIONS 060) comes out whole; what it
## gives is the stump's own (ObjectDef.clears_to), not the thicket's timber.
func apply(farm: FarmData, cell: Vector2i) -> void:
	if clears_at(farm, cell):
		farm.clear_debris(cell)
		return
	farm.chop(cell, timber.id, timber_from_thicket)


## Away from the farm the place says what's at the cell: &"thicket", &"log",
## or &"" for nothing the axe can cut. Only the Woods answer so far.
func can_use_away(place: Node, cell: Vector2i) -> bool:
	return timber != null and place != null and place.has_method(&"choppable_at") \
			and place.choppable_at(cell) != &""


func apply_away(place: Node, cell: Vector2i) -> void:
	var what: StringName = place.choppable_at(cell)
	var amount := timber_from_log if what == &"log" else timber_from_thicket
	place.chop(cell, timber.id, amount)
