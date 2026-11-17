class_name ContestDef
extends Resource
##
## ContestDef — the judging at a festival (DECISIONS 059): what can be
## entered and how it scores (a ContestRule), when the judge decides, who
## else has entered, and the prizes for first, second and third.
##
## A contest belongs to a CalendarEvent (its `contest`), and is run by the
## event's host, who stands at the festival all day: talk to them to enter.
## Every contest works the same way, which is why a new one is a .tres:
##
##   - Before judging, the host asks what you'll enter (the best few things
##     in your bag that the rule accepts), or for a fishing contest signs
##     you up. You enter once.
##   - At `judged_at` the judge scores the entries. The rivals' scores are
##     rolled with dice seeded by the date, so the same day always gives the
##     same field however often it's played. Your place is one more than
##     the number of rivals who beat you (a tie goes your way).
##   - The prize for your place is handed over at once, and the host tells
##     you the results when you next speak to them.
##
## Nothing in this file may touch an autoload (it is plain data).
##

## What can be entered, and how it scores.
@export var rule: ContestRule

## When the judge decides, in minutes after midnight (840 = 2 PM). Entries
## close then. If the day ends first (the farmer went to bed early), the
## judging happens as the day ends.
@export var judged_at: int = 840

## Everyone else who enters, every time.
@export var rivals: Array[ContestRival] = []

## The prizes, first place first. A place with no prize (fourth, say) gets
## the judge's thanks.
@export var prizes: Array[ContestPrize] = []

## What the host says when you haven't entered yet, before the question.
@export var invite_lines: Array[String] = []

## The question, with the choices under it: "What will you put on the table?"
@export var question: String = "What will you enter?"

## The choice that signs you up, for a contest with nothing to hand over
## (the fishing contest).
@export var sign_up_choice: String = "Sign me up"

## What the host says when you have nothing that could be entered.
@export var nothing_line: String = ""

## What the host says as you enter. {entry} is what you entered, {time} the
## judging time.
@export var entered_line: String = ""

## What the host says if you come back before the judging. {entry}, {score}
## and {time} are filled in.
@export var waiting_line: String = ""

## What the host says to start the results.
@export var results_line: String = "The results!"


## The prize for `place` (1 is first), or null.
func prize_for(place: int) -> ContestPrize:
	if place < 1 or place > prizes.size():
		return null
	return prizes[place - 1]


## "1st", "2nd", "3rd", "4th"…
static func place_text(place: int) -> String:
	match place:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
	return "%dth" % place


## Fill {entry}, {score} and {time} into one of the lines above.
static func fill(line: String, words: Dictionary) -> String:
	var text := line
	for key: String in words:
		text = text.replace("{%s}" % key, str(words[key]))
	return text
