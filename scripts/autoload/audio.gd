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
## What each sound is lives in data/audio/sound_bank.tres (SoundBank). Which
## tune plays where lives on each LocationDef (its `music`). The weather's
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


## The tune for a location: its own, or its outside's (a shop plays the
## town's tune). Null for silence.
func music_for(location_id: StringName) -> AudioStream:
	for location in LocationManager.all():
		if location.id != location_id:
			continue
		if location.music != null:
			return location.music
		if location.outside != &"":
			return music_for(location.outside)
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
	EventBus.foraged.connect(func(_id: StringName, _where: StringName) -> void: play(&"harvest"))
	EventBus.wood_chopped.connect(func(_where: StringName, _c: Vector2i, _what: StringName, _id: StringName, _n: int) -> void: play(&"chop"))
	# Fishing (DECISIONS 054): the float lands, the bite, the fish landed.
	EventBus.line_cast.connect(func(_c: Vector2i, _water: StringName, _m: float) -> void: play(&"cast"))
	EventBus.fish_bit.connect(func() -> void: play(&"bite"))
	EventBus.fish_caught.connect(func(_id: StringName, _size: int, _where: StringName, _water: StringName, _ice: bool) -> void: play(&"splash"))
	# Cutting a hole in the ice (DECISIONS 055) sounds like a blow of the axe.
	EventBus.ice_hole_cut.connect(func(_where: StringName, _cell: Vector2i) -> void: play(&"chop"))
	EventBus.fish_escaped.connect(func(_id: StringName) -> void: play(&"nope"))
	EventBus.object_placed.connect(func(_c: Vector2i, _id: StringName) -> void: _farm_sound(&"place"))
	EventBus.object_removed.connect(func(_c: Vector2i, _id: StringName) -> void: _farm_sound(&"pick_up"))
	EventBus.items_shipped.connect(func(count: int, _v: int) -> void: play(&"ship" if count > 0 else &"nope"))
	EventBus.item_bought.connect(func(_id: StringName, _n: int, _g: int) -> void: play(&"coins"))
	EventBus.upgrade_bought.connect(func(_id: StringName, _g: int) -> void: play(&"coins"))
	EventBus.items_sold_to_shop.connect(func(_id: StringName, _n: int, _g: int) -> void: play(&"coins"))
	EventBus.npc_talked_to.connect(func(_id: StringName) -> void: play(&"talk"))
	EventBus.notice_board_read.connect(func() -> void: play(&"paper"))
	EventBus.quest_started.connect(func(_id: StringName) -> void: play(&"chime"))
	EventBus.quest_progressed.connect(func(_id: StringName, _p: int, _n: int) -> void: play(&"chime"))
	EventBus.quest_completed.connect(func(_id: StringName) -> void: play(&"quest_done"))
	EventBus.tool_selected.connect(func(_id: StringName) -> void: play(&"tick"))
	EventBus.energy_exhausted.connect(func() -> void: play(&"collapse"))
	EventBus.day_ended.connect(func(_d: int) -> void: play(&"sleep"))
	EventBus.day_started.connect(func(_d: int, _s: int, _y: int) -> void: play(&"morning"))
	EventBus.location_changed.connect(_on_location_changed)
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
	_play_music(music_for(location_id))
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


## Fade to `stream`. The same tune already playing carries on where it is,
## so going into a shop and out again doesn't restart the town's tune.
func _play_music(stream: AudioStream) -> void:
	if stream != null and _music_now.playing and _music_now.stream == stream:
		return
	var old := _music_now
	_music_now = _music_b if old == _music_a else _music_a
	if old.playing:
		_fade(old, -40.0, true)
	if stream == null:
		_music_now.stop()
		return
	_music_now.stream = stream
	_music_now.volume_db = -40.0
	_music_now.play()
	_fade(_music_now, 0.0, false)


## Fade one music player to `volume_db`, stopping it at the end if asked.
## A player already fading has that fade cancelled first.
func _fade(player: AudioStreamPlayer, volume_db: float, then_stop: bool) -> void:
	var running: Tween = _music_tweens.get(player)
	if running != null:
		running.kill()
	var tween := create_tween()
	tween.tween_property(player, ^"volume_db", volume_db, MUSIC_FADE_SECONDS)
	if then_stop:
		tween.tween_callback(player.stop)
	_music_tweens[player] = tween
