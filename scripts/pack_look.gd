class_name PackLook
extends RefCounted
##
## PackLook — TEST (DECISIONS 081): the bought packs' props, festival dressing
## and wooden UI, built by art/build_pack_look.py into assets/packs/. That
## folder is kept out of git (the packs' licence; the repository is public),
## so on a copy without it nothing here changes anything.
##
## - Props: our objects (bench, lamp post, fences, well ...) wear the packs'
##   pictures (SeasonLook.skin_object asks texture_for()). Fences and walls
##   join up with their neighbours, as the packs' 4-bit sheets are drawn.
## - Dressing: extra pieces that are only looks (the Cove's harbour clutter,
##   the four festivals' and market day's decorations in town): dress().
##   Nothing walks into them and nothing is saved.
## - UI: the Wood theme's panel, buttons, hotbar slots and portrait frame
##   (our fonts stay).
##
## Ctrl+P flips props and dressing, Ctrl+U the UI (GroundEdges). Never saved.
##

const DIR := "res://assets/packs/"
const DATA := DIR + "pack_look.json"
const TILE_PX := 16
## Drawn over people, as the packs ask for lights and bunting.
const ABOVE_Z := 20
## The Wood panel's paper (the middle of its panel picture), behind portraits.
const WOOD_PAPER := Color8(232, 194, 144)

static var props_on := true
static var ui_on := true

static var _data: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
## The project theme's own textures and margins, to put back (UI off).
static var _theme_saved: Dictionary = {}
## Every panel UiStyle.panel() handed out (weak), so a flip reaches them too.
static var _panels: Array[WeakRef] = []


## Whether the packs' look has been built on this copy of the game.
static func has_pack() -> bool:
	return _load()


static func _load() -> bool:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(DATA):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
			if parsed is Dictionary:
				_data = parsed
				apply_ui.call_deferred()
	return not _data.is_empty()


static func _texture(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(DIR + file) if ResourceLoader.exists(DIR + file) else null
	return _textures[file]


## The pack's picture for our object `object_id`, or null (ours stays).
static func texture_for(object_id: StringName) -> Texture2D:
	if not props_on or not _load():
		return null
	var sprites: Dictionary = _data.get("sprites", {})
	if sprites.has(String(object_id)):
		return _texture(sprites[String(object_id)])
	return null


## Whether `object_id` is drawn from a 4-bit sheet that joins neighbours.
static func joins(object_id: StringName) -> bool:
	return props_on and _load() and _data.get("joins", {}).has(String(object_id))


## One piece of a 4-bit sheet (index N*8 + E*4 + S*2 + W*1).
static func _sheet_piece(sheet: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((index % 4) * TILE_PX, (index / 4) * TILE_PX, TILE_PX, TILE_PX)
	return atlas


## Give a joined object (`node`, whose Sprite2D is `sprite`) the piece for its
## neighbours of the same kind, and its neighbours theirs.
static func join(node: Node2D, sprite: Sprite2D, object_id: StringName) -> void:
	node.set_meta(&"pack_join", object_id)
	if not node.tree_exiting.is_connected(_on_joined_leaving):
		node.tree_exiting.connect(_on_joined_leaving.bind(node))
	_pick_join(node, sprite, object_id)
	for other in _joined_neighbours(node, object_id):
		_pick_join(other, other.get_node(^"Sprite"), object_id)


static func _pick_join(node: Node2D, sprite: Sprite2D, object_id: StringName, leaving: Node = null) -> void:
	var sheet := _texture(_data["joins"][String(object_id)])
	if sheet == null or sprite == null:
		return
	var index := 0
	for other in _joined_neighbours(node, object_id, leaving):
		var d := (other.position - node.position).round()
		if d.y < 0: index |= 8
		elif d.x > 0: index |= 4
		elif d.y > 0: index |= 2
		else: index |= 1
	sprite.texture = _sheet_piece(sheet, index)


static func _joined_neighbours(node: Node2D, object_id: StringName, leaving: Node = null) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var parent := node.get_parent()
	if parent == null:
		return out
	for other in parent.get_children():
		if other == node or other == leaving or not other is Node2D:
			continue
		if other.get_meta(&"pack_join", &"") != object_id or other.is_queued_for_deletion():
			continue
		var d: Vector2 = ((other as Node2D).position - node.position).round()
		if absf(d.x) + absf(d.y) == TILE_PX:
			out.append(other)
	return out


## A fence taken away: its neighbours lose the join towards it.
static func _on_joined_leaving(node: Node2D) -> void:
	var object_id: StringName = node.get_meta(&"pack_join", &"")
	if object_id == &"" or not joins(object_id):
		return
	for other in _joined_neighbours(node, object_id):
		_pick_join(other, other.get_node_or_null(^"Sprite"), object_id, node)


## Put up the dressing for `location_id` under `entities` (today's events'
## pieces too): bottom middle on the bottom middle of each piece's cell.
static func dress(entities: Node2D, location_id: StringName) -> void:
	if not _load():
		return
	var today: Array[StringName] = []
	for event in GameState.events_today():
		if event.location == location_id:
			today.append(event.id)
	for item: Dictionary in _data.get("pieces", []):
		if StringName(item["location"]) != location_id:
			continue
		var event := StringName(item.get("event", ""))
		if event != &"" and not today.has(event):
			continue
		# Market day's pieces stand aside when a festival shares the day.
		if item.get("alone", false) and today.size() > 1:
			continue
		var node := _make_piece(item)
		if node == null:
			continue
		var cell := Vector2(item["cell"][0], item["cell"][1])
		node.position = Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)
		node.visible = props_on
		node.add_to_group(&"pack_dressing")
		entities.add_child(node)


static func _make_piece(item: Dictionary) -> Node2D:
	var picture: Dictionary = _data["pictures"].get(item["picture"], {})
	var tex := _texture(picture.get("file", ""))
	if tex == null:
		return null
	var holder := Node2D.new()
	holder.name = "Pack_%s" % item["picture"]
	var lift := float(item.get("lift", 0))
	if item.get("above", false):
		holder.z_index = ABOVE_Z
	var frames := int(picture.get("frames", 1))
	if picture.get("sheet", false):
		var sprite := Sprite2D.new()
		sprite.texture = _sheet_piece(tex, int(item.get("join", 0)))
		sprite.offset = Vector2(0, -TILE_PX / 2.0 - lift)
		holder.add_child(sprite)
	elif frames > 1:
		var w := tex.get_width() / frames
		var h := tex.get_height()
		var sprite_frames := SpriteFrames.new()
		var order: Array = range(frames)
		if picture.get("pingpong", false):
			order += range(frames - 2, 0, -1)
		for f: int in order:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(f * w, 0, w, h)
			sprite_frames.add_frame(&"default", atlas)
		sprite_frames.set_animation_speed(&"default", 6.0)
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sprite_frames
		anim.offset = Vector2(0, -h / 2.0 - lift)
		anim.play(&"default")
		holder.add_child(anim)
	else:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 - lift)
		holder.add_child(sprite)
	return holder


## Flip the props and dressing, and/or the UI, and show it everywhere now.
static func set_on(props: bool, ui: bool) -> void:
	props_on = props
	ui_on = ui
	refresh()


static func refresh() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"pack_skinned"):
		SeasonLook.skin_object(node, node.get_meta(&"object_id"))
	for node in tree.get_nodes_in_group(&"pack_dressing"):
		node.visible = props_on
	apply_ui()
	tree.call_group(&"pack_ui", &"pack_ui_changed")


# --- UI --------------------------------------------------------------------------

## Whether the wooden UI is showing.
static func ui_active() -> bool:
	return ui_on and _load() and _data.has("ui")


## The Wood theme's picture for `key` (panel, slot, portrait_frame ...), or null.
static func ui_texture(key: String) -> Texture2D:
	if not ui_active():
		return null
	var entry: Dictionary = _data["ui"].get(key, {})
	return _texture(entry.get("file", ""))


static func ui_margin(key: String) -> int:
	return int(_data.get("ui", {}).get(key, {}).get("margin", 0))


## UiStyle.panel() calls this with each panel it hands out.
static func track_panel(style: StyleBox) -> void:
	if style is StyleBoxTexture:
		_panels = _panels.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
		_panels.append(weakref(style))
		_style_texture(style, "panel")


## Swap the project theme's panel and button pictures (or put ours back).
static func apply_ui() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var swaps := {
		"panel": [&"panel", &"PanelContainer"],
		"button_focus": [&"focus", &"Button"],
		"button_hover": [&"hover", &"Button"],
		"button_pressed": [&"pressed", &"Button"],
	}
	for key: String in swaps:
		var names: Array = swaps[key]
		if not theme.has_stylebox(names[0], names[1]):
			continue
		var style := theme.get_stylebox(names[0], names[1]) as StyleBoxTexture
		if style != null:
			_style_texture(style, key)
	for w in _panels:
		var style := w.get_ref() as StyleBoxTexture
		if style != null:
			_style_texture(style, "panel")


## Give a StyleBoxTexture the Wood picture for `key`, remembering its own the
## first time so it can have it back.
static func _style_texture(style: StyleBoxTexture, key: String) -> void:
	if not style.has_meta(&"own_texture"):
		style.set_meta(&"own_texture", style.texture)
		style.set_meta(&"own_margins", [style.texture_margin_left, style.texture_margin_top,
				style.texture_margin_right, style.texture_margin_bottom])
	var wood := ui_texture(key)
	if wood != null:
		style.texture = wood
		style.set_texture_margin_all(ui_margin(key))
	else:
		style.texture = style.get_meta(&"own_texture")
		var m: Array = style.get_meta(&"own_margins")
		style.texture_margin_left = m[0]
		style.texture_margin_top = m[1]
		style.texture_margin_right = m[2]
		style.texture_margin_bottom = m[3]
