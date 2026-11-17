class_name BestItemRule
extends ContestRule
##
## BestItemRule — "bring your best": the flower show and the harvest fair
## (DECISIONS 059). You hand one thing over; it scores its sell price (the
## ItemDef's own, before any difficulty), so a pumpkin beats a radish.
##
## What can be entered: things with `tag` (&"flower"), or with
## `grown_only`, anything a crop gives (the harvest fair: produce, not fish
## or forage). Both may be set; either may be left empty.
##
## A bonus for something standing on the farm: the flower show adds
## `bonus_each` points for every `bonus_object` (garden flower beds) on the
## farm, up to `bonus_most` — the judge has heard about your garden. The
## Festivals service counts them and passes the count in.
##

## Only things with this tag can be entered. &"": no tag needed.
@export var tag: StringName = &""

## Only things a crop gives can be entered.
@export var grown_only: bool = false

## An ObjectDef id whose copies on the farm add to the score, or &"".
@export var bonus_object: StringName = &""

## Points for each one.
@export var bonus_each: int = 0

## The most the bonus can add. 0: no limit.
@export var bonus_most: int = 0


func takes_entry() -> bool:
	return true


func can_enter(item: ItemDef, grown: bool) -> bool:
	if item == null or item.sell_price <= 0:
		return false
	if tag != &"" and not item.has_tag(tag):
		return false
	if grown_only and not grown:
		return false
	return true


func score_of(item: ItemDef, bonus_count: int) -> int:
	return item.sell_price + bonus(bonus_count)


## The points the farm's bonus objects add.
func bonus(bonus_count: int) -> int:
	if bonus_object == &"" or bonus_each <= 0:
		return 0
	var points := bonus_count * bonus_each
	return mini(points, bonus_most) if bonus_most > 0 else points


func score_text(score: int) -> String:
	return "%d points" % score
