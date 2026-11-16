class_name CatchGoal
extends QuestGoal
##
## CatchGoal — "catch 3 fish" (DECISIONS 054). Counts every fish landed
## after the request was taken (EventBus fish_caught), optionally only one
## kind (`fish`), only from one kind of water (`water`: Wren's river fish
## will want &"stream"), or only one at least `min_size` cm long (Pip's
## biggest fish). The fish stays the player's: nothing is handed in.
##

## Only this kind counts. Null: any fish.
@export var fish: FishDef

## Only fish from this kind of water count (&"pond", &"river", &"stream").
## &"": any water.
@export var water: StringName = &""

## Only fish at least this long count, in cm. 0: any size.
@export var min_size: int = 0


func describe() -> String:
	var what := plural(fish.display_name, amount) if fish != null else "fish"
	var text := "Catch %d %s" % [amount, what]
	if min_size > 0:
		text += " of %d cm or more" % min_size
	if water != &"":
		text += " in the %s" % water
	return text


func counts(event: StringName, args: Array) -> int:
	# fish_caught(fish_id, size, location_id, water)
	if event != &"fish_caught":
		return 0
	if fish != null and args[0] != fish.id:
		return 0
	if min_size > 0 and int(args[1]) < min_size:
		return 0
	if water != &"" and args[3] != water:
		return 0
	return 1
