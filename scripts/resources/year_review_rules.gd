class_name YearReviewRules
extends Resource
##
## YearReviewRules — what the mayor's year review at lantern night counts and
## the titles it can give (DECISIONS 085).
##
## The review adds up a score from the year's tally (Almanac keeps it,
## GameState saves it): so many points for every `gold_per_point` gold earned
## by selling, so many for each kind of crop grown, fish caught, wild thing
## found and dish cooked, for each request finished and for each festival
## placing. The highest title whose score is reached is the year's title.
##
## Every number and every word the mayor says about the title is here, so
## tuning the review (Stage 26's balance pass) never means touching code
## (rule 6). One file, data/year_review_rules.tres, which game_rules.tres
## points at.
##
## Must not use the GameState autoload: game_rules.tres preloads this file,
## and GameState preloads game_rules.tres (a cycle stops the game starting).
##

## A point for every this many gold earned by selling (the bin, counters,
## market stalls) during the year.
@export var gold_per_point: int = 500

## Points for each different kind of crop picked during the year.
@export var points_per_crop_kind: int = 3
## Points for each different kind of fish caught during the year.
@export var points_per_fish_kind: int = 2
## Points for each different wild thing found (forage) during the year.
@export var points_per_forage_kind: int = 1
## Points for each different dish cooked during the year.
@export var points_per_dish_kind: int = 1
## Points for each request finished during the year (orders and jobs too).
@export var points_per_request: int = 2
## Points for coming first at a festival's contest, and for second or third.
@export var points_per_festival_win: int = 6
@export var points_per_festival_place: int = 2

## The titles, lowest first, and the score each needs. The first should need
## 0, so every year earns one. `title_lines` is what the mayor says after
## naming it, one per title.
@export var titles: Array[String] = []
@export var title_scores: Array[int] = []
@export var title_lines: Array[String] = []

## What the mayor says before reading out the year.
@export var intro_lines: Array[String] = []

## Said instead of the first line when the game was upgraded from before the
## review existed, so the year's tally only started partway through.
@export var partial_line: String = ""


## The index into `titles` that `score` earns: the highest whose score is
## reached. -1 if there are no titles.
func title_index(score: int) -> int:
	var best := -1
	for i in mini(titles.size(), title_scores.size()):
		if score >= title_scores[i]:
			best = i
	return best


## The title `score` earns, or "" if there are none.
func title_for(score: int) -> String:
	var index := title_index(score)
	return titles[index] if index >= 0 else ""


## What the mayor says after naming the title `score` earns, or "".
func line_for(score: int) -> String:
	var index := title_index(score)
	return title_lines[index] if index >= 0 and index < title_lines.size() else ""
