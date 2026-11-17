class_name ContestRule
extends Resource
##
## ContestRule — what a contest judges, and how it scores an entry
## (DECISIONS 059). The base class accepts nothing. Each kind of contest is a
## small script in scripts/festivals/ — the same pattern as QuestGoal and
## ToolAction: a new contest of an existing kind is only a .tres; a new
## *kind* of contest is one small script.
##
## Two ways to enter:
##   - Something handed over (takes_entry() true): the best flower, the best
##     crop. The host asks which, from what the rule accepts in your bag, and
##     the judge keeps it. can_enter() and score_of() are asked.
##   - Signing up (takes_entry() false): the fishing contest. What counts is
##     what you do afterwards, offered to score_event() as EventBus signals,
##     and the best of it is your score.
##
## A rule never touches an autoload: anything it needs to know about the
## game (how many flower beds are on the farm, whether an item is grown) is
## passed in by the Festivals service.
##


## True if entering means handing something over.
func takes_entry() -> bool:
	return false


## True if `item` may be entered. `grown` says whether a crop gives it.
func can_enter(_item: ItemDef, _grown: bool) -> bool:
	return false


## The score `item` would get. `bonus_count` is how many of the rule's bonus
## objects stand on the farm (see BestItemRule).
func score_of(_item: ItemDef, _bonus_count: int) -> int:
	return 0


## The score something that happened (an EventBus signal's name and its
## values, in order) would give a signed-up entrant, or 0 if it doesn't
## count. The best one so far is the entrant's score.
func score_event(_event: StringName, _args: Array) -> int:
	return 0


## A score in words: "65 points", "34 cm".
func score_text(score: int) -> String:
	return "%d" % score


## A tool the farmer must have to take part (the rod), or null.
func needs_tool() -> ToolDef:
	return null
