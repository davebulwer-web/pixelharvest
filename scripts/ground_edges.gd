class_name GroundEdges
extends Node2D
##
## GroundEdges — the soft edges where two kinds of ground meet (Stage 23,
## DECISIONS 072). Display only: nothing here is saved or read by the rules.
##
## The map's Ground layer still holds one plain tile per cell, and still gives
## the pond, the sea and the cliffs their collision. This node draws over it
## a second picture of the same ground, built differently: a "dual grid".
##
## The dual grid. Each picture tile here sits half a tile up and left of the
## game's cells, so its middle is a CORNER where four cells meet, and it is
## chosen from what those four cells are. Where all four are grass it shows
## plain grass; where the two top ones are grass and the two bottom ones path,
## it shows grass with a soft, ragged edge running across its middle onto the
## path. Sixteen pictures (every mix of four corners) cover every case, and
## that is exactly the 4 × 4 set Pixellab's terrain tool makes.
##
## Layers by height. Rather than a set of sixteen for every PAIR of grounds,
## each kind of ground has a height (GroundTiles.EDGE_GROUNDS, lowest first)
## and one set that draws it over anything lower. At each corner the lowest
## ground there is drawn whole, and every higher one is drawn on top with its
## edge picture, on its own layer. A ground counts as present at every corner
## cell that is it OR anything higher, so the higher grounds always sit on a
## bed of the ones below and nothing shows through.
##
## Some ground keeps its square edges (the cliffs, the pier: GroundTiles.
## edge_ground() says -1): it counts as "higher than everything" for the soft
## layers underneath and is then drawn again, square, on a layer of its own
## on top.
##
## Foam (session 5, DECISIONS 073). Where the sea meets anything, a ring of
## foam is drawn on the sea just off the shore, on a layer between the sea and
## the wet sand; the tileset animates it, so it runs up the beach and back. It
## follows the tide by itself, like everything here.
##
## Scatter. Along the joins, now and then, a tuft or a pebble is drawn on a
## layer of its own, so edges look lived in. Purely cosmetic, like the grass
## details.
##
## How it keeps up. GroundTiles.draw() tells this node (through the Ground
## layer's meta) whenever a cell is drawn: the hoe tilling, a field going back
## to grass, the tide turning. The four corners round that cell are marked,
## and redrawn once at the end of the frame, however many cells changed.
##

## The Ground layer's meta key that points at its GroundEdges, if it has one.
const META := &"ground_edges"

## How far the soft layers sit from the game's grid: half a tile up and left,
## so a picture tile's middle is the corner between four cells.
const HALF_TILE := Vector2(-8, -8)

## How often a corner on a join gets a scatter piece.
const SCATTER_CHANCE := 0.3

## The four cells round corner (0, 0), and the bit each sets in an edge
## picture's mask (the column of its picture: see GroundTiles.edge_tile()).
const _CORNER_CELLS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0),
]
const _CORNER_BITS: Array[int] = [1, 2, 4, 8]

var _ground: TileMapLayer

## One TileMapLayer per kind of soft ground, lowest first (index = the
## GroundTiles.EdgeGround value).
var _layers: Array[TileMapLayer] = []
var _scatter: TileMapLayer
var _square: TileMapLayer
var _foam: TileMapLayer
## TEST (DECISIONS 080): the harbour's fronts in the sea (quay wall, pier
## posts, breakwater foot), on the game's grid, over the soft layers.
var _front: TileMapLayer

## Corners waiting to be redrawn at the end of the frame.
var _dirty: Dictionary = {}  # Vector2i -> true
var _flush_queued := false


## Give `ground` soft edges: build the layers just above it and draw every
## cell already on it. Call it after SeasonLook.apply_ground(), before or
## after the map draws its ground (either way works: drawing marks cells).
static func attach(ground: TileMapLayer) -> GroundEdges:
	var edges := GroundEdges.new()
	edges.name = "GroundEdges"
	edges._ground = ground
	edges.position = ground.position
	# Same depth as the ground, and straight after it in the tree, so it
	# draws over the ground and under everything else.
	edges.z_index = ground.z_index
	ground.set_meta(META, edges)
	var parent := ground.get_parent()
	parent.add_child(edges)
	parent.move_child(edges, ground.get_index() + 1)
	edges._build_layers()
	for cell in ground.get_used_cells():
		edges.mark(cell)
	return edges


## The GroundEdges drawing over `ground`, or null for one without (rooms).
static func of(ground: TileMapLayer) -> GroundEdges:
	if ground == null or not ground.has_meta(META):
		return null
	return ground.get_meta(META) as GroundEdges


## `cell` on the ground has just been drawn: redraw the four corners round it
## at the end of this frame.
func mark(cell: Vector2i) -> void:
	for step: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_dirty[cell + step] = true
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## TEST (DECISIONS 076): Ctrl+G swaps between our own ground and the cozy
## pack's, if it's built. Every outdoor map has one of these, so it works
## everywhere outside.
func _unhandled_input(event: InputEvent) -> void:
	if _swap_calm(event) or _swap_harbour(event) or _swap_pack(event):
		return
	if not event.is_action_pressed(&"swap_ground_look") or not SeasonLook.has_cozy_ground():
		return
	get_viewport().set_input_as_handled()
	SeasonLook.cozy_ground = not SeasonLook.cozy_ground
	SeasonLook.apply_ground(_ground)
	EventBus.message_posted.emit("Ground look: %s (Ctrl+G to swap)."
			% ("Cozy pack" if SeasonLook.cozy_ground else "our own"))


## TEST (DECISIONS 080): Ctrl+H swaps the harbour's pictures on and off.
func _swap_harbour(event: InputEvent) -> bool:
	if not event.is_action_pressed(&"swap_harbour_look") or not SeasonLook.has_harbour_test():
		return false
	get_viewport().set_input_as_handled()
	SeasonLook.harbour_test = not SeasonLook.harbour_test
	SeasonLook.apply_ground(_ground)
	EventBus.message_posted.emit("Harbour look: %s (Ctrl+H to swap)."
			% ("on" if SeasonLook.harbour_test else "off"))
	return true


## TEST (DECISIONS 081): Ctrl+P swaps the packs' props and dressing, Ctrl+U
## the wooden UI.
func _swap_pack(event: InputEvent) -> bool:
	var props := event.is_action_pressed(&"swap_pack_props")
	var ui := event.is_action_pressed(&"swap_pack_ui")
	if not (props or ui) or not PackLook.has_pack():
		return false
	get_viewport().set_input_as_handled()
	PackLook.set_on(PackLook.props_on != props, PackLook.ui_on != ui)
	if props:
		EventBus.message_posted.emit("Pack props and dressing: %s (Ctrl+P to swap)."
				% ("on" if PackLook.props_on else "off"))
	else:
		EventBus.message_posted.emit("Wooden UI: %s (Ctrl+U to swap)."
				% ("on" if PackLook.ui_on else "off"))
	return true


## TEST (DECISIONS 078): Ctrl+K swaps the calmer cliffs and paving on and off
## (over the cozy ground only).
func _swap_calm(event: InputEvent) -> bool:
	if not event.is_action_pressed(&"swap_calm_look") or not SeasonLook.has_calm_test():
		return false
	get_viewport().set_input_as_handled()
	SeasonLook.calm_test = not SeasonLook.calm_test
	SeasonLook.apply_ground(_ground)
	EventBus.message_posted.emit("Calm cliffs and paving: %s (Ctrl+K to swap)."
			% ("on" if SeasonLook.calm_test else "off"))
	return true


## The season changed the ground's tileset: every layer here shows the same
## tileset (its edge pictures are a second source in each season's ground
## tileset), so they follow.
func follow_tileset() -> void:
	for layer in _all_layers():
		layer.tile_set = _ground.tile_set
	# The calm test's cliffs (DECISIONS 078) are only in some tilesets, so
	# the square layer is redrawn: with them or without.
	for cell in _ground.get_used_cells():
		mark(cell)


func _build_layers() -> void:
	for i in GroundTiles.EDGE_GROUNDS.size():
		_layers.append(_new_layer("Edge_%d" % i, HALF_TILE))
		if i == GroundTiles.EdgeGround.SEA:
			# Straight after the sea, so whatever lies on the sea covers the
			# foam's inner half and only the ring out on the water shows.
			_foam = _new_layer("Foam", HALF_TILE)
	_scatter = _new_layer("EdgeScatter", HALF_TILE)
	_front = _new_layer("HarbourFront", Vector2.ZERO)
	_square = _new_layer("SquareGround", Vector2.ZERO)


func _new_layer(layer_name: String, offset: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.position = offset
	layer.tile_set = _ground.tile_set
	# Pictures only: the Ground layer underneath keeps the collision.
	layer.collision_enabled = false
	layer.navigation_enabled = false
	add_child(layer)
	return layer


func _all_layers() -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = _layers.duplicate()
	result.append(_scatter)
	result.append(_square)
	result.append(_foam)
	result.append(_front)
	return result


func _flush() -> void:
	_flush_queued = false
	if not is_instance_valid(_ground):
		return
	var bounds := _ground.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return
	var square_cells: Dictionary = {}
	for corner: Vector2i in _dirty:
		_draw_corner(corner, bounds)
		# The square layer is on the game's own grid: a corner's bottom-right
		# cell is the one that corner was marked for.
		square_cells[corner] = true
	for cell: Vector2i in square_cells:
		_draw_square(cell)
	_dirty.clear()


## Redraw the soft layers and the scatter at `corner`.
func _draw_corner(corner: Vector2i, bounds: Rect2i) -> void:
	# What each of the four cells is, as an edge-ground height (-1: square).
	var kinds: Array[int] = []
	var lowest := GroundTiles.EDGE_GROUNDS.size()
	for i in 4:
		var kind := _kind_at(_clamp(corner + _CORNER_CELLS[i], bounds))
		kinds.append(kind)
		if kind >= 0 and kind < lowest:
			lowest = kind
	for layer in _layers:
		layer.erase_cell(corner)
	_scatter.erase_cell(corner)
	_foam.erase_cell(corner)
	if lowest == GroundTiles.EDGE_GROUNDS.size():
		return  # all four square: the square layer covers it
	# The lowest ground is drawn whole; every higher one present over it.
	var drawn: Dictionary = {}
	for i in 4:
		var kind := kinds[i]
		if kind < 0 or drawn.has(kind):
			continue
		drawn[kind] = true
	drawn[lowest] = true
	for kind: int in drawn:
		var layer := _layers[kind]
		if kind == lowest:
			var fill := GroundTiles.edge_fill(kind, corner)
			layer.set_cell(corner, GroundTiles.SOURCE_ID, fill,
					GroundTiles.transform_for(corner, fill))
			continue
		var mask := 0
		for i in 4:
			# Present where the cell is this ground or anything higher (square
			# ground counts as highest of all).
			if kinds[i] < 0 or kinds[i] >= kind:
				mask |= _CORNER_BITS[i]
		layer.set_cell(corner, GroundTiles.EDGE_SOURCE_ID,
				GroundTiles.edge_tile(kind, mask, corner, lowest))
	if drawn.size() > 1:
		_maybe_scatter(corner, drawn)
		if lowest == GroundTiles.EdgeGround.SEA:
			_draw_foam(corner, kinds)


## The foam round whatever meets the sea at `corner`.
func _draw_foam(corner: Vector2i, kinds: Array[int]) -> void:
	var mask := 0
	for i in 4:
		if kinds[i] != GroundTiles.EdgeGround.SEA:
			mask |= _CORNER_BITS[i]
	_foam.set_cell(corner, GroundTiles.EDGE_SOURCE_ID, GroundTiles.foam_tile(mask))


## Now and then, a tuft or a pebble on a join between two soft grounds that
## can carry one (GroundTiles.scatter_for()).
func _maybe_scatter(corner: Vector2i, kinds: Dictionary) -> void:
	if GroundTiles.roll(corner, 11) >= SCATTER_CHANCE:
		return
	var piece := GroundTiles.scatter_for(kinds.keys(), corner)
	if piece.x < 0:
		return
	var flip := TileSetAtlasSource.TRANSFORM_FLIP_H if GroundTiles.pick(corner, 12, 2) == 1 else 0
	_scatter.set_cell(corner, GroundTiles.EDGE_SOURCE_ID, piece, flip)


## Square ground (cliff, pier) drawn again on top, on the game's grid.
## With the calm test's tileset (DECISIONS 078) a cliff is drawn as raised
## ground instead, its picture chosen by which sides open onto something else.
func _draw_square(cell: Vector2i) -> void:
	var source := _ground.get_cell_source_id(cell)
	var coords := _ground.get_cell_atlas_coords(cell)
	_draw_front(cell)
	if source == GroundTiles.SOURCE_ID and coords == GroundTiles.PIER and _has_edge_tile(GroundTiles.pier_tile(0)):
		_square.set_cell(cell, GroundTiles.EDGE_SOURCE_ID,
				GroundTiles.pier_tile(_open_sides(cell, [GroundTiles.PIER, GroundTiles.PAVING])))
	elif source == GroundTiles.SOURCE_ID and coords == GroundTiles.CLIFF and _has_cliff_pictures():
		var sides := _open_sides(cell)
		# The cell above a cliff's foot shows the upper half of a taller face.
		var below := cell + Vector2i.DOWN
		var above_face := sides & 4 == 0 and _is_cliff(below) and _open_sides(below) & 4 != 0
		_square.set_cell(cell, GroundTiles.EDGE_SOURCE_ID,
				GroundTiles.cliff_tile(sides, above_face))
	elif source == GroundTiles.SOURCE_ID and GroundTiles.edge_ground(coords) < 0:
		_square.set_cell(cell, source, coords, _ground.get_cell_alternative_tile(cell))
	else:
		_square.erase_cell(cell)


## Whether the ground's tileset has the calm test's cliff pictures.
func _has_cliff_pictures() -> bool:
	return _has_edge_tile(GroundTiles.cliff_tile(0))


## Whether the ground's tileset has edge picture `coords` (the tests' extra
## rows are only in their own tilesets).
func _has_edge_tile(coords: Vector2i) -> bool:
	var tiles := _ground.tile_set
	if tiles == null or not tiles.has_source(GroundTiles.EDGE_SOURCE_ID):
		return false
	var edges := tiles.get_source(GroundTiles.EDGE_SOURCE_ID) as TileSetAtlasSource
	return edges != null and edges.has_tile(coords)


## TEST (DECISIONS 080): on a sea cell just south of the quay, the pier or
## the breakwater, what stands in the water there: the quay's wall, the
## pier's posts, the breakwater's foot. Pictures only, like everything here.
func _draw_front(cell: Vector2i) -> void:
	_front.erase_cell(cell)
	if _coords_at(cell) != GroundTiles.SEA or not _has_edge_tile(GroundTiles.front_tile(GroundTiles.Front.QUAY)):
		return
	var above := _coords_at(cell + Vector2i.UP)
	var left_same := _coords_at(cell + Vector2i(-1, -1)) == above and _coords_at(cell + Vector2i.LEFT) == GroundTiles.SEA
	var right_same := _coords_at(cell + Vector2i(1, -1)) == above and _coords_at(cell + Vector2i.RIGHT) == GroundTiles.SEA
	var front := -1
	if above == GroundTiles.PAVING:
		if left_same and right_same:
			# A ladder down to the water now and then along the wall.
			front = GroundTiles.Front.QUAY_LADDER if GroundTiles.pick(cell, 13, 7) == 0 else GroundTiles.Front.QUAY
		else:
			front = GroundTiles.Front.QUAY_LEFT if not left_same and right_same \
					else GroundTiles.Front.QUAY_RIGHT if left_same and not right_same else GroundTiles.Front.QUAY
	elif above == GroundTiles.PIER:
		var pier_left := _coords_at(cell + Vector2i(-1, -1)) == GroundTiles.PIER
		var pier_right := _coords_at(cell + Vector2i(1, -1)) == GroundTiles.PIER
		if pier_left and pier_right:
			front = GroundTiles.Front.POSTS_MID
		elif pier_right:
			front = GroundTiles.Front.POSTS_LEFT
		elif pier_left:
			front = GroundTiles.Front.POSTS_RIGHT
		else:
			front = GroundTiles.Front.POSTS_SINGLE
	elif above == GroundTiles.ROCKS:
		front = GroundTiles.Front.BREAKWATER
	if front >= 0:
		_front.set_cell(cell, GroundTiles.EDGE_SOURCE_ID, GroundTiles.front_tile(front))


## The ground tile at `cell`, or (-1, -1) for none.
func _coords_at(cell: Vector2i) -> Vector2i:
	if _ground.get_cell_source_id(cell) != GroundTiles.SOURCE_ID:
		return Vector2i(-1, -1)
	return _ground.get_cell_atlas_coords(cell)


func _is_cliff(cell: Vector2i) -> bool:
	return _ground.get_cell_source_id(cell) == GroundTiles.SOURCE_ID \
			and _ground.get_cell_atlas_coords(cell) == GroundTiles.CLIFF


## Which sides of the cliff cell `cell` open onto something that isn't cliff:
## 1 north, 2 east, 4 south, 8 west. Beyond the map's drawn cells counts as
## cliff, so the map's border shows no edge on its outer side.
## `joined` lists the ground that counts as the same (the pier joins the
## quay's paving).
func _open_sides(cell: Vector2i, joined: Array = [GroundTiles.CLIFF]) -> int:
	var sides := 0
	var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var beside := cell + steps[i]
		if _ground.get_cell_source_id(beside) == -1:
			continue
		if not _ground.get_cell_atlas_coords(beside) in joined:
			sides |= 1 << i
	return sides


## What the Ground layer shows at `cell`, as an edge-ground height, or -1 for
## square ground (and for nothing at all, which a map shouldn't have).
## This reads the PICTURE, not the game's state: it only decides how other
## pictures look, which keeps every map's own drawing code as it was.
func _kind_at(cell: Vector2i) -> int:
	if _ground.get_cell_source_id(cell) != GroundTiles.SOURCE_ID:
		return -1
	return GroundTiles.edge_ground(_ground.get_cell_atlas_coords(cell))


## Cells beyond the map's edge are taken to be the nearest cell on it, so the
## ground runs on to the edge without a fringe.
static func _clamp(cell: Vector2i, bounds: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, bounds.position.x, bounds.end.x - 1),
		clampi(cell.y, bounds.position.y, bounds.end.y - 1))
