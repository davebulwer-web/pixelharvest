class_name JobTemplate
extends OrderTemplate
##
## JobTemplate — the pattern for an odd job at the allotments on the Lane
## (DECISIONS 062): "pull the weeds in plot 3", "water plot 6 before noon",
## "dig over plot 2". One .tres in data/orders/, beside the other order
## patterns; ContentDB finds it there.
##
## A job is done with your own tools on someone else's ground: the hoe, the
## can, the sickle or your hands, on one of the allotment beds. It's paid on
## the spot when the last of it is done (nobody to go back to), from the shed
## where it was pinned up. Its `items` are left empty: a job asks for work,
## not things.
##
## Each day the Quests service puts up one job from every pattern of this
## kind that's available (set `always_up`), each on a different bed, with
## its size and pay from the day's dice. Taking one leaves the others up, so
## on a day with energy to spare all three can be done, one after another.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## What the job is: &"weed" (pull weeds: by hand, the hoe or the sickle),
## &"water" (the can), &"dig" (the hoe). The tools say which work they do
## (ToolAction.away_work), and the allotments know what each looks like.
@export var work: StringName = &"weed"

## For weeding, how many weeds (never more than the bed has room for). For
## watering and digging, the whole bed is the job, and these aren't used.
@export var cells_min: int = 4
@export var cells_max: int = 8

## What it pays: this much for each tile of work, plus `bonus_gold`
## (before the difficulty).
@export var pay_per_cell: int = 3

## The time it's due by, in minutes after midnight (720 is noon). 0: by the
## end of the day.
@export var due_time: int = 0

## Seasons (SeasonTheme ids) it's put up in. Empty: all year. Nobody waters
## a bare winter bed.
@export var seasons: Array[StringName] = []


## Do the work on the bed `params` names, `params`' "count" tiles of it.
func make_goal(_item: ItemDef, params: Dictionary) -> QuestGoal:
	var goal := AllotmentGoal.new()
	goal.work = work
	goal.plot = int(params.get("plot", 1))
	goal.amount = int(params.get("count", 1))
	return goal
