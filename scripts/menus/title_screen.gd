class_name TitleScreen
extends MenuScreen
##
## TitleScreen — what the game opens on (DECISIONS 086): its name over the
## farm, and Continue, New game, Settings, Controls and Quit.
##
## The boot scene has already loaded the save (or set up a fresh game if
## there isn't one) and opened the place the farmer is in, so the title sits
## over the real world, paused and dimmed, with the season's music playing.
## Continue just takes the title away. New game asks the difficulty
## (DifficultyMenu, as Ctrl+N does) and starts again; the save file isn't
## touched until the new game's first night, as before (DECISIONS 040).
##

## The save couldn't be read (SaveSystem set it aside), so say so.
var save_was_unreadable: bool = false

## True when there's a saved game to continue.
var _has_game: bool = false
## True while the difficulty menu is open over the title.
var _asking_difficulty: bool = false


func _init() -> void:
	dim = 0.35  # the farm shows through: it's the title's picture


## The game's own screen layers (the HUD and hotbar at 2, boxes above it)
## hidden while the title is up, so it shows the world and not the clock;
## given back on close. The weather (rain at 1) is part of the world, so stays.
const HIDE_FROM_LAYER := 2
var _hidden: Array[CanvasLayer] = []


func _ready() -> void:
	_has_game = SaveSystem.has_save()
	super()


func _process(_delta: float) -> void:
	# The place opens a moment after the title (the boot changes scene once
	# the title is up), so keep looking for its HUD while the title is open.
	var scene := get_tree().current_scene
	if scene == null or not visible:
		return
	for found in scene.find_children("*", "CanvasLayer", true, false):
		var layer_node := found as CanvasLayer
		if layer_node.visible and layer_node.layer >= HIDE_FROM_LAYER and layer_node.layer < layer:
			layer_node.visible = false
			_hidden.append(layer_node)


func close() -> void:
	for layer_node in _hidden:
		if is_instance_valid(layer_node):
			layer_node.visible = true
	_hidden.clear()
	super()


func _build_top(holder: VBoxContainer) -> void:
	var name_label := Label.new()
	name_label.text = ProjectSettings.get_setting("application/config/name", "Pixel Harvest")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Pixelify Sans at three times its clean size (13), so it stays crisp.
	name_label.add_theme_font_override(&"font", UiStyle.HEADING_FONT)
	name_label.add_theme_font_size_override(&"font_size", UiStyle.HEADING_SIZE * 3)
	name_label.add_theme_color_override(&"font_color", UiStyle.TEXT)
	name_label.add_theme_color_override(&"font_outline_color", UiStyle.OUTLINE)
	name_label.add_theme_constant_override(&"outline_size", 8)
	holder.add_child(name_label)


func _show_main() -> void:
	_page("", true)
	_hint.text = "Space / Enter: choose"
	if _has_game:
		_button("Continue", _game_in_hand(), close)
	var new_detail := "Start your farm on the first morning of spring."
	if _has_game:
		new_detail = "Start again on the first morning of spring. Your saved game is kept until you first sleep in the new one."
	elif save_was_unreadable:
		new_detail = "Your saved game couldn't be read, so it's been put aside as save.unreadable.json. Start a new farm."
	_button("New game", new_detail, _ask_difficulty)
	_button("Settings", "Music and sound volume, window or full screen.", _show_settings)
	_button("Controls", "Which key does what.", _show_controls)
	_button("Quit", "Close the game.", _quit_game)
	_focus_first()


## Esc on the title does nothing: there's no game behind it to go back to yet.
func _on_escape_at_main() -> void:
	pass


## "Spring 5, year 1  ·  340 gold  ·  Standard": the saved game, as loaded.
func _game_in_hand() -> String:
	var theme := GameState.current_season_theme()
	var season := theme.display_name if theme != null else ""
	return "%s %d, year %d  ·  %d gold  ·  %s" % [season, GameState.day, GameState.year,
			GameState.gold, GameState.difficulty.display_name]


func _ask_difficulty() -> void:
	_asking_difficulty = true
	visible = false
	var menu := DifficultyMenu.new()
	menu.can_cancel = true
	menu.cancel_words = "back"
	menu.chosen.connect(_start_new_game)
	# Esc on the difficulty menu: it un-pauses as it closes, so pause again
	# and come back to the title.
	menu.tree_exited.connect(func() -> void:
		if _asking_difficulty and is_inside_tree():
			_asking_difficulty = false
			get_tree().paused = true
			visible = true
			_focus_first())
	get_tree().root.add_child(menu)


func _start_new_game(difficulty: DifficultyDef) -> void:
	_asking_difficulty = false
	close()
	SaveSystem.start_new_game(difficulty)
