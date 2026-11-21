extends Node
##
## Settings — the player's own choices about how the game sounds and shows:
## music and sound volume, window or full screen, the window's size, and how
## the picture is scaled (DECISIONS 086).
##
## They're not part of a game, so they're not in the save: they live in their
## own small file, user://settings.cfg (next to save.json; on Windows that's
## %APPDATA%\Godot\app_userdata\Pixel Harvest\settings.cfg). Starting a new
## game, or a damaged save, never touches them. It's a ConfigFile, so it can
## be read in Notepad:
##
##   [audio]
##   music=8
##   sounds=10
##   [display]
##   fullscreen=false
##   window_scale=2
##   whole_pixels=false
##   ambience=true
##   toolbar_large=true
##   [game]
##   slot=1
##
## Volumes are steps of 0 to 10 (10 is as loud as the game was before there
## were settings). Each is put on its own bus, "Music" or "SFX", from
## default_bus_layout.tres; the bus's own level there stays the "10", so the
## mix Audio was tuned with is kept.
##
## The settings page (MenuScreen, scripts/menus/) changes them through the
## set_ functions below, which apply the change at once and write the file.
##
## The display settings can't change a window the editor has swallowed: when
## the game runs embedded in the editor's Game tab, they're kept but only
## take effect when the game runs in a window of its own.
##

## The little moving things were turned on or off (Ambience listens).
signal ambience_changed(on: bool)
## The toolbar was made large or small (the hotbar listens; DECISIONS 089).
signal toolbar_changed(large: bool)

const PATH := "user://settings.cfg"

const VOLUME_STEPS := 10
## The window's sizes, as multiples of the 640 × 360 picture.
const WINDOW_SCALES := [1, 2, 3, 4]

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var music_volume: int = VOLUME_STEPS
var sound_volume: int = VOLUME_STEPS
var fullscreen: bool = false
## The window's size as a multiple of the picture: 2 is 1280 × 720, the size
## project.godot opens it at.
var window_scale: int = 2
## True: the picture is only ever scaled by a whole number (×2, ×3), so every
## game pixel is the same size, with a border round it if the screen isn't an
## exact fit. False: it fills the window, and some pixels are a screen pixel
## wider than others.
var whole_pixels: bool = false
## The little moving things on the maps: chimney smoke, lit windows,
## butterflies, birds, leaves, sparkles (Ambience, DECISIONS 088). Only looks.
var ambience: bool = true
## The toolbar at the bottom of the screen drawn at twice its old size
## (DECISIONS 089). False draws it as it was.
var toolbar_large: bool = true
## The saved game played last (1 to 3, SaveSystem.SLOTS), so the game opens
## on it (DECISIONS 090). Not a setting on the page: picking a game on the
## title screen's "Saved games" page changes it.
var slot: int = 1

## Each bus's level in default_bus_layout.tres, i.e. its level at 10.
var _bus_base_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [MUSIC_BUS, SFX_BUS]:
		var index := AudioServer.get_bus_index(bus)
		_bus_base_db[bus] = AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0
	_load()
	_apply_audio()
	_apply_display()


# --- Changing them -------------------------------------------------------------

func set_music_volume(steps: int) -> void:
	music_volume = clampi(steps, 0, VOLUME_STEPS)
	_apply_audio()
	_save()


func set_sound_volume(steps: int) -> void:
	sound_volume = clampi(steps, 0, VOLUME_STEPS)
	_apply_audio()
	_save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_display()
	_save()


func set_window_scale(scale: int) -> void:
	window_scale = scale if WINDOW_SCALES.has(scale) else 2
	_apply_display()
	_save()


func set_whole_pixels(on: bool) -> void:
	whole_pixels = on
	_apply_display()
	_save()


func set_ambience(on: bool) -> void:
	ambience = on
	ambience_changed.emit(on)
	_save()


func set_toolbar_large(on: bool) -> void:
	toolbar_large = on
	toolbar_changed.emit(on)
	_save()


func set_slot(number: int) -> void:
	slot = clampi(number, 1, 3)
	_save()


## The window sizes this screen has room for (always at least ×1).
func window_scales_that_fit() -> Array[int]:
	var room := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var base := _base_size()
	var result: Array[int] = []
	for scale in WINDOW_SCALES:
		if scale == 1 or (base.x * scale <= room.x and base.y * scale <= room.y):
			result.append(scale)
	return result


## False when the window belongs to the editor (the game embedded in its Game
## tab), so the window settings can't be applied now.
func can_change_window() -> bool:
	return not Engine.is_embedded_in_editor() and DisplayServer.get_name() != "headless"


# --- Applying them ----------------------------------------------------------------

func _apply_audio() -> void:
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sound_volume)


## Put `steps` (0 to 10) on a bus. Loudness is heard on a curve, so the steps
## go through linear_to_db: 5 sounds about half as loud, not barely quieter.
## 0 mutes the bus rather than making it very quiet.
func _set_bus(bus: StringName, steps: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, steps <= 0)
	if steps > 0:
		var level := float(steps) / VOLUME_STEPS
		AudioServer.set_bus_volume_db(index, _bus_base_db.get(bus, 0.0) + linear_to_db(level))


func _apply_display() -> void:
	# The scaling applies to the picture inside the window, so it works even
	# embedded in the editor.
	var stretch := (Window.CONTENT_SCALE_STRETCH_INTEGER if whole_pixels
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	if get_tree().root.content_scale_stretch != stretch:
		get_tree().root.content_scale_stretch = stretch
	if not can_change_window():
		return
	var window := get_window()
	if fullscreen:
		if window.mode != Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		return
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	var scale := window_scale
	if not window_scales_that_fit().has(scale):
		scale = window_scales_that_fit().back()
	var size := _base_size() * scale
	if window.size != size:
		window.size = size
		# Keep it in the middle of the screen it's on as it grows or shrinks.
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = screen.position + (screen.size - size) / 2


## The game's picture size, 640 × 360 (project.godot's viewport).
func _base_size() -> Vector2i:
	return Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width", 640),
			ProjectSettings.get_setting("display/window/size/viewport_height", 360))


# --- The file --------------------------------------------------------------------

## Read the file if there is one. A missing file, or a missing or odd value
## in it, keeps the default for that setting.
func _load() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	music_volume = clampi(int(file.get_value("audio", "music", music_volume)), 0, VOLUME_STEPS)
	sound_volume = clampi(int(file.get_value("audio", "sounds", sound_volume)), 0, VOLUME_STEPS)
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))
	var scale := int(file.get_value("display", "window_scale", window_scale))
	window_scale = scale if WINDOW_SCALES.has(scale) else window_scale
	whole_pixels = bool(file.get_value("display", "whole_pixels", whole_pixels))
	ambience = bool(file.get_value("display", "ambience", ambience))
	toolbar_large = bool(file.get_value("display", "toolbar_large", toolbar_large))
	slot = clampi(int(file.get_value("game", "slot", slot)), 1, 3)


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sounds", sound_volume)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "window_scale", window_scale)
	file.set_value("display", "whole_pixels", whole_pixels)
	file.set_value("display", "ambience", ambience)
	file.set_value("display", "toolbar_large", toolbar_large)
	file.set_value("game", "slot", slot)
	var error := file.save(PATH)
	if error != OK:
		push_error("Couldn't write the settings: %s" % error_string(error))
