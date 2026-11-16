class_name CatchGoal
extends QuestGoal
##
## CatchGoal — "catch 3 fish" (DECISIONS 054). Counts every fish landed
## after the request was taken (EventBus fish_caught), optionally only one
## kind (`fish`), only from one kind of water (`water`: Wren's river fish
## wants &"stream"), only in one place (`location`: the summer contest is
## the town's pond, not the farm's), only one at least `min_size` cm long
## (Pip's biggest fish), or only through the ice (`through_ice`: Wren's
## "ice and patience", DECISIONS 055). The fish stays the player's: nothing
## is handed in.
##

## Only this kind counts. Null: any fish.
@export var fish: FishDef

## Only fish from this kind of water count (&"pond", &"river", &"stream").
## &"": any water.
@export var water: StringName = &""

## Only fish caught in this location count (&"town"). &"": anywhere.
@export var location: StringName = &""

## Only fish at least this long count, in cm. 0: any size.
@export var min_size: int = 0

## Only fish brought up through a hole in winter's ice count.
@export var through_ice: bool = false

## What to call the place in the request's text ("the town pond"), when
## `location` alone would read oddly. "": the water's name.
@export var where: String = ""


func describe() -> String:
	var what := plural(fish.display_name, amount) if fish != null else "fish"
	var text := "Catch %d %s" % [amount, what]
	if min_size > 0:
		text += " of %d cm or more" % min_size
	if where != "":
		text += " in %s" % where
	elif water != &"":
		text += " in the %s" % water
	if through_ice:
		text += " through the ice"
	return text


func counts(event: StringName, args: Array) -> int:
	# fish_caught(fish_id, size, location_id, water, through_ice)
	if event != &"fish_caught":
		return 0
	if fish != null and args[0] != fish.id:
		return 0
	if min_size > 0 and int(args[1]) < min_size:
		return 0
	if location != &"" and args[2] != location:
		return 0
	if water != &"" and args[3] != water:
		return 0
	if through_ice and not (args.size() > 4 and bool(args[4])):
		return 0
	return 1
