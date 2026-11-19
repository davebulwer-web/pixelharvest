class_name UiStyle
extends RefCounted
##
## UiStyle — the colours, sizes and boxes every screen shares, so they look like
## one game. All colours are from art/palette.png.
##
## Since Stage 24 (DECISIONS 074) the look itself lives in a Godot Theme,
## assets/ui/theme.tres, set as the project's theme: the pixel fonts (monogram
## for text, Pixelify Sans for headings) and the wooden nine-patch panel and
## buttons from assets/ui/. Every Label, Button and PanelContainer in the game
## picks it up without being told. This file is what code still asks for by
## name: a panel box with a given padding, a button styled like the others,
## and the two kinds of text:
##
## - *Text on the world* (the clock, the hotbar, a floating "+3", a "!" over
##   someone's head) is light with a dark outline, readable over grass or
##   soil: style_label().
## - *Text on a panel* (dialogue, menus, the day's summary) is dark ink on the
##   panel's cream paper, with no outline: style_panel_label(). It takes the
##   same colour names as world text (TEXT, TEXT_DIM, GOLD, WARNING,
##   HIGHLIGHT) and swaps each for its ink, so a screen says what a line *is*
##   (dim, a warning) and not which shade of brown it is.
##
## Sizes: monogram is drawn one font pixel to one game pixel only at 16, so
## every size asked for below 12 becomes 16 (the old 8, 9 and 10 of the
## default font all read about as big). 12 and over asked for a heading,
## so they get Pixelify Sans at its own clean size, 13.
##

# --- Text on the world: light, outlined -----------------------------------------

const TEXT := Color8(255, 231, 216)
const TEXT_DIM := Color8(171, 129, 108)
const OUTLINE := Color8(34, 34, 43)
const PANEL := Color8(54, 46, 54, 235)
const PANEL_EDGE := Color8(120, 88, 83)
const SLOT := Color8(34, 34, 43, 200)
const SLOT_EDGE := Color8(113, 113, 126)
const HIGHLIGHT := Color8(255, 231, 216)
const GOLD := Color8(200, 153, 123)
const WARNING := Color8(196, 73, 76)

# --- Text on a panel: ink on the panel's cream ----------------------------------

const INK := Color8(46, 31, 26)
const INK_DIM := Color8(120, 88, 83)
## Names, the highlighted answer, gold, "done": what the eye should find first.
const INK_ACCENT := Color8(63, 78, 113)
const INK_WARNING := Color8(172, 59, 70)
## The panel's own paper colour (the middle of assets/ui/panel.png), for
## anything drawn behind a picture that sits on a panel (the portrait).
const PAPER := Color8(255, 231, 216)

# --- Sizes ----------------------------------------------------------------------

## monogram's own size: one font pixel to one game pixel.
const FONT_SIZE := 16
## Pixelify Sans's clean size, for headings.
const HEADING_SIZE := 13
## Sizes asked for at this or above are headings.
const HEADING_FROM := 12

const HEADING_FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")

## Padding inside the panel's wooden border, on top of the border itself.
const PANEL_BORDER := 6


## The font size to use for a size the code asked for (see above).
static func font_size(asked: int) -> int:
	return HEADING_SIZE if asked >= HEADING_FROM else FONT_SIZE


## Text on the world: light with a dark outline, readable over grass or soil.
static func style_label(label: Label, size: int = 10, colour: Color = TEXT) -> void:
	_font_for(label, size)
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_outline_color", OUTLINE)
	label.add_theme_constant_override(&"outline_size", 4)


## Text on a panel: the ink for `colour`, no outline.
static func style_panel_label(label: Label, size: int = 10, colour: Color = TEXT) -> void:
	_font_for(label, size)
	label.add_theme_color_override(&"font_color", ink(colour))
	label.add_theme_constant_override(&"outline_size", 0)


## The ink on a panel for one of the world-text colours.
static func ink(colour: Color) -> Color:
	# (HIGHLIGHT is the same colour as TEXT, so both become INK.)
	if colour == TEXT_DIM:
		return INK_DIM
	if colour == GOLD:
		return INK_ACCENT
	if colour == WARNING:
		return INK_WARNING
	if colour == TEXT:
		return INK
	return colour


## The wooden panel (assets/ui/panel.png as a nine-patch, from the theme),
## with `padding` pixels of paper between its border and what's inside.
static func panel(padding: int = 8) -> StyleBox:
	var base := ThemeDB.get_project_theme()
	var style: StyleBox = null
	if base != null and base.has_stylebox(&"panel", &"PanelContainer"):
		style = base.get_stylebox(&"panel", &"PanelContainer").duplicate()
	else:
		style = box(PANEL, PANEL_EDGE, padding)  # no theme (shouldn't happen)
	style.set_content_margin_all(PANEL_BORDER + padding)
	return style


## Style a menu button (a row in a shop or the cook menu) like the theme's
## buttons, with dark ink text. The theme already does this for any Button;
## this is for buttons whose look was set by hand before the theme, so it
## clears those overrides.
static func style_button(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.remove_theme_stylebox_override(state)
	for colour: StringName in [&"font_color", &"font_focus_color", &"font_hover_color",
			&"font_pressed_color"]:
		button.remove_theme_color_override(colour)
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)


## A flat box with a 1px edge: the hotbar's slots and anything not a panel.
static func box(fill: Color, edge: Color, padding: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style


static func _font_for(label: Label, size: int) -> void:
	if size >= HEADING_FROM:
		label.add_theme_font_override(&"font", HEADING_FONT)
	else:
		label.remove_theme_font_override(&"font")
	label.add_theme_font_size_override(&"font_size", font_size(size))
