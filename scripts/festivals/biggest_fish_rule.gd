class_name BiggestFishRule
extends ContestRule
##
## BiggestFishRule — the fishing contest (DECISIONS 059): sign up with the
## host, then the biggest fish you land in `location`'s `water` before the
## judging is your entry. Nothing is handed over; the fish stays yours.
## Counted from EventBus fish_caught, as CatchGoal counts it.
##

## Only fish caught here count (&"town"). &"": anywhere.
@export var location: StringName = &""

## Only fish from this water count (&"pond"). &"": any.
@export var water: StringName = &""

## The rod: without it, the host tells you where to get one.
@export var rod: ToolDef


func score_event(event: StringName, args: Array) -> int:
	# fish_caught(fish_id, size, location_id, water, through_ice)
	if event != &"fish_caught":
		return 0
	if location != &"" and args[2] != location:
		return 0
	if water != &"" and args[3] != water:
		return 0
	return int(args[1])


func score_text(score: int) -> String:
	return "%d cm" % score


func needs_tool() -> ToolDef:
	return rod
