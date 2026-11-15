class_name HarvestGoal
extends QuestGoal
##
## HarvestGoal — "grow and pick 3 strawberries". Counts every harvest of `crop`
## after the request was accepted (EventBus.crop_harvested). With no crop set,
## any harvest counts. What's picked stays the player's: nothing is handed in.
##

@export var crop: CropDef


func describe() -> String:
	if crop == null:
		return "Harvest %d crops" % amount
	var crop_name := crop.produce.display_name if crop.produce != null else crop.display_name
	return "Harvest %d %s" % [amount, plural(crop_name, amount)]


func counts(event: StringName, args: Array) -> int:
	# crop_harvested(cell, crop_id, amount)
	if event != &"crop_harvested":
		return 0
	if crop != null and args[1] != crop.id:
		return 0
	return args[2]
