extends Node
##
## ContentDB — finds every crop and tool definition by its id.
##
## A save file can't hold a CropDef or a ToolDef; it holds their ids (&"parsnip",
## &"hoe"). Loading a save needs the way back: "which resource has id parsnip?"
## That's this file's whole job for now (DECISIONS 022).
##
## It builds its index by looking in the content folders when the game starts,
## so adding a crop is still just dropping a .tres into data/crops/ — nothing
## here needs editing (rule 3). Stage 4 grows this into the full content
## catalogue: more kinds of content, and lists for the shop to show.
##

const CROPS_DIR := "res://data/crops/"
const TOOLS_DIR := "res://data/tools/"

var _crops: Dictionary = {}  # StringName -> CropDef
var _tools: Dictionary = {}  # StringName -> ToolDef


func _ready() -> void:
	_index(CROPS_DIR, _crops)
	_index(TOOLS_DIR, _tools)


## The crop with this id, or null if there isn't one (for example, a save from
## before a crop was removed from the game).
func crop(id: StringName) -> CropDef:
	return _crops.get(id)


## The tool with this id, or null if there isn't one.
func tool(id: StringName) -> ToolDef:
	return _tools.get(id)


## Load every .tres in `dir` and file it under its own `id` field.
##
## ResourceLoader.list_directory rather than DirAccess: in an exported game the
## .tres files are converted and renamed, and list_directory reports the names
## as they were in the project, so this works the same in the editor and in a
## Windows build.
func _index(dir: String, into: Dictionary) -> void:
	for file_name: String in ResourceLoader.list_directory(dir):
		if not file_name.ends_with(".tres"):
			continue
		var path := dir + file_name
		var resource := load(path)
		var id: StringName = resource.get(&"id") if resource != null else &""
		if id == &"":
			push_error("ContentDB: '%s' has no id, so nothing can refer to it" % path)
			continue
		if into.has(id):
			# Two files claiming one id would make saves load the wrong thing
			# depending on file order. Say so loudly and keep the first.
			push_error("ContentDB: '%s' reuses the id '%s'" % [path, id])
			continue
		into[id] = resource
