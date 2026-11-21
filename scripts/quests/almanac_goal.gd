class_name AlmanacGoal
extends QuestGoal
##
## AlmanacGoal — "fill in 12 more entries of the almanac" (DECISIONS 085).
## Counts each entry that goes into the almanac for the first time after the
## request was taken (EventBus almanac_entry_added), optionally only on one
## page (`page`: &"fish" for the river and pond fish). Entries already filled
## in before don't count: the request is about finding new things.
##

## Only entries on this page count (Almanac.PAGES: &"crops", &"fish",
## &"sea_fish", &"forage", &"sea_forage", &"recipes"). &"": any page.
@export var page: StringName = &""

## What to call that page in the request's text ("river and pond fish").
## "": "entries".
@export var page_words: String = ""


func describe() -> String:
	var what := page_words if page_words != "" else ("entry" if amount == 1 else "entries")
	return "Fill in %d new %s in the almanac (L)" % [amount, what]


func counts(event: StringName, args: Array) -> int:
	# almanac_entry_added(page, entry_id)
	if event != &"almanac_entry_added":
		return 0
	if page != &"" and args[0] != page:
		return 0
	return 1
