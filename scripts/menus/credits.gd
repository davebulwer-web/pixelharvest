class_name Credits
extends RefCounted
##
## Credits — who made what, in words for players, for the title screen's
## Credits page (DECISIONS 090).
##
## CREDITS.md at the top of the project is the full list for us, with where
## each thing is used and the licences' details; this is the short version
## a player reads. A .md file isn't part of the exported game, so the words
## live here. When CREDITS.md gains a line, add it here too.
##
## Each line is ["h", heading] or ["t", text]. monogram has no accented
## letters (í, é), so names are written without them.
##

const LINES: Array = [
	["h", "Made by"],
	["t", "Dave, with Claude. Characters, buildings and crops drawn with Pixellab."],
	["h", "Art packs"],
	["t", "By Michel Clauwaert: Cozy Village & Farm, Coast Beach & Fishing, Seasons & Festivals, Game UI Kit, Cozy Interiors & Town Life."],
	["h", "Fonts"],
	["t", "monogram by datagoblin (CC0), Pixelify Sans by Stefie Justprince (OFL)."],
	["h", "Music and engine"],
	["t", "Tunes by Dave. Godot Engine (MIT licence), © the Godot Engine contributors."],
]
