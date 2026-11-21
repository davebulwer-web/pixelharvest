extends Node
##
## Almanac — the collections book and the mayor's year review (DECISIONS 085).
##
## The book has six pages: crops, fish (river, stream and pond), sea fish,
## forage (the Woods and the Lane), sea forage (the Cove) and recipes (dishes
## cooked at the farmhouse stove). Every page is worked out from content, so a
## new crop, fish, wild thing or recipe .tres is in the book without a code
## change (rule 3): an entry is filled in once it has been grown, caught,
## found or cooked, and greyed out with a hint until then.
##
## What's been grown and found is kept in GameState.collections; fish come
## from GameState.fish_log and dishes from GameState.recipes, which already
## counted them. This service listens on EventBus and writes the new counts,
## announces each first-time entry (almanac_entry_added, which AlmanacGoal
## requests count), and keeps this year's tally (GameState.year_stats).
##
## The year review: at lantern night (the CalendarEvent with year_review on)
## the mayor reads out the year when he gives his lantern (Festivals asks
## give_review() for the words). The tally becomes a score
## (YearReviewRules, data/year_review_rules.tres) and the score a title. The
## review is kept in GameState.year_reviews. If the farmer misses lantern
## night, the year still closes the night it turns, and the mayor's review is
## left as a note: the morning's summary says so, and the almanac's Years page
## has it either way.
##
## Nothing here is saved: everything it keeps is in GameState.
##

const PAGES: Array[StringName] = [&"crops", &"fish", &"sea_fish", &"forage", &"sea_forage", &"recipes"]

const PAGE_NAMES: Dictionary = {
	&"crops": "Crops",
	&"fish": "Fish",
	&"sea_fish": "Sea fish",
	&"forage": "Forage",
	&"sea_forage": "Sea forage",
	&"recipes": "Recipes",
}

## What each kind of water and place is called in a hint.
const WATER_NAMES: Dictionary = {&"pond": "ponds", &"river": "the river", &"stream": "the Woods' stream",
		&"sea": "the sea"}
const PLACE_NAMES: Dictionary = {&"woods": "the Woods", &"lane": "the Lane's hedgerows", &"cove": "the Cove",
		&"farm": "the farm", &"town": "the town"}

## The season order crops and forage are listed in; anything else comes last.
const SEASON_ORDER: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

## The morning's news about the year review (a note left because lantern
## night was missed), shown once by the day's summary.
var _note_today: String = ""


func _ready() -> void:
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.foraged.connect(_on_foraged)
	EventBus.fish_caught.connect(_on_fish_caught)
	EventBus.dish_cooked.connect(_on_dish_cooked)
	EventBus.quest_completed.connect(func(_id: StringName) -> void: _add(&"requests", 1))
	# Gold earned by selling: the bin overnight, and counters and stalls.
	EventBus.shipment_sold.connect(func(gold: int) -> void: _add(&"earned", gold))
	EventBus.items_sold_to_shop.connect(func(_id: StringName, _n: int, gold: int) -> void: _add(&"earned", gold))
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: _on_day_started())
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.new_game_started.connect(func() -> void: _note_today = "")


# --- The pages ------------------------------------------------------------------

## The page an entry belongs on, given what it is.
static func page_of_fish(fish: FishDef) -> StringName:
	for water in fish.waters:
		if water != &"sea":
			return &"fish"
	return &"sea_fish" if fish.waters.has(&"sea") else &"fish"


static func page_of_forage(forage: ForageDef) -> StringName:
	return &"sea_forage" if forage.found_in.has(&"cove") else &"forage"


## Every entry on `page`, in the book's order. Each is a Dictionary:
## {"id", "name", "icon": Texture2D, "known": bool, "detail": String}. A
## known entry's detail says how many and where; an unknown one's is a hint.
func entries(page: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		&"crops":
			var crops := ContentDB.crops()
			crops.sort_custom(func(a: CropDef, b: CropDef) -> bool:
				return _season_key(a.seasons, a.display_name) < _season_key(b.seasons, b.display_name))
			for crop in crops:
				result.append(_crop_entry(crop))
		&"fish", &"sea_fish":
			var fish := ContentDB.fish().filter(func(f: FishDef) -> bool: return page_of_fish(f) == page)
			fish.sort_custom(func(a: FishDef, b: FishDef) -> bool:
				return _season_key(a.seasons, a.display_name) < _season_key(b.seasons, b.display_name))
			for each: FishDef in fish:
				result.append(_fish_entry(each))
		&"forage", &"sea_forage":
			var forage := ContentDB.forage().filter(func(f: ForageDef) -> bool: return page_of_forage(f) == page)
			forage.sort_custom(func(a: ForageDef, b: ForageDef) -> bool:
				return _season_key(a.seasons, a.display_name) < _season_key(b.seasons, b.display_name))
			for each: ForageDef in forage:
				result.append(_forage_entry(each))
		&"recipes":
			var recipes := ContentDB.recipes().filter(func(r: RecipeDef) -> bool:
				return r.made_at == &"stove" and r.product() != null)
			recipes.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool: return a.display_name() < b.display_name())
			for each: RecipeDef in recipes:
				result.append(_recipe_entry(each))
	return result


## How many of `page`'s entries are filled in, and how many there are.
func filled(page: StringName) -> int:
	return entries(page).filter(func(e: Dictionary) -> bool: return e["known"]).size()


func total(page: StringName) -> int:
	return entries(page).size()


## Filled in and in all, across every page.
func filled_all() -> int:
	var count := 0
	for page in PAGES:
		count += filled(page)
	return count


func total_all() -> int:
	var count := 0
	for page in PAGES:
		count += total(page)
	return count


func _crop_entry(crop: CropDef) -> Dictionary:
	var picked := int(GameState.collections["grown"].get(crop.id, 0))
	var grows := "Grows %s." % _when(crop.seasons)
	var detail := grows
	if picked > 0:
		detail = "Picked %s.  %s" % [_times(picked), grows]
	return {"id": crop.id, "name": crop.display_name, "known": picked > 0, "detail": detail,
			"icon": crop.produce.icon if crop.produce != null else null}


func _fish_entry(fish: FishDef) -> Dictionary:
	var caught := GameState.fish_caught_count(fish.id)
	var waters: Array[String] = []
	for water in fish.waters:
		waters.append(WATER_NAMES.get(water, String(water)))
	var when := _when(fish.seasons)
	var hours := ""
	if fish.bites_from > GameState.RULES.day_start_minutes or fish.bites_until < GameState.RULES.day_end_minutes:
		hours = ", %s to %s" % [Clock.format_short(fish.bites_from), Clock.format_short(fish.bites_until)]
	var hint := "Bites in %s %s%s." % [_and_list(waters), when, hours]
	if fish.only_at_high_tide:
		hint = hint.trim_suffix(".") + ", at high tide."
	if not fish.only_in_weather.is_empty():
		var weathers: Array[String] = []
		for id in fish.only_in_weather:
			var weather := ContentDB.weather(id)
			weathers.append(weather.display_name.to_lower() if weather != null else String(id))
		hint = hint.trim_suffix(".") + ", only in %s." % _and_list(weathers, "or")
	var detail := hint
	if caught > 0:
		detail = "Caught %d, the biggest %d cm.  %s" % [caught, GameState.biggest_fish(fish.id), hint]
	return {"id": fish.id, "name": fish.display_name, "known": caught > 0, "detail": detail, "icon": fish.icon}


func _forage_entry(forage: ForageDef) -> Dictionary:
	var found := int(GameState.collections["foraged"].get(forage.id, 0))
	var places: Array[String] = []
	for place in forage.found_in:
		places.append(PLACE_NAMES.get(place, String(place)))
	var when := _when(forage.seasons)
	var hint := "Found in %s %s" % [_and_list(places), when]
	if forage.at_low_tide:
		hint += ", at low tide"
	hint += "."
	var detail := hint
	if found > 0:
		detail = "Found %s.  %s" % [_times(found), hint]
	return {"id": forage.id, "name": forage.display_name, "known": found > 0, "detail": detail, "icon": forage.icon}


func _recipe_entry(recipe: RecipeDef) -> Dictionary:
	var cooked := GameState.times_cooked(recipe.id)
	var detail := "Not learnt yet: someone in the valley will teach it."
	if GameState.knows_recipe(recipe.id):
		detail = "Learnt, not cooked yet. Cook it at the farmhouse stove."
	if cooked > 0:
		detail = "Cooked %s." % _times(cooked)
	return {"id": recipe.id, "name": recipe.display_name(), "known": cooked > 0, "detail": detail,
			"icon": recipe.product().icon}


## "in spring and summer", or "all year" for no seasons or every one.
func _when(seasons: Array[StringName]) -> String:
	if seasons.is_empty() or SEASON_ORDER.all(func(s: StringName) -> bool: return seasons.has(s)):
		return "all year"
	return "in " + GameState.describe_seasons(seasons).to_lower()


## Sorts by first season (spring first, all-year last), then by name.
func _season_key(seasons: Array[StringName], name: String) -> String:
	var first := SEASON_ORDER.size()
	for season in seasons:
		var at := SEASON_ORDER.find(season)
		if at >= 0:
			first = mini(first, at)
	return "%d %s" % [first, name.to_lower()]


# --- Keeping count -----------------------------------------------------------------

func _on_crop_harvested(_cell: Vector2i, crop_id: StringName, amount: int) -> void:
	var grown: Dictionary = GameState.collections["grown"]
	var first := not grown.has(crop_id)
	grown[crop_id] = int(grown.get(crop_id, 0)) + amount
	_add(&"harvested", amount)
	_add_kind(&"crops", crop_id)
	if first:
		_entry_added(&"crops", crop_id)


func _on_foraged(item_id: StringName, _location_id: StringName) -> void:
	var forage := ContentDB.item(item_id) as ForageDef
	if forage == null:
		return
	var found: Dictionary = GameState.collections["foraged"]
	var first := not found.has(item_id)
	found[item_id] = int(found.get(item_id, 0)) + 1
	_add(&"foraged", 1)
	_add_kind(&"forage_kinds", item_id)
	if first:
		_entry_added(page_of_forage(forage), item_id)


## The fish log is GameState's, already counted by the time this is heard.
func _on_fish_caught(fish_id: StringName, _size: int, _location_id: StringName, _water: StringName,
		_through_ice: bool) -> void:
	_add(&"fish", 1)
	_add_kind(&"fish_kinds", fish_id)
	var fish := ContentDB.item(fish_id) as FishDef
	if fish != null and GameState.fish_caught_count(fish_id) == 1:
		_entry_added(page_of_fish(fish), fish_id)


## Recipes count their own cooking, already done by the time this is heard.
func _on_dish_cooked(recipe_id: StringName, _dish_id: StringName) -> void:
	_add(&"cooked", 1)
	_add_kind(&"dish_kinds", recipe_id)
	var recipe := ContentDB.recipe(recipe_id)
	if recipe != null and recipe.made_at == &"stove" and GameState.times_cooked(recipe_id) == 1:
		_entry_added(&"recipes", recipe_id)


func _entry_added(page: StringName, entry_id: StringName) -> void:
	_add(&"new_entries", 1)
	EventBus.almanac_entry_added.emit(page, entry_id)


func _add(key: StringName, amount: int) -> void:
	if GameState.year_stats.is_empty():
		GameState.year_stats = GameState.fresh_year_stats(GameState.year)
	GameState.year_stats[String(key)] = int(GameState.year_stats.get(String(key), 0)) + amount


func _add_kind(key: StringName, id: StringName) -> void:
	if GameState.year_stats.is_empty():
		GameState.year_stats = GameState.fresh_year_stats(GameState.year)
	var kinds: Array = GameState.year_stats.get(String(key), [])
	if not kinds.has(String(id)):
		kinds.append(String(id))
	GameState.year_stats[String(key)] = kinds


# --- The year review ---------------------------------------------------------------

## The year's score from a tally (GameState.year_stats, or a review's stats).
func score(stats: Dictionary) -> int:
	var rules := GameState.RULES.year_review
	if rules == null:
		return 0
	var points := 0
	if rules.gold_per_point > 0:
		points += int(stats.get("earned", 0)) / rules.gold_per_point
	points += _kinds(stats, "crops") * rules.points_per_crop_kind
	points += _kinds(stats, "fish_kinds") * rules.points_per_fish_kind
	points += _kinds(stats, "forage_kinds") * rules.points_per_forage_kind
	points += _kinds(stats, "dish_kinds") * rules.points_per_dish_kind
	points += int(stats.get("requests", 0)) * rules.points_per_request
	for entry in festivals_in(int(stats.get("year", 0))):
		var place := int(entry.get("place", 0))
		if place == 1:
			points += rules.points_per_festival_win
		elif place in [2, 3]:
			points += rules.points_per_festival_place
	return points


## The title a tally earns, or "" if game_rules.tres has no titles.
func title_for(stats: Dictionary) -> String:
	var rules := GameState.RULES.year_review
	return rules.title_for(score(stats)) if rules != null else ""


## The review of `year`, or {} if it hasn't been given.
func review_of(year: int) -> Dictionary:
	for review in GameState.year_reviews:
		if int(review.get("year", 0)) == year:
			return review
	return {}


## True if this year's review hasn't been given yet.
func review_due() -> bool:
	return review_of(int(GameState.year_stats.get("year", GameState.year))).is_empty()


## The festival log's entries for `year`, contests only (place 1 or more).
func festivals_in(year: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in GameState.festival_log:
		if int(entry.get("year", 0)) == year and int(entry.get("place", 0)) > 0:
			result.append(entry)
	return result


## Lantern night: the mayor reads out the year. Records the review (heard)
## and returns what he says. Asked again the same year, he says it again
## without recording it twice.
func give_review() -> Array[String]:
	var stats := GameState.year_stats
	var year := int(stats.get("year", GameState.year))
	var review := review_of(year)
	if review.is_empty():
		review = _record_review(stats, true)
	return review_lines(review)


## What the mayor says about `review` (one of GameState.year_reviews).
func review_lines(review: Dictionary) -> Array[String]:
	var rules := GameState.RULES.year_review
	var stats: Dictionary = review.get("stats", {})
	var year := int(review.get("year", 1))
	var lines: Array[String] = []
	if rules != null:
		if stats.get("partial", false) and rules.partial_line != "":
			lines.append(rules.partial_line)
		else:
			lines.append_array(rules.intro_lines)
	lines.append_array(stat_lines(stats, "you"))
	var title := str(review.get("title", ""))
	if title != "":
		lines.append("So for year %d, the valley names you: %s!" % [year, title])
		var said := rules.line_for(int(review.get("score", 0))) if rules != null else ""
		if said != "":
			lines.append(said)
		var last := review_of(year - 1)
		if rules != null and not last.is_empty() \
				and rules.title_index(int(review.get("score", 0))) > rules.title_index(int(last.get("score", 0))):
			lines.append("[happy]Better than last year's \"%s\", too!" % last.get("title", ""))
	return lines


## The year's tally in sentences, about `who` ("you" for the mayor's review;
## the almanac's Years page uses the same words).
func stat_lines(stats: Dictionary, who: String = "you") -> Array[String]:
	var lines: Array[String] = []
	var harvested := int(stats.get("harvested", 0))
	var earned := int(stats.get("earned", 0))
	var crop_kinds := _kinds(stats, "crops")
	var picked := "%s picked %s %s of %d %s" % [who.capitalize(), _number(harvested), "crop" if harvested == 1 else "crops",
			crop_kinds, "kind" if crop_kinds == 1 else "kinds"] if harvested > 0 else ""
	var sold := "sold %sg worth" % _number(earned) if earned > 0 else ""
	if picked != "" and sold != "":
		lines.append("%s, and %s." % [picked, sold])
	elif picked != "":
		lines.append(picked + ".")
	elif sold != "":
		lines.append("%s %s." % [who.capitalize(), sold])
	var parts: Array[String] = []
	var fish := int(stats.get("fish", 0))
	if fish > 0:
		var fish_kinds := _kinds(stats, "fish_kinds")
		parts.append("caught %d fish of %d %s" % [fish, fish_kinds, "kind" if fish_kinds == 1 else "kinds"])
	var foraged := int(stats.get("foraged", 0))
	if foraged > 0:
		parts.append("found %d wild %s" % [foraged, "thing" if foraged == 1 else "things"])
	var cooked := int(stats.get("cooked", 0))
	if cooked > 0:
		parts.append("cooked %d %s" % [cooked, "dish" if cooked == 1 else "dishes"])
	if not parts.is_empty():
		lines.append("%s %s." % [who.capitalize(), _and_list(parts)])
	var requests := int(stats.get("requests", 0))
	var festival_text := _festival_text(int(stats.get("year", 0)))
	if requests > 0:
		var text := "%s finished %d %s for the valley" % [who.capitalize(), requests,
				"request" if requests == 1 else "requests"]
		lines.append(text + (", and " + festival_text if festival_text != "" else "") + ".")
	elif festival_text != "":
		lines.append("%s %s." % [who.capitalize(), festival_text])
	var new_entries := int(stats.get("new_entries", 0))
	if new_entries > 0:
		# A closed year's own count; this year's as it is now.
		var book_filled := int(stats.get("filled", filled_all()))
		var book_total := int(stats.get("total", total_all()))
		lines.append("The almanac gained %d %s, and has %d of %d filled in." % [new_entries,
				"entry" if new_entries == 1 else "entries", book_filled, book_total])
	if lines.is_empty():
		lines.append("A quiet year. They're allowed.")
	return lines


## "came first at the flower show and second at the harvest fair", or "".
func _festival_text(year: int) -> String:
	var parts: Array[String] = []
	for entry in festivals_in(year):
		var place := int(entry.get("place", 0))
		if place > 3:
			continue
		var event := ContentDB.event(StringName(entry.get("event", "")))
		var name := event.display_name.to_lower() if event != null else str(entry.get("event", ""))
		parts.append("%s at the %s" % [["", "first", "second", "third"][place], name])
	if parts.is_empty():
		return ""
	return "came " + _and_list(parts)


## Write down a review of `stats`: its title and score. `heard` says whether
## the mayor read it out (lantern night) or left it as a note.
func _record_review(stats: Dictionary, heard: bool) -> Dictionary:
	var year := int(stats.get("year", GameState.year))
	var review := {"year": year, "title": title_for(stats), "score": score(stats), "heard": heard,
			"stats": _closed(stats)}
	GameState.year_reviews.append(review)
	EventBus.year_reviewed.emit(year, str(review["title"]), heard)
	return review


## A copy of a tally to keep with its review, with how full the almanac was.
func _closed(stats: Dictionary) -> Dictionary:
	var kept := stats.duplicate(true)
	kept["filled"] = filled_all()
	kept["total"] = total_all()
	return kept


## A new morning: if the year has turned since the tally was started, close
## it. A review given at lantern night keeps its title and gets the final
## tally (the night's sales); one that wasn't given is left as a note.
func _on_day_started() -> void:
	_note_today = ""
	_close_turned_year(true)


func _on_game_loaded() -> void:
	_note_today = ""
	_close_turned_year(false)


func _close_turned_year(tell: bool) -> void:
	if GameState.year_stats.is_empty():
		GameState.year_stats = GameState.fresh_year_stats(GameState.year)
		return
	var old_year := int(GameState.year_stats.get("year", GameState.year))
	if old_year >= GameState.year:
		return
	var review := review_of(old_year)
	if review.is_empty():
		review = _record_review(GameState.year_stats, false)
		if tell:
			_note_today = "You missed lantern night, so Mayor Bramble left a note: year %d, \"%s\". It's in the almanac (L)." % [
					old_year, review["title"]]
	else:
		review["stats"] = _closed(GameState.year_stats)
	GameState.year_stats = GameState.fresh_year_stats(GameState.year)


## The morning summary's line about the year review, or nothing.
func news_today() -> Array[String]:
	var news: Array[String] = []
	if _note_today != "":
		news.append(_note_today)
	return news


# --- Words -------------------------------------------------------------------------

static func _kinds(stats: Dictionary, key: String) -> int:
	var kinds: Variant = stats.get(key, [])
	return kinds.size() if typeof(kinds) == TYPE_ARRAY else 0


## "once", "twice", "5 times".
static func _times(count: int) -> String:
	match count:
		1:
			return "once"
		2:
			return "twice"
	return "%s times" % _number(count)


## 12345 -> "12,345".
static func _number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if value < 0 else "") + digits + out


static func _and_list(parts: Array[String], word: String = "and") -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " %s " % word + parts[-1]
