class_name ContestPrize
extends Resource
##
## ContestPrize — what one place in a contest wins (DECISIONS 059): gold,
## and things for the bag (a trophy to stand on the farm).
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var gold: int = 0

## Items given, and how many of each.
@export var items: Dictionary[ItemDef, int] = {}


## "250g and a bird bath", or "" for nothing.
func text() -> String:
	var parts: Array[String] = []
	if gold > 0:
		parts.append("%dg" % gold)
	for item: ItemDef in items:
		var count: int = items[item]
		if count == 1:
			var word := item.display_name.to_lower()
			parts.append(("an " if "aeiou".contains(word.left(1)) else "a ") + word)
		else:
			parts.append("%d %s" % [count, QuestGoal.plural(item.display_name, count)])
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
