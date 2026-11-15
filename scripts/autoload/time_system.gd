extends Node
##
## TimeSystem — decides when a day ends, and runs the overnight sequence.
##
## It also runs the clock (DECISIONS 035). Time passes while the game runs,
## 10 minutes at a time, and stops whenever the game is paused (the shop menu
## and the dialogue box pause it) — this node pauses with the rest of the game.
##
## A day ends in one of three ways (DECISIONS 002, 003, 035): the player goes
## to bed in the farmhouse, their energy runs out, or the clock reaches 2 AM.
## Whichever it is, the same thing happens, in a fixed order:
##
##   0. If the player isn't at home (they ran out of energy in the field),
##      they're taken home first, so the night and the morning happen in the
##      farmhouse, beside the bed (DECISIONS 033).
##      If it was the clock, stayed_up_too_late is announced once home.
##   1. day_ended is announced — anything that needs to settle up against
##      *today* does it now. Economy sells the shipping bin here.
##   2. The farm grows: watered crops advance, unwatered ones get thirstier
##      (and may die of it), and the soil dries. Then the night's hazards:
##      crows, aphids, weeds, bare soil going back to grass (DECISIONS 045,
##      048). Then ripe blocks of melons or pumpkins may go giant (DECISIONS
##      048). Then sprinklers water, last, so the morning has wet soil round them.
##   3. The calendar moves on and energy refills.
##   4. If that started a new season: crops that can't grow in it die, and
##      season_changed is announced — the farm repaints itself for the season.
##   4b. Whatever the calendar opens today opens (Brann's forge on day 8,
##      DECISIONS 043), so the morning's summary can say so.
##   4c. Today's weather arrives — last night's forecast — and tomorrow's
##      is chosen (DECISIONS 046). Rain waters every tilled tile now, so the
##      morning is wet and those crops grow tonight; frost kills what can't
##      take the next season. (The day that just ended had its say already:
##      after a heatwave, step 2 made thirsty crops twice as thirsty; after a
##      storm, the crows in step 2 stayed away.)
##   5. day_started is announced — the farm redraws, the HUD updates. Then
##      calendar_event_began for each of today's events (market day).
##   6. The game is saved. Last, so the save is the finished morning: crops
##      grown, energy full. Loading it puts you exactly at the start of a day.
##
## Keeping that order in one place is the point of this file. One consequence
## worth knowing: an out-of-season crop still in the ground on the last night
## of the season dies, even if that night's growth (step 2) would have ripened
## it. Anything ready has to be picked before sleeping on the last day.
##

## Guards against two triggers landing together, e.g. the last point of energy
## spent on the same frame the player presses sleep.
var _ending_day: bool = false

## Real seconds gathered towards the next 10-minute step of the clock.
var _clock_seconds: float = 0.0

## True once the clock has run out tonight, so the morning can say so.
var _out_too_late: bool = false

## The clock's step: it moves in tens, like most farming-game clocks, so the
## HUD doesn't flicker every second.
const CLOCK_STEP_MINUTES := 10

## The dice for the night's hazards (weeds, crows). Its own, rather than the
## global ones, so a test can set its seed and get the same night every time.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Deferred so the action that spent the last energy finishes first —
	# otherwise the crop you just watered would dry out before it was watered.
	EventBus.energy_exhausted.connect(end_day, CONNECT_DEFERRED)


## Runs the clock. Stops while the night is happening, and while paused
## (process_mode is the default, so a paused tree stops this too).
func _process(delta: float) -> void:
	if _ending_day:
		return
	var rules: GameRules = GameState.RULES
	var step_seconds := rules.seconds_per_ten_minutes
	if step_seconds <= 0.0:
		return  # a clock that never moves: set it to 0 in game_rules.tres to try the game without one
	_clock_seconds += delta
	while _clock_seconds >= step_seconds and not _ending_day:
		_clock_seconds -= step_seconds
		GameState.advance_clock(CLOCK_STEP_MINUTES)
		if GameState.minutes >= rules.day_end_minutes:
			_out_too_late = true
			end_day()


func end_day() -> void:
	if _ending_day:
		return
	_ending_day = true
	_clock_seconds = 0.0
	await _go_home()
	if _out_too_late:
		_out_too_late = false
		EventBus.stayed_up_too_late.emit()
	EventBus.day_ended.emit(GameState.day)
	GameState.farm.advance_day(GameState.difficulty.grow_time_multiplier, GameState.thirst_deadline(),
			GameState.thirst_per_dry_night(), GameState.season_id(), GameState.weather_id())
	_run_hazards()
	GameState.farm.form_giants(rng)
	GameState.farm.run_sprinklers()
	var season_turned := GameState.advance_calendar()
	EventBus.energy_changed.emit(GameState.energy, GameState.max_energy)
	if season_turned:
		GameState.farm.wither_out_of_season(GameState.season_id())
		EventBus.season_changed.emit(GameState.season)
	GameState.open_due_unlocks()
	_bring_weather()
	EventBus.day_started.emit(GameState.day, GameState.season, GameState.year)
	for event in GameState.events_today():
		EventBus.calendar_event_began.emit(event.id)
	SaveSystem.save_game()
	_ending_day = false


## Crows, aphids, weeds and soil going back to grass (FarmHazards), each only once
## its unlock has opened, scaled by the difficulty. Part of step 2. After a
## stormy day the crows stay away (DECISIONS 046), and tall crops with no
## fence near may have been flattened (DECISIONS 047).
func _run_hazards() -> void:
	var rules := GameState.RULES.hazards
	if rules == null:
		return
	var today := GameState.weather
	var storm := today != null and today.keeps_crows_away
	FarmHazards.run_night(GameState.farm, rules, GameState.difficulty.hazard_multiplier,
			GameState.season_id(), GameState.has_unlock(rules.weeds_start),
			GameState.has_unlock(rules.crows_start) and not storm, rng,
			today.flattens_tall_crops if today != null else 0.0,
			GameState.has_unlock(rules.pests_start))


## Step 4c: the new day's weather, and what it does to the farm at once.
func _bring_weather() -> void:
	GameState.advance_weather()
	var today := GameState.weather
	if today == null:
		return
	if today.waters_farm:
		GameState.farm.rain()
	if today.kills_tender_crops:
		GameState.farm.frost(GameState.next_season_id())


## True from the moment the night begins until the morning's save. The HUD
## uses it to start black when the player is carried home mid-night.
func is_ending_day() -> bool:
	return _ending_day


## Take the player home (game_rules.tres home_location) if they aren't there,
## and wait until the farmhouse scene is up. Waiting matters: the night's news
## (what the bin sold, crops lost to the season) is collected by the HUD of the
## scene that's open, so the night has to happen in the scene the morning is
## seen in. Going to bed is already at home, so that costs nothing.
func _go_home() -> void:
	var home := GameState.RULES.home_location
	if home == &"" or GameState.location == home:
		return
	LocationManager.go_to(home)
	var home_def := LocationManager.current()
	if home_def == null:
		return
	# A scene change finishes at the end of the frame; give it a few.
	for _frame in 10:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == home_def.scene_path and scene.is_node_ready():
			return
	push_warning("TimeSystem: went home to '%s' but its scene didn't open" % home)
