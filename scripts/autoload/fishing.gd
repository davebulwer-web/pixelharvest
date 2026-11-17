extends Node
##
## Fishing — a cast, a wait, a bite and the reel (DECISIONS 054).
##
## The rod is a tool like any other (FishAction, rule 5): facing water with it,
## Space announces EventBus line_cast, and the rod knows nothing more. This
## service takes it from there, wherever the player is (the farm's pond, the
## town's pond and river, the Woods' stream):
##
##   WAITING   the float sits on the water. A few seconds (sooner with bait)
##             and something bites. Space too soon reels in empty.
##   BITING    the float goes under and a "!" shows: Space within the
##             strike time hooks it (fish_hooked). Too slow, it's gone.
##   REELING   the reel bar over the farmer's head: a marker swings end to
##             end across a green zone. Space with the marker in the green is
##             a good pull; outside it, the line goes slack. Enough good
##             pulls land the fish (GameState.catch_fish, fish_caught); too
##             many slack ones and it gets away (fish_escaped).
## E gives up at any point and reels in.
##
## Winter (DECISIONS 055): every water is ice. Space with the rod on bare ice
## cuts a hole there (ice_hole_cut) instead of casting; Space at a hole casts
## through it, and the wait is longer (the rules' ice_wait_multiplier). The
## holes are kept here, by location, and drawn as IceHole pictures in
## whichever map is showing. The night freezes them all over, so they're
## never saved.
##
## What shortens the wait, in order: the rod's tier (Wren's fine rod), then a
## lure that works today (kept, never used up), or else bait (used up).
##
## The sea (DECISIONS 065), off the Cove's pier, quay and breakwater, is
## fished with Tam's handline (or the rod). It never freezes, and its tide
## sets the wait: fish bite sooner with the tide in, slower with it out
## (FishingRules.tide_wait_multiplier), and a few (the bass) only come in
## with the tide.
##
## Which fish bites is decided when it bites: one of the FishDefs biting in
## that water, in that place, this season, at this hour, in today's weather,
## chosen by weight. Its fight (1 to 5) sets the bar: data/fishing_rules.tres
## says how fast, how wide and how many pulls for each step.
##
## While a line is out the farmer stands still: the Player asks is_busy() and
## leaves the keys to this service. The clock keeps running, so fishing costs
## time, as foraging does. Nothing here is saved: the game saves overnight,
## and a line is never out overnight (going to bed, or anywhere else, reels
## it in).
##
## The float, the line and the reel bar are drawn by a FishingLine node put
## in the current scene for as long as the line is out.
##

enum State { IDLE, WAITING, BITING, REELING }

var _state: State = State.IDLE

## Counts down the wait, the strike, or the hooked fish's patience.
var _timer: float = 0.0

## Where the line is: the water cell, its kind (&"pond", &"river", &"stream")
## and the location's id.
var _cell: Vector2i
var _water: StringName = &""
var _location: StringName = &""

## The fish on the line (from the bite on) and how big it is (from the hook).
var _fish: FishDef
var _size: int = 0

## The reel bar: the marker's place along the bar (0 to 1) and which way it's
## going, the green zone's start and width (fractions of the bar), seconds for
## one crossing, and good and slack pulls so far.
var _marker: float = 0.0
var _direction: float = 1.0
var _zone_start: float = 0.0
var _zone_width: float = 0.3
var _sweep_seconds: float = 1.2
var _pulls: int = 0
var _pulls_needed: int = 1
var _slack: int = 0

## The frame the line went out on: the key press that cast it reaches this
## service too, and mustn't count as striking.
var _cast_frame: int = -1

## True if this line went down through a hole in the ice.
var _through_ice: bool = false

var _line: FishingLine
var _dice := RandomNumberGenerator.new()

## The holes in the ice: location id -> the cells cut today.
var _holes: Dictionary = {}

## The map the holes were last drawn in, and the pictures drawn there, so a
## new map (going through a gate, waking up) gets its own.
var _holes_scene: Node
var _hole_sprites: Array[Node] = []

const ICE_HOLE: Texture2D = preload("res://assets/sprites/fishing/ice_hole.png")

## On the ground's own level (-1, as the town's bridge is), added after the
## ground so it draws over it, and under the farmer and everything standing.
const ICE_HOLE_Z := -1


func _ready() -> void:
	_dice.randomize()
	EventBus.line_cast.connect(_on_line_cast)
	# Anything that takes the farmer away reels the line in, quietly.
	EventBus.location_changed.connect(func(_id: StringName) -> void: _stop(""))
	EventBus.day_ended.connect(func(_d: int) -> void: _stop(""))
	EventBus.new_game_started.connect(func() -> void: _stop(""))
	EventBus.game_loaded.connect(func() -> void: _stop(""))
	# The night freezes every hole over; a different game has none.
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: clear_holes())
	EventBus.new_game_started.connect(clear_holes)
	EventBus.game_loaded.connect(clear_holes)


## True while a line is out: the player stands still and leaves Space and E
## to this service.
func is_busy() -> bool:
	return _state != State.IDLE


## What's happening, for tests and the line's drawing: &"idle", &"waiting",
## &"biting" or &"reeling".
func state_name() -> StringName:
	return [&"idle", &"waiting", &"biting", &"reeling"][_state]


## The fish on the line, or null before a bite.
func fish_on_line() -> FishDef:
	return _fish


## True if every water is frozen in `season_id` (winter): the rod cuts a
## hole before it can cast. Except the sea: see is_frozen_water().
func is_frozen(season_id: StringName) -> bool:
	var rules: FishingRules = GameState.RULES.fishing
	return rules != null and season_id in rules.frozen_seasons


## True if `water` is frozen in `season_id`: fresh water in winter, never
## the sea (DECISIONS 065).
func is_frozen_water(season_id: StringName, water: StringName) -> bool:
	var rules: FishingRules = GameState.RULES.fishing
	return is_frozen(season_id) and not rules.is_sea(water)


## True if a hole has been cut in the ice at `cell` in `location_id` today.
func has_hole(location_id: StringName, cell: Vector2i) -> bool:
	return cell in _holes.get(location_id, [])


## The cells with holes cut today in `location_id`.
func holes_in(location_id: StringName) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_holes.get(location_id, []))
	return cells


## Freeze every hole over (each night, and for a different game).
func clear_holes() -> void:
	_holes.clear()
	_remove_hole_sprites()


## How long the float waits as things stand, as a multiple of the rules'
## wait, and what's on the hook: the rod's tier (only when it's the rod
## being cast, not Tam's handline), the ice, the tide (in the sea), then a
## lure that works in today's season or else bait. Doesn't use anything up:
## see _bait_up().
func wait_factor(through_ice: bool, water: StringName = &"") -> float:
	var rules: FishingRules = GameState.RULES.fishing
	var multiplier := 1.0
	var held := GameState.selected_tool()
	if held != null and held.id == rules.rod_tool:
		multiplier *= rules.rod_wait_multiplier(_rod_tier())
	if through_ice:
		multiplier *= rules.ice_wait_multiplier
	multiplier *= rules.tide_wait_multiplier(water, tide_in(water))
	var lure := lure_today()
	if lure != null:
		multiplier *= lure.wait_multiplier
	elif _bait_in_bag() != null:
		multiplier *= rules.bait_wait_multiplier
	return multiplier


## A lure in the bag that works today, or null.
func lure_today() -> LureDef:
	var rules: FishingRules = GameState.RULES.fishing
	for lure in rules.lures:
		if lure != null and GameState.inventory.count(lure) > 0 and lure.works_in(GameState.season_id()):
			return lure
	return null


func _bait_in_bag() -> ItemDef:
	var rules: FishingRules = GameState.RULES.fishing
	for bait in rules.bait:
		if bait != null and GameState.inventory.count(bait) > 0:
			return bait
	return null


## The tier of the rod the player owns (1 once Wren gives the fine rod).
func _rod_tier() -> int:
	var rules: FishingRules = GameState.RULES.fishing
	var rod := ContentDB.item(rules.rod_tool) as ToolDef
	return GameState.tool_tier(rod) if rod != null else 0


## The fish that would bite in `water` at `location_id` right now: today's
## season, the clock's time, today's weather and, in the sea, the tide. In
## ContentDB's order.
func biting_now(water: StringName, location_id: StringName) -> Array[FishDef]:
	var weather_id: StringName = GameState.weather.id if GameState.weather != null else &""
	return ContentDB.fish_biting(water, location_id, GameState.season_id(), GameState.minutes, weather_id,
			tide_in(water))


## True if the tide is in, for `water`: the sea's is worked out from the
## clock (Tides, DECISIONS 064); every other water counts as "in".
func tide_in(water: StringName) -> bool:
	var rules: FishingRules = GameState.RULES.fishing
	if not rules.is_sea(water):
		return true
	return not Tides.is_out()


# --- Casting ---------------------------------------------------------------------

func _on_line_cast(cell: Vector2i, water: StringName, wait_multiplier: float) -> void:
	if is_busy():
		return
	var rules: FishingRules = GameState.RULES.fishing
	var location := GameState.location
	var through_ice := is_frozen_water(GameState.season_id(), water)
	if through_ice:
		cell = _ice_cell(cell)
	# On bare ice the rod's Space cuts a hole instead (the energy is the
	# cast's). The next Space there casts through it.
	if through_ice and not has_hole(location, cell):
		_cut_hole(location, cell)
		return
	_cell = cell
	_water = water
	_location = location
	_through_ice = through_ice
	_fish = null
	_size = 0
	_cast_frame = Engine.get_process_frames()
	var wait := _dice.randf_range(rules.wait_min_seconds, rules.wait_max_seconds) * wait_multiplier \
			* wait_factor(through_ice, water)
	_bait_up()
	_timer = wait
	_state = State.WAITING
	_line = FishingLine.new()
	_line.name = "FishingLine"
	_line.setup(_find_player(), cell, through_ice)
	var scene := get_tree().current_scene
	if scene != null:
		scene.add_child(_line)


## Where on the ice the hole goes for a cast at `cell`. Facing down, left or
## right, that's the tile ahead. Facing up, the tile ahead is hidden behind
## the farmer's head and hat (open water has the float land further out for
## the same reason), so the hole goes one tile further, if that's ice too.
func _ice_cell(cell: Vector2i) -> Vector2i:
	var player := _find_player()
	if player == null or player.position.y <= (cell.y + 1) * FishingLine.TILE_PX:
		return cell
	var further := cell + Vector2i.UP
	return further if _is_water(further) else cell


## True if `cell` in the map showing is water (ice, in winter): the farm's
## pond, or wherever the map's water_at says.
func _is_water(cell: Vector2i) -> bool:
	if GameState.location == LocationManager.FARM_ID:
		var tile := GameState.farm.tile(cell)
		return tile != null and tile.terrain == FarmTile.Terrain.WATER
	var scene := get_tree().current_scene
	return scene != null and scene.has_method(&"water_at") and scene.water_at(cell) != &""


## What goes on the hook for this cast: a lure that works today is tied on
## and kept; otherwise bait, if there's any in the bag, is used up.
func _bait_up() -> void:
	var lure := lure_today()
	if lure != null:
		return
	var bait := _bait_in_bag()
	if bait == null:
		return
	GameState.inventory.remove(bait, 1)
	var left := GameState.inventory.count(bait)
	EventBus.message_posted.emit("Baited the hook (%d %s left)" % [left, QuestGoal.plural(bait.display_name, left)])


## Cut a hole in the ice at `cell`, and draw it if that's here.
func _cut_hole(location: StringName, cell: Vector2i) -> void:
	var cells: Array = _holes.get(location, [])
	cells.append(cell)
	_holes[location] = cells
	if _holes_scene != null and is_instance_valid(_holes_scene) and _holes_scene == get_tree().current_scene:
		_add_hole_sprite(cell)
	EventBus.ice_hole_cut.emit(location, cell)
	EventBus.message_posted.emit("You cut a hole in the ice. Space again to fish through it.")


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


# --- Each frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	# A different map is showing (a gate, a door, the morning): draw its holes.
	var scene := get_tree().current_scene
	if scene != _holes_scene:
		_draw_holes(scene)
	match _state:
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_bite()
		State.BITING:
			_timer -= delta
			if _timer <= 0.0:
				_escape("It got away. Strike with Space as soon as the float goes under.")
		State.REELING:
			_marker += _direction * delta / _sweep_seconds
			if _marker >= 1.0:
				_marker = 2.0 - _marker
				_direction = -1.0
			elif _marker <= 0.0:
				_marker = -_marker
				_direction = 1.0
			_timer -= delta
			if _timer <= 0.0:
				_escape("It slipped the hook while the line hung loose.")
				return
			_show_bar()


## Something bites: one of the fish biting here and now, by weight.
func _bite() -> void:
	var fish := biting_now(_water, _location)
	if fish.is_empty():
		_stop("Not a nibble. Try another time of day, or other water.")
		return
	var total := 0
	for each in fish:
		total += each.weight
	var roll := _dice.randi_range(1, total)
	_fish = fish[-1]
	for each in fish:
		roll -= each.weight
		if roll <= 0:
			_fish = each
			break
	var rules: FishingRules = GameState.RULES.fishing
	_timer = rules.strike_seconds
	_state = State.BITING
	if _line != null:
		_line.set_biting(true)
	EventBus.fish_bit.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.IDLE or Engine.get_process_frames() == _cast_frame:
		return
	if event.is_action_pressed(&"use_tool"):
		get_viewport().set_input_as_handled()
		match _state:
			State.WAITING:
				_stop("Reeled in too soon. Wait for the float to go under.")
			State.BITING:
				_hook()
			State.REELING:
				_pull()
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_stop("Reeled in.")


## Struck in time: the fish is on, and its size is settled.
func _hook() -> void:
	var rules: FishingRules = GameState.RULES.fishing
	# Two dice averaged: most fish are middling, the record ones are rare.
	var middle := (_dice.randf() + _dice.randf()) / 2.0
	_size = roundi(lerpf(_fish.min_size, _fish.max_size, middle))
	_sweep_seconds = maxf(0.2, float(FishingRules.for_fight(rules.sweep_seconds, _fish.fight)))
	_zone_width = clampf(float(FishingRules.for_fight(rules.zone_widths, _fish.fight)), 0.05, 1.0)
	_pulls_needed = maxi(1, int(FishingRules.for_fight(rules.pulls_needed, _fish.fight)))
	_pulls = 0
	_slack = 0
	_marker = 0.0
	_direction = 1.0
	_move_zone()
	_timer = rules.reel_patience_seconds
	_state = State.REELING
	if _line != null:
		_line.set_biting(false)
	EventBus.fish_hooked.emit(_fish.id)
	EventBus.message_posted.emit("Hooked one! Space when the marker's in the green")
	_show_bar()


## Space while reeling: a good pull in the green, slack outside it.
func _pull() -> void:
	var rules: FishingRules = GameState.RULES.fishing
	_timer = rules.reel_patience_seconds
	if _marker >= _zone_start and _marker <= _zone_start + _zone_width:
		_pulls += 1
		if _pulls >= _pulls_needed:
			_land()
			return
		_move_zone()
	else:
		_slack += 1
		if _slack > rules.slack_allowed:
			_escape("The line went slack and it got away.")
			return
		EventBus.message_posted.emit("Slack! (%d more and it's gone)" % (rules.slack_allowed - _slack + 1))
	_show_bar()


## A new place for the green zone, away from where the marker is now, so each
## pull is a fresh bit of timing.
func _move_zone() -> void:
	var room := 1.0 - _zone_width
	var start := _dice.randf_range(0.0, room)
	if absf(start + _zone_width / 2.0 - _marker) < _zone_width:
		start = fposmod(start + 0.5, room) if room > 0.0 else 0.0
	_zone_start = clampf(start, 0.0, room)


func _show_bar() -> void:
	if _line != null:
		_line.set_bar(_marker, _zone_start, _zone_width, _pulls, _pulls_needed, _slack)


func _land() -> void:
	var fish := _fish
	var size := _size
	var water := _water
	var location := _location
	var through_ice := _through_ice
	_stop("")
	GameState.catch_fish(fish, size, location, water, through_ice)


func _escape(message: String) -> void:
	var fish_id: StringName = _fish.id if _fish != null else &""
	_stop(message)
	EventBus.fish_escaped.emit(fish_id)


## Reel in: the line, the float and the bar go, and the farmer can move.
func _stop(message: String) -> void:
	if _state == State.IDLE:
		return
	_state = State.IDLE
	_fish = null
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
	if message != "":
		EventBus.message_posted.emit(message)


# --- The holes' pictures --------------------------------------------------------

## Draw the holes cut today in `scene`'s location. Each is a picture in the
## middle of its tile, just above the ground and under everything standing.
func _draw_holes(scene: Node) -> void:
	_remove_hole_sprites()
	_holes_scene = scene
	if scene == null:
		return
	for cell in holes_in(GameState.location):
		_add_hole_sprite(cell)


func _add_hole_sprite(cell: Vector2i) -> void:
	if _holes_scene == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "IceHole"
	sprite.texture = ICE_HOLE
	sprite.position = Vector2(cell * FishingLine.TILE_PX) + Vector2.ONE * FishingLine.TILE_PX / 2.0
	sprite.z_index = ICE_HOLE_Z
	_holes_scene.add_child(sprite, true)  # true: "IceHole2", not "@Sprite2D@5"
	_hole_sprites.append(sprite)


func _remove_hole_sprites() -> void:
	for sprite in _hole_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_hole_sprites.clear()
