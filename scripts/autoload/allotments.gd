extends Node
##
## Allotments — the work on the allotment beds on the Lane today (DECISIONS
## 062): which tiles an odd job wants doing, which are done, and doing them.
##
## The allotment holders pin small jobs on their shed (JobTemplate, posted at
## Quests.ALLOTMENTS); taking one is taking a request like any other. This
## service is the ground half: it knows which bed the job in hand is on,
## which of its tiles want weeding, watering or digging, and which have been
## done today, and it announces each tile done (EventBus.allotment_worked) so
## the request can count it. The Lane scene only draws what this says and
## passes its tools' work here, so walking off to the town and back loses
## nothing.
##
## Nothing here is saved, and nothing needs to be: a job is due the day it's
## taken, and the game saves in the morning, when the beds are tidy again.
##
## Beds are numbered 1 to 8 in LaneLayout.ALLOTMENT_BEDS order: along the top
## row left to right, then the bottom row.
##

const WEED := &"weed"
const WATER := &"water"
const DIG := &"dig"

## How a bed's tile looks now, for the Lane to draw.
const LOOK_PLAIN := &""            # tilled, tended, nothing wanted
const LOOK_WEEDS := &"weeds"       # weeds to pull
const LOOK_DRY := &"dry"           # a holder's crop, the soil dry: water it
const LOOK_WATERED := &"watered"   # watered today
const LOOK_ROUGH := &"rough"       # gone back to grass: dig it over
const LOOK_DUG := &"dug"           # dug over today

## Tiles done today: cell -> the work done there.
var _done: Dictionary = {}  # Vector2i -> StringName


func _ready() -> void:
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _done.clear())
	EventBus.new_game_started.connect(func() -> void: _done.clear())
	EventBus.game_loaded.connect(func() -> void: _done.clear())


# --- The beds -----------------------------------------------------------------

func bed_count() -> int:
	return LaneLayout.ALLOTMENT_BEDS.size()


## The cells of bed `plot` (1 to 8), row by row, or none if there's no such bed.
func bed_cells(plot: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if plot < 1 or plot > bed_count():
		return cells
	var rect: Rect2i = LaneLayout.ALLOTMENT_BEDS[plot - 1]
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


func bed_size(plot: int) -> int:
	return bed_cells(plot).size()


## The bed `cell` is in (1 to 8), or 0.
func plot_at(cell: Vector2i) -> int:
	for n in bed_count():
		if LaneLayout.ALLOTMENT_BEDS[n].has_point(cell):
			return n + 1
	return 0


# --- The job in hand ------------------------------------------------------------

## The allotment job the player has taken and not finished, or null. One at
## a time: the shed asks nothing more while one is open.
func job() -> QuestDef:
	for quest in Quests.active():
		if quest.goal is AllotmentGoal:
			return quest
	return null


## The tiles `quest`'s job wants worked: the whole bed for watering and
## digging; for weeding, as many tiles as there are weeds, picked with dice
## seeded by the request's id, so they're the same wherever you look from.
func job_cells(quest: QuestDef) -> Array[Vector2i]:
	var goal := quest.goal as AllotmentGoal
	if goal == null:
		return []
	var cells := bed_cells(goal.plot)
	if goal.work != WEED or goal.amount >= cells.size():
		return cells
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(String(quest.id))
	for i in range(cells.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	return cells.slice(0, goal.amount)


## The work still wanted at `cell` for the job in hand (&"weed", &"water",
## &"dig"), or &"" if none.
func work_at(cell: Vector2i) -> StringName:
	var quest := job()
	if quest == null or _done.has(cell):
		return &""
	if cell in job_cells(quest):
		return (quest.goal as AllotmentGoal).work
	return &""


## True if any of `works` (a tool's away_work) is wanted at `cell`.
func can_work(cell: Vector2i, works: Array[StringName]) -> bool:
	var work := work_at(cell)
	return work != &"" and work in works


## Do the wanted work at `cell`, if it's one of `works`. Energy has been paid
## by whoever swung the tool. Returns true if something was done.
func do_work(cell: Vector2i, works: Array[StringName]) -> bool:
	if not can_work(cell, works):
		return false
	var work := work_at(cell)
	_done[cell] = work
	EventBus.allotment_worked.emit(plot_at(cell), work, cell)
	return true


## E on a weed in the job's bed: pull it by hand, for the same energy as a
## weed on the farm (HazardRules.pull_weeds_energy, by the difficulty).
func pull_by_hand(cell: Vector2i) -> bool:
	if work_at(cell) != WEED:
		return false
	var rules := GameState.RULES.hazards
	var cost := (rules.pull_weeds_energy if rules != null else 0.0) * GameState.difficulty.energy_cost_multiplier
	if not GameState.try_spend_energy(cost):
		EventBus.message_posted.emit("Too tired to pull weeds")
		return false
	return do_work(cell, [WEED])


# --- How it looks ------------------------------------------------------------------

## How bed tile `cell` looks now (LOOK_*): what the job in hand wants there,
## or what was done there today (it stays watered or dug after the job's
## paid), or plain.
func look_at(cell: Vector2i) -> StringName:
	match work_at(cell):
		WEED:
			return LOOK_WEEDS
		WATER:
			return LOOK_DRY
		DIG:
			return LOOK_ROUGH
	match _done.get(cell, &""):
		WATER:
			return LOOK_WATERED
		DIG:
			return LOOK_DUG
	return LOOK_PLAIN


## The holder's crop growing on bed `plot`, to draw on a bed that wants
## watering (or was watered today): one of the small crops growing this
## season, the same one all day. Null if nothing grows now.
func crop_for(plot: int) -> CropDef:
	var choices: Array[CropDef] = []
	for crop in ContentDB.crops():
		if crop.grows_in(GameState.season_id()) and crop.size == 1 and not crop.tall \
				and not crop.solid and crop.sprite_sheet != null:
			choices.append(crop)
	if choices.is_empty():
		return null
	return choices[absi(hash([plot, GameState.day_number(), "allotment"])) % choices.size()]
