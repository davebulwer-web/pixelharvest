class_name OrderTemplate
extends Resource
##
## OrderTemplate — the pattern for a request that comes round again and again:
## Rosa's market orders and the notice board's daily jobs (DECISIONS 050).
## One .tres in data/orders/ per pattern; ContentDB finds them.
##
## A written request (QuestDef) is asked once. An order is made fresh from
## this pattern on the day: the Quests service picks what's wanted from
## `items` (only things in season, whose seeds you can buy), how many, and
## what it pays, and builds an ordinary QuestDef from it, so the request log,
## the "!" and "?" markers and handing in all work as for any request.
##
## Where it's offered is `posted_at`: a shopkeeper (Rosa is &"market_grocer")
## or the notice board (&"notice_board"). Each day each place picks one of its
## patterns that's available (by `weight`), and that pattern puts up
## `choices` orders, each for a different item, for the player to choose
## between. Rosa offers three; the board one job.
##
## The words can name what was picked: {count} "8", {item} "tomatoes",
## {gold} "420", {client} "Marlow", {due} "by next market day"; an errand's
## {to} "Hollis" and {time} "2 PM", an allotment job's {plot} "3"
## (DECISIONS 062).
##
## Two kinds of pattern extend this one (DECISIONS 062): ErrandTemplate (Dot's
## parcels, carried to someone by a time) and JobTemplate (the allotments'
## odd jobs, done with your own tools). The Quests service picks what each
## kind asks for; each kind makes its own goal (make_goal).
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var id: StringName

## Who offers these orders and takes them in: a shop id (&"market_grocer",
## Rosa) or &"notice_board" (the board in the square: you read it, and leave
## what's asked in the crate beneath it).
@export var posted_at: StringName

## Who the order is for, when it isn't whoever posts it: "Marlow". Only words;
## the order is still handed in where it was posted.
@export var client: String = ""

## For the request log: "Rosa's order: {item}".
@export var title: String = ""

## Said when choosing, before the choices: "The city's after these. Which can
## you do?". Empty: the choices are shown with no line before them.
@export var choice_line: String = ""

## Said when an order is taken.
@export var offer_line: String = ""

## Said if you come back before it's done. The progress and the time left
## are added on.
@export var reminder_line: String = ""

## Said when it's handed in. The reward is added on.
@export var thanks_line: String = ""

## A line for the morning's summary on a day these are on offer: "Help wanted
## on the notice board today." Empty: nothing said.
@export var news_line: String = ""

## What might be wanted. Each day only the ones in season are picked from:
## produce of a crop growing this season whose seeds can be bought (anything
## not grown, like fibre, is always in season).
@export var items: Array[ItemDef] = []

## How many of the item: a number between these…
@export var count_min: int = 3
@export var count_max: int = 6

## …but no more than this is worth at the bin, so an order for pumpkins asks
## for one or two, not six. 0: no cap. Always at least one.
@export var max_value: int = 0

## What it pays, as a multiple of what the same items fetch at the bin (at the
## game's difficulty): 1.5 is half as much again. Plus `bonus_gold`.
@export_range(0.0, 10.0, 0.05) var pay_rate: float = 1.5
@export var bonus_gold: int = 0

## How long the player has, counting the day it's taken (QuestDef.deadline_days):
## 1 is "by tonight", 8 "by the end of next market day".
@export var deadline_days: int = 1

## How many orders to choose between, each for a different item.
@export var choices: int = 1

## How likely this pattern is to be the one a place picks today, against the
## others available there.
@export var weight: int = 1

# --- When it's offered ---------------------------------------------------------

## The first day (GameState.day_number) these can be offered.
@export var first_day: int = 1

## A calendar event (CalendarEvent id) that must be on that day, or &"" for
## any day: Rosa's orders are only on market day, when her stall is up.
@export var on_event: StringName = &""

## Not offered until this is earned (DECISIONS 043). Null: no wait.
@export var requires_unlock: UnlockDef


## Put up every day it's available, alongside whichever of the place's other
## patterns has its turn, instead of taking turns with them (DECISIONS 062):
## the allotment shed has its weeding, watering and digging up together. Each
## such pattern is taken on its own: taking it leaves the others up.
@export var always_up: bool = false

## Said when an order from this pattern runs out (QuestDef.late_line).
@export var late_line: String = ""

## How a choice is put when choosing between them, with the same
## {placeholders}: "A parcel to {to}, by {time}: {gold}g". Empty: "8 tomatoes,
## 420g" (and "for Marlow" if there's a client).
@export var choice_text: String = ""


## The goal of an order made from this pattern: a delivery of `params`'
## "count" of `item`. ErrandTemplate and JobTemplate make their own
## (DECISIONS 062). `item` is looked up by the Quests service, since this
## file touches no autoload.
func make_goal(item: ItemDef, params: Dictionary) -> QuestGoal:
	var goal := DeliverGoal.new()
	goal.item = item
	goal.amount = int(params.get("count", 1))
	return goal


## `text` with its {placeholders} filled in.
static func fill(text: String, values: Dictionary) -> String:
	return text.format(values)
