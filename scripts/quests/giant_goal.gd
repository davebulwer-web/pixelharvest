class_name GiantGoal
extends QuestGoal
##
## GiantGoal — "grow a giant pumpkin" (DECISIONS 049). Counts each giant of
## `crop` picked after the request was accepted (EventBus.giant_harvested).
## With no crop set, any giant counts. What's picked stays the player's.
##
## Picked, not grown: a giant that merged before the request was asked still
## counts when it's picked, and the player sees it done the moment they pick it.
##

@export var crop: CropDef


func describe() -> String:
	var crop_name := "crop"
	if crop != null:
		crop_name = (crop.produce.display_name if crop.produce != null else crop.display_name).to_lower()
	if amount == 1:
		return "Grow and pick a giant %s" % crop_name
	return "Grow and pick %d giant %s" % [amount, plural(crop_name, amount)]


func counts(event: StringName, args: Array) -> int:
	# giant_harvested(cell, crop_id)
	if event != &"giant_harvested":
		return 0
	if crop != null and args[1] != crop.id:
		return 0
	return 1
