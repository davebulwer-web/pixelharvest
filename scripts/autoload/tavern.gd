extends Node
##
## Tavern — the rules of Nell's tavern, the Wheatsheaf (DECISIONS 068,
## ROADMAP 13.3 #8 and #10): what's on the chalkboard today, what Nell has
## heard tonight, and darts night.
##
## Almost nothing here is state. The chalkboard is picked from the date (the
## same dice however often it's asked, like market orders and the forage),
## so tomorrow's board can be told tonight as a rumour; how many of each
## thing Nell has bought today is Economy's count, like every buyer's. The
## rumour is worked out from things the game already knows a day ahead: the
## weather forecast, the tides, what's in season, tomorrow's chalkboard. The
## only thing remembered is whether you've had your go at darts tonight, and
## that is forgotten overnight (the game only saves in the morning).
##
## The numbers and the words are TavernRules (data/tavern_rules.tres); the
## tavern's room is scripts/town/tavern.gd, and the darts themselves
## DartsGame.
##

## The tavern's ShopDef id, whose ShopDef has the chalkboard.
const SHOP_ID := &"tavern"

## The day darts were last played, and the score, so it's one go a night.
var _darts_played_on: int = -1
var _darts_score: int = 0


func _ready() -> void:
	EventBus.new_game_started.connect(_forget)
	EventBus.game_loaded.connect(_forget)


func _forget() -> void:
	_darts_played_on = -1
	_darts_score = 0


func rules() -> TavernRules:
	return GameState.RULES.tavern


# --- The chalkboard ---------------------------------------------------------------

## What the chalkboard wants on day `number` (a day_number): a few of
## TavernRules.chalkboard_items that are in season that day, picked by dice
## seeded with the date.
func wanted_on(number: int) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	var tavern := rules()
	if tavern == null:
		return result
	var season := GameState.season_id_on(number)
	var pool: Array[ItemDef] = []
	for item in tavern.chalkboard_items:
		if item != null and _in_season(item, season) and item.sell_price > 0:
			pool.append(item)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("chalkboard/%d" % number)
	for i in mini(tavern.chalkboard_count, pool.size()):
		var j := dice.randi_range(i, pool.size() - 1)
		var picked := pool[j]
		pool[j] = pool[i]
		pool[i] = picked
		result.append(picked)
	return result


func wanted_today() -> Array[ItemDef]:
	return wanted_on(GameState.day_number())


## True if `shop` (one with a chalkboard) would take `item` today: it's
## chalked up, and Nell hasn't had her fill of it yet.
func takes_today(item: ItemDef, shop: ShopDef) -> bool:
	return item in wanted_today() and left_today(item, shop) > 0


## How many more of `item` the chalkboard takes today.
func left_today(item: ItemDef, shop: ShopDef) -> int:
	if rules() == null:
		return 0
	return maxi(0, rules().chalkboard_each - Economy.bought_today(item, shop))


## The chalkboard in words, for reading it and for the notice board:
## "Wanted today: Parsnips (5 more), Wild garlic (5 more)." Things Nell has
## had her fill of are crossed off.
func chalkboard_lines() -> Array[String]:
	var lines: Array[String] = []
	var shop := ContentDB.shop(SHOP_ID)
	var wanted := wanted_today()
	if shop == null or wanted.is_empty():
		lines.append("The chalkboard's wiped clean. Nothing wanted today.")
		return lines
	var parts: Array[String] = []
	for item in wanted:
		var left := left_today(item, shop)
		if left <= 0:
			parts.append("%s (had enough)" % item.display_name)
		else:
			parts.append("%s (%d wanted, %dg each)" % [item.display_name, left,
					Economy.full_store_price(item, shop)])
	lines.append("WANTED TODAY, paid at the bar: %s." % ", ".join(parts))
	lines.append("Half as much again as the shipping bin pays, and paid on the spot. Open %s."
			% shop.hours_text())
	return lines


## For the notice board: "The Wheatsheaf's chalkboard wants parsnips, wild
## garlic and mackerel today." Empty before the tavern opens.
func notice_text() -> String:
	var location := LocationManager.find(SHOP_ID)
	if location != null and not GameState.has_unlock(location.requires_unlock):
		return ""
	var wanted := wanted_today()
	if wanted.is_empty():
		return ""
	return "The Wheatsheaf's chalkboard wants %s today, at half as much again as the bin pays." \
			% QuestGoal.list_names(wanted)


## True if `item` is in season on a day in `season`: a crop growing then
## whose seeds can be bought now, a wild thing growing then, a fish biting
## then (and not only in some weather). Anything else is always in season.
func _in_season(item: ItemDef, season: StringName) -> bool:
	if item is FishDef:
		var fish := item as FishDef
		return season in fish.seasons and fish.only_in_weather.is_empty()
	if item is ForageDef:
		var wild := item as ForageDef
		return (wild.seasons.is_empty() or season in wild.seasons) and wild.only_in_weather.is_empty()
	var crop := ContentDB.crop_giving(item)
	if crop != null:
		if not crop.grows_in(season):
			return false
		var seeds := ContentDB.seeds_for(crop)
		return seeds != null and seeds.buy_price > 0 and GameState.has_unlock(seeds.requires_unlock)
	return true


# --- Rumours ------------------------------------------------------------------------

## What Nell has heard tonight: one rumour a day, the kind turning with the
## date, each about tomorrow and each true (the forecast is never wrong, the
## tides and the chalkboard are worked out, the forage and fish are what
## grows and bites tomorrow). A kind with nothing to tell gives way to the
## next; with nothing at all, a bit of gossip.
func rumour_tonight() -> String:
	var tavern := rules()
	if tavern == null:
		return ""
	var tomorrow := GameState.day_number() + 1
	var kinds: Array[Callable] = [_rumour_chalkboard, _rumour_forage, _rumour_fish, _rumour_tides,
			_rumour_weather]
	var first := posmod(GameState.day_number(), kinds.size())
	for n in kinds.size():
		var text: String = kinds[(first + n) % kinds.size()].call(tavern, tomorrow)
		if text != "":
			return text
	if tavern.gossip.is_empty():
		return ""
	return tavern.gossip[posmod(GameState.day_number(), tavern.gossip.size())]


func _rumour_chalkboard(tavern: TavernRules, tomorrow: int) -> String:
	var wanted := wanted_on(tomorrow)
	if wanted.is_empty():
		return ""
	return tavern.rumour_chalkboard.format({"items": QuestGoal.list_names(wanted).to_lower()})


## The most valuable wild thing growing tomorrow somewhere you can get to,
## preferring one that only comes up in tomorrow's weather (the reason to go).
func _rumour_forage(tavern: TavernRules, tomorrow: int) -> String:
	var season := GameState.season_id_on(tomorrow)
	var weather_id: StringName = GameState.forecast.id if GameState.forecast != null else &""
	var best: ForageDef = null
	var best_place: StringName = &""
	for place: StringName in tavern.place_words:
		var location := LocationManager.find(place)
		if location == null or not GameState.has_unlock(location.requires_unlock):
			continue
		for wild in ContentDB.forage_growing(place, season, weather_id):
			if wild.at_low_tide:
				continue  # the tides rumour covers the rockpools
			if best == null or _better_find(wild, best):
				best = wild
				best_place = place
	if best == null:
		return ""
	var item: ItemDef = best.gives if best.gives != null else best
	return tavern.rumour_forage.format({"item": item.display_name.to_lower(),
			"where": tavern.place_words[best_place]})


func _better_find(a: ForageDef, b: ForageDef) -> bool:
	var a_special := not a.only_in_weather.is_empty()
	var b_special := not b.only_in_weather.is_empty()
	if a_special != b_special:
		return a_special
	return a.sell_price > b.sell_price


## The biggest fish biting tomorrow in water you can fish, preferring one
## that only bites in tomorrow's weather.
func _rumour_fish(tavern: TavernRules, tomorrow: int) -> String:
	var season := GameState.season_id_on(tomorrow)
	var weather_id: StringName = GameState.forecast.id if GameState.forecast != null else &""
	var best: FishDef = null
	for fish in ContentDB.fish():
		if season not in fish.seasons:
			continue
		if not fish.only_in_weather.is_empty() and weather_id not in fish.only_in_weather:
			continue
		var known_water := false
		for water in fish.waters:
			if tavern.water_words.has(water):
				known_water = true
		if not known_water:
			continue
		if best == null or _better_fish(fish, best):
			best = fish
	if best == null:
		return ""
	var where := ""
	for water in best.waters:
		if tavern.water_words.has(water):
			where = tavern.water_words[water]
			break
	return tavern.rumour_fish.format({"fish": best.display_name.to_lower(), "where": where,
			"hours": best.hours_text()})


func _better_fish(a: FishDef, b: FishDef) -> bool:
	var a_special := not a.only_in_weather.is_empty()
	var b_special := not b.only_in_weather.is_empty()
	if a_special != b_special:
		return a_special
	return a.max_size > b.max_size


func _rumour_tides(tavern: TavernRules, tomorrow: int) -> String:
	var lows := Tides.lows_on(tomorrow)
	if lows.is_empty():
		return ""
	var times: Array[String] = []
	for low in lows:
		times.append(Clock.format(low))
	return tavern.rumour_tides.format({"tides": " and ".join(times)})


func _rumour_weather(tavern: TavernRules, _tomorrow: int) -> String:
	if GameState.forecast == null:
		return ""
	return tavern.rumour_weather.format({"weather": GameState.forecast.display_name.to_lower()})


# --- Darts night ---------------------------------------------------------------------

## True if day `number` (a day_number; today if left out) is darts night and
## the tavern is open for business by then.
func is_darts_night(number: int = -1) -> bool:
	if rules() == null:
		return false
	if number < 0:
		number = GameState.day_number()
	var location := LocationManager.find(SHOP_ID)
	if location != null and not GameState.has_unlock(location.requires_unlock):
		return false
	return Schedules.weekday(number) == rules().darts_weekday


## True if the darts are out now: darts night, from its time.
func darts_on_now() -> bool:
	return is_darts_night() and GameState.minutes >= rules().darts_from


func has_played_tonight() -> bool:
	return _darts_played_on == GameState.day_number()


## Tonight's best score among the regulars and who holds it: the same all
## evening. Whoever is in the tavern when the darts come out (by their
## schedules) is a candidate; with nobody named, "one of the regulars".
func tonights_best() -> Dictionary:
	var tavern := rules()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("darts/%d" % GameState.day_number())
	var score := dice.randi_range(tavern.rival_min, tavern.rival_max)
	var names: Array[String] = []
	var shop := ContentDB.shop(SHOP_ID)
	for person in Schedules.people_at(SHOP_ID, tavern.darts_from):
		if shop == null or person.id != shop.keeper_id:
			names.append(person.display_name)
	var who := tavern.regulars_name
	if not names.is_empty():
		who = names[dice.randi_range(0, names.size() - 1)]
	return {"score": score, "who": who}


## The score of one dart landing at `offset` from the bull, as a share of
## the board's radius (so (0, 0) is the bull, length 1 the edge).
func dart_score(offset: Vector2) -> int:
	var tavern := rules()
	var distance := offset.length()
	for i in mini(tavern.ring_radii.size(), tavern.ring_points.size()):
		if distance <= tavern.ring_radii[i]:
			return tavern.ring_points[i]
	return 0


## Your go is over with `score`: remember it for tonight, pay the prize if
## it beats the best, and say how it went.
func finish_darts(score: int) -> Array[String]:
	_darts_played_on = GameState.day_number()
	_darts_score = score
	var best := tonights_best()
	var lines: Array[String] = []
	if score > int(best["score"]):
		GameState.add_gold(rules().darts_prize_gold)
		lines.append("%d! That beats %s's %d. The bar cheers, and Nell hands you the pot: %dg."
				% [score, best["who"], best["score"], rules().darts_prize_gold])
	elif score == int(best["score"]):
		lines.append("%d: level with %s. No prize for a tie, but the round's on the house."
				% [score, best["who"]])
	else:
		lines.append("%d. %s's %d still stands. Better luck next week." % [score, best["who"], best["score"]])
	return lines


## What the dartboard says when you face it and the darts aren't for you.
func darts_board_lines() -> Array[String]:
	var lines: Array[String] = []
	var tavern := rules()
	var night := Schedules.WEEKDAY_NAMES[tavern.darts_weekday]
	if has_played_tonight():
		lines.append("You've had your go tonight: %d. Darts again next %s." % [_darts_score, night])
	elif is_darts_night() and not darts_on_now():
		lines.append("Darts night tonight! The darts come out at %s." % Clock.format_short(tavern.darts_from))
	elif not is_darts_night():
		lines.append("Darts night is %s, from %s. Beat the night's best score and the pot's yours: %dg."
				% [night, Clock.format_short(tavern.darts_from), tavern.darts_prize_gold])
	return lines
