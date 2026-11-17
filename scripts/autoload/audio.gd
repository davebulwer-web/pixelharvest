extends Node
##
## Audio — plays the game's sounds and music (DECISIONS 042).
##
## Nothing in the game asks for a sound when something happens. This listens
## on EventBus, like the HUD, and plays the sound that goes with each event:
## a tile tilled, something bought, a request handed in. So a new feature
## gets its sound here by subscribing, and the farming code never knows
## sound exists. (Screens that aren't game events, like closing the day's
## summary, call play() directly.)
##
## What each sound is lives in data/audio/sound_bank.tres (SoundBank). The
## music is the season's (SeasonTheme.music, DECISIONS 066): its tunes play
## one after another wherever you go, so walking from the farm to the Cove
## doesn't change the tune, but the turn of the season does. A place can
## still have a tune of its own instead (LocationDef.music). The weather's
## loop (rain on the leaves) is on its WeatherDef (`ambience`, DECISIONS
## 046): it plays all day, and quieter indoors.
##
## Two buses, set up in default_bus_layout.tres: "Music" and "SFX", so the
## settings screen (Stage 9 session 2) can give each its own volume. Until
## then, M mutes and unmutes everything.
##
## This node keeps running while the game is paused, because the shop menu
## and the day's summary pause the game and should still make sounds.
##

const BANK: SoundBank = preload("res://data/audio/sound_bank.tres")

## How long one tune takes to fade into the next, in seconds.
const MUSIC_FADE_SECONDS := 0.8

## When one of the season's tunes is nearly over, the next starts this many
## seconds before its end and the two cross-fade, so there's no gap and no
## hard stop (Dave's tunes end at full volume).
const TRACK_CROSSFADE_SECONDS := 3.0

## How many copies of one sound can overlap. Watering three tiles in a row
## quickly overlaps; more than this and the oldest is cut off.
const VOICES_PER_SOUND := 3

## How long the audio gets to stop before the game closes. Too short to notice.
const QUIT_DELAY_SECONDS := 0.15

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"

## Sound name -> its player.
var _players: Dictionary = {}

## Sound name -> the frame it last played on. An upgraded watering can waters
## nine tiles in one swing: that's one splash, not nine on top of each other.
var _last_frame: Dictionary = {}

## Two music players, so one can fade out while the other fades in.
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_now: AudioStreamPlayer
## Music player -> the fade running on it.
var _music_tweens: Dictionary = {}

## The tunes that take turns here and now (the season's, or a place's own
## one), how loud they play, and the last one started, so the next pick
## isn't the same again.
var _playlist: Array[AudioStream] = []
var _music_volume_db: float = 0.0
var _last_track: AudioStream

## The first scene of a session is opened by the boot, not by a door, so it
## doesn't get a door sound.
var _first_location: bool = true

## The weather's loop (DECISIONS 046), and how much quieter it is indoors,
## where the rain is on the roof rather than all around.
var _ambience: AudioStreamPlayer
const INDOORS_DB := -14.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The window's close button comes here first (see _notification).
	get_tree().auto_accept_quit = false
	for sound_name: StringName in BANK.sounds:
		var player := AudioStreamPlayer.new()
		player.stream = BANK.sounds[sound_name]
		player.bus = SFX_BUS
		player.max_polyphony = VOICES_PER_SOUND
		add_child(player)
		_players[sound_name] = player
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_now = _music_a
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = SFX_BUS
	add_child(_ambience)
	_listen()


## Closing the window: stop every sound, give the audio a moment to let go
## of them, then quit. Quitting with a sound still playing makes Godot report
## it as "leaked" in the output panel, which is harmless but looks like a bug.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for player: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", false, false):
			player.stop()
		await get_tree().create_timer(QUIT_DELAY_SECONDS, true, false, true).timeout
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		get_viewport().set_input_as_handled()
		var master := AudioServer.get_bus_index(&"Master")
		var muted := not AudioServer.is_bus_mute(master)
		AudioServer.set_bus_mute(master, muted)
		EventBus.message_posted.emit("Sound off — M to turn it back on" if muted else "Sound on")


## Play the sound called `sound_name` from the sound bank, once. A name the
## bank doesn't have is silent. Asking twice in one frame plays it once.
func play(sound_name: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(sound_name)
	if player == null:
		return
	var frame := Engine.get_process_frames()
	if _last_frame.get(sound_name, -1) == frame:
		return
	_last_frame[sound_name] = frame
	var spread := BANK.pitch_variation
	player.pitch_scale = randf_range(1.0 - spread, 1.0 + spread)
	player.play()


## The tunes for a location: its own one if it has one (or its outside's: a
## shop plays the town's), otherwise the season's (DECISIONS 066). Empty for
## silence.
func music_for(location_id: StringName) -> Array[AudioStream]:
	var own := _own_music(location_id)
	if own != null:
		return [own]
	var tunes: Array[AudioStream] = []
	var theme := GameState.current_season_theme()
	if theme != null:
		for tune: AudioStream in theme.music:
			if tune != null:
				tunes.append(tune)
	return tunes


## A location's own tune, or its outside's, or null if neither has one.
func _own_music(location_id: StringName) -> AudioStream:
	for location in LocationManager.all():
		if location.id != location_id:
			continue
		if location.music != null:
			return location.music
		if location.outside != &"":
			return _own_music(location.outside)
		return null
	return null


## The tune playing now (or fading in), or null.
func current_music() -> AudioStream:
	return _music_now.stream if _music_now.playing else null


# --- Which event makes which sound -----------------------------------------
# The whole list in one place. Farm sounds are skipped at night: overnight,
# sprinklers water and crops change, and nobody's there to hear it.

func _listen() -> void:
	EventBus.tile_tilled.connect(func(_c: Vector2i) -> void: _farm_sound(&"till"))
	EventBus.tile_watered.connect(func(_c: Vector2i) -> void: _farm_sound(&"water"))
	EventBus.crop_planted.connect(func(_c: Vector2i, _id: StringName) -> void: _farm_sound(&"plant"))
	EventBus.crop_harvested.connect(func(_c: Vector2i, _id: StringName, _n: int) -> void: _farm_sound(&"harvest"))
	EventBus.weeds_pulled.connect(func(_c: Vector2i) -> void: _farm_sound(&"pick_up"))
	# Fertiliser going into the soil (DECISIONS 058) sounds like sowing.
	EventBus.soil_fed.connect(func(_c: Vector2i, id: StringName) -> void:
		if id != &"":
			_farm_sound(&"plant"))
	EventBus.foraged.connect(func(_id: StringName, _where: StringName) -> void: play(&"harvest"))
	EventBus.wood_chopped.connect(func(_where: StringName, _c: Vector2i, _what: StringName, _id: StringName, _n: int) -> void: play(&"chop"))
	# Fishing (DECISIONS 054): the float lands, the bite, the fish landed.
	EventBus.line_cast.connect(func(_c: Vector2i, _water: StringName, _m: float) -> void: play(&"cast"))
	EventBus.fish_bit.connect(func() -> void: play(&"bite"))
	EventBus.fish_caught.connect(func(_id: StringName, _size: int, _where: StringName, _water: StringName, _ice: bool) -> void: play(&"splash"))
	# Cutting a hole in the ice (DECISIONS 055) sounds like a blow of the axe.
	EventBus.ice_hole_cut.connect(func(_where: StringName, _cell: Vector2i) -> void: play(&"chop"))
	EventBus.fish_escaped.connect(func(_id: StringName) -> void: play(&"nope"))
	# Cooking (DECISIONS 056): the pan at the stove, and a dish eaten.
	EventBus.dish_cooked.connect(func(_r: StringName, _d: StringName) -> void: play(&"sizzle"))
	EventBus.item_made.connect(func(_r: StringName, _i: StringName, _n: int) -> void: play(&"chop"))
	EventBus.dish_eaten.connect(func(_d: StringName, _e: float) -> void: play(&"eat"))
	EventBus.object_placed.connect(func(_c: Vector2i, _id: StringName) -> void: _farm_sound(&"place"))
	EventBus.object_removed.connect(func(_c: Vector2i, _id: StringName) -> void: _farm_sound(&"pick_up"))
	EventBus.object_emptied.connect(func(_c: Vector2i, _o: StringName, _i: StringName, _n: int) -> void: _farm_sound(&"harvest"))
	EventBus.items_shipped.connect(func(count: int, _v: int) -> void: play(&"ship" if count > 0 else &"nope"))
	EventBus.item_bought.connect(func(_id: StringName, _n: int, _g: int) -> void: play(&"coins"))
	EventBus.upgrade_bought.connect(func(_id: StringName, _g: int) -> void: play(&"coins"))
	EventBus.items_sold_to_shop.connect(func(_id: StringName, _n: int, _g: int) -> void: play(&"coins"))
	EventBus.npc_talked_to.connect(func(_id: StringName) -> void: play(&"talk"))
	EventBus.notice_board_read.connect(func() -> void: play(&"paper"))
	EventBus.quest_started.connect(func(_id: StringName) -> void: play(&"chime"))
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: play(&"chime"))
	EventBus.quest_completed.connect(func(_id: StringName) -> void: play(&"quest_done"))
	# Festivals (DECISIONS 059): entering chimes; a place at the judging
	# sounds like a request done, nothing to show like a fish lost.
	EventBus.festival_entered.connect(func(_e: StringName, _w: String) -> void: play(&"chime"))
	EventBus.festival_judged.connect(func(_e: StringName, place: int, _w: String) -> void:
		play(&"quest_done" if place > 0 else &"nope"))
	EventBus.festival_gift_given.connect(func(_e: StringName) -> void: play(&"quest_done"))
	EventBus.tool_selected.connect(func(_id: StringName) -> void: play(&"tick"))
	EventBus.energy_exhausted.connect(func() -> void: play(&"collapse"))
	EventBus.day_ended.connect(func(_d: int) -> void: play(&"sleep"))
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: play(&"morning"))
	EventBus.location_changed.connect(_on_location_changed)
	# The season's turn changes the tunes (DECISIONS 066).
	EventBus.season_changed.connect(func(_s: int) -> void: _update_music(GameState.location))
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _update_ambience())
	EventBus.thunder_rolled.connect(func() -> void: play(&"thunder"))


func _farm_sound(sound_name: StringName) -> void:
	if TimeSystem.is_ending_day():
		return
	play(sound_name)


func _on_location_changed(location_id: StringName) -> void:
	if _first_location:
		_first_location = false
	elif not TimeSystem.is_ending_day():
		play(&"door")
	_update_music(location_id)
	_update_ambience()


# --- The weather's loop (DECISIONS 046) ----------------------------------------

## Start, stop or re-level the weather's loop for today's weather and where
## the player is. The same loop carries on through a door, only quieter.
func _update_ambience() -> void:
	var weather := GameState.weather
	if weather == null or weather.ambience == null:
		_ambience.stop()
		return
	if _ambience.stream != weather.ambience:
		_ambience.stream = weather.ambience
		_ambience.stop()
	_ambience.volume_db = weather.ambience_volume_db + (0.0 if _is_outdoors(GameState.location) else INDOORS_DB)
	if not _ambience.playing:
		_ambience.play()


## True for a place with no `outside` (the farm, the town), false for a
## room inside one (the farmhouse, a shop).
func _is_outdoors(location_id: StringName) -> bool:
	for location in LocationManager.all():
		if location.id == location_id:
			return location.outside == &""
	return true


# --- Music -------------------------------------------------------------------

func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	add_child(player)
	return player


## Work out the tunes for `location_id` and play them. If the tune already
## playing is one of them it carries on where it is, so going through a door,
## or from the farm down the Lane to the town, never restarts the music.
func _update_music(location_id: StringName) -> void:
	var tunes := music_for(location_id)
	var volume := 0.0
	if _own_music(location_id) == null and GameState.current_season_theme() != null:
		volume = GameState.current_season_theme().music_volume_db
	_playlist = tunes
	if tunes.is_empty():
		_play_music(null)
		return
	if _music_now.playing and tunes.has(_music_now.stream):
		if not is_equal_approx(volume, _music_volume_db):
			_music_volume_db = volume
			_fade(_music_now, volume, false)
		return
	_music_volume_db = volume
	_play_music(_next_track())


## The next tune to play: any one of the list but the one that played last,
## so it never plays the same tune twice running (unless it only has one).
func _next_track() -> AudioStream:
	var choices: Array[AudioStream] = []
	for tune in _playlist:
		if tune != _last_track:
			choices.append(tune)
	if choices.is_empty():
		return _playlist[0] if not _playlist.is_empty() else null
	return choices.pick_random()


## A tune that loops by itself (a place's own .ogg, imported with loop on)
## never ends, so it never needs the next one queued.
func _loops(stream: AudioStream) -> bool:
	return stream != null and stream.get(&"loop") == true


## Near the end of one of the season's tunes, cross-fade into the next.
func _process(_delta: float) -> void:
	if _playlist.is_empty() or not _music_now.playing or _loops(_music_now.stream):
		return
	var length := _music_now.stream.get_length()
	if length <= 0.0:
		return
	if _music_now.get_playback_position() >= length - TRACK_CROSSFADE_SECONDS:
		_play_music(_next_track(), true, TRACK_CROSSFADE_SECONDS)


## Fade to `stream`. The same tune already playing carries on where it is,
## unless `restart` (a tune following itself, when the list has only one).
func _play_music(stream: AudioStream, restart: bool = false,
		fade_seconds: float = MUSIC_FADE_SECONDS) -> void:
	if stream != null and not restart and _music_now.playing and _music_now.stream == stream:
		return
	var old := _music_now
	_music_now = _music_b if old == _music_a else _music_a
	if old.playing:
		_fade(old, -40.0, true, fade_seconds)
	if stream == null:
		_music_now.stop()
		return
	_last_track = stream
	_music_now.stream = stream
	_music_now.volume_db = -40.0
	_music_now.play()
	_fade(_music_now, _music_volume_db, false, fade_seconds)


## Fade one music player to `volume_db`, stopping it at the end if asked.
## A player already fading has that fade cancelled first.
func _fade(player: AudioStreamPlayer, volume_db: float, then_stop: bool,
		seconds: float = MUSIC_FADE_SECONDS) -> void:
	var running: Tween = _music_tweens.get(player)
	if running != null:
		running.kill()
	var tween := create_tween()
	tween.tween_property(player, ^"volume_db", volume_db, seconds)
	if then_stop:
		tween.tween_callback(player.stop)
	_music_tweens[player] = tween
