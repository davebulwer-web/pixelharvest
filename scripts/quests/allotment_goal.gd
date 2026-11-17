class_name AllotmentGoal
extends QuestGoal
##
## AllotmentGoal — an odd job on one of the allotment beds on the Lane
## (DECISIONS 062): pull `amount` weeds, or water or dig over `amount` tiles,
## on bed number `plot`.
##
## It counts EventBus.allotment_worked, which the Allotments service
## announces for each tile of work done with a tool or by hand. It's done the
## moment the last tile is (finishes_itself): the job was pinned on the shed,
## and the pay was left with it, so there's nobody to go back to.
##

## &"weed", &"water" or &"dig".
@export var work: StringName = &"weed"

## Which bed: 1 to 8, numbered along the top row and then the bottom, left to
## right (LaneLayout.ALLOTMENT_BEDS).
@export var plot: int = 1


func describe() -> String:
	match work:
		&"weed":
			return "Pull the %d %s in plot %d" % [amount, "weed" if amount == 1 else "weeds", plot]
		&"water":
			return "Water plot %d" % plot
		&"dig":
			return "Dig over plot %d" % plot
	return "Work on plot %d" % plot


func counts(event: StringName, args: Array) -> int:
	if event != &"allotment_worked" or args.size() < 2:
		return 0
	return 1 if int(args[0]) == plot and StringName(args[1]) == work else 0


func finishes_itself() -> bool:
	return true
