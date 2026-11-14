class_name UiStyle
extends RefCounted
##
## UiStyle — the few colours and boxes the stopgap UI (HUD, hotbar, shop) shares,
## so they look like one game. All colours are from art/palette.png.
##
## Stage 9 replaces this with a proper Godot Theme resource and a pixel font;
## until then, one small file is easier to follow than a theme.
##

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


## A flat box with a 1px edge, for panels and buttons.
static func box(fill: Color, edge: Color, padding: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style


## Light text with a dark outline, readable over grass or soil.
static func style_label(label: Label, size: int = 10, colour: Color = TEXT) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_outline_color", OUTLINE)
	label.add_theme_constant_override(&"outline_size", 4)
