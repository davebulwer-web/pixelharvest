class_name ErrandTemplate
extends OrderTemplate
##
## ErrandTemplate — the pattern for Dot the carrier's errands (DECISIONS 062):
## "this parcel to Hollis by 2 PM". One .tres in data/orders/, beside the
## other order patterns; ContentDB finds it there.
##
## An errand is an order whose goal is to carry something Dot hands you
## (`items`: a parcel, a letter) to someone else (`deliver_to`) before a time
## of day (`due_times`). Taking it puts the parcel in your bag; handing it to
## the person it's addressed to pays you on the spot (Dot has been paid
## already). If the time passes first, it runs out there and then and the
## parcel goes back to Dot: no penalty but the pay.
##
## Each day the Quests service picks, with the day's dice, `choices` errands
## to different people who are about that day (Brann only once the forge is
## open, a shopkeeper only if the shop is open before the time), a time for
## each and the pay. Errands whose time has already passed aren't offered.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## Who errands can be for: CharacterDef ids (&"mayor") and shop ids
## (&"seed_shop" is Hollis). Only those about that day are picked.
@export var deliver_to: Array[StringName] = []

## The times of day an errand can be due by, in minutes after midnight (720
## is noon). One is picked for each errand.
@export var due_times: Array[int] = [720]

## What an errand pays, picked between these (before the difficulty).
@export var pay_min: int = 20
@export var pay_max: int = 30


## Carry the parcel (`item`) to whoever `params` says: the rest of who and
## when is on the QuestDef (hand_in_to, due_minute).
func make_goal(item: ItemDef, _params: Dictionary) -> QuestGoal:
	var goal := CarryGoal.new()
	goal.item = item
	goal.amount = 1
	return goal
