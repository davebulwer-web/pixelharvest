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


## The season changed the ground's tileset: every layer here shows the same
## tileset (its edge pictures are a second source in each season's ground
## tileset), so they follow.
func follow_tileset() -> void:
	for layer in _all_layers():
		layer.tile_set = _ground.tile_set


func _build_layers() -> void:
	for i in GroundTiles.EDGE_GROUNDS.size():
		_layers.append(_new_layer("Edge_%d" % i, HALF_TILE))
	_scatter = _new_layer("EdgeScatter", HALF_TILE)
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
		layer.set_cell(corner, GroundTiles.EDGE_SOURCE_ID, GroundTiles.edge_tile(kind, mask, corner))
	if drawn.size() > 1:
		_maybe_scatter(corner, drawn)


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
func _draw_square(cell: Vector2i) -> void:
	var source := _ground.get_cell_source_id(cell)
	var coords := _ground.get_cell_atlas_coords(cell)
	if source == GroundTiles.SOURCE_ID and GroundTiles.edge_ground(coords) < 0:
		_square.set_cell(cell, source, coords, _ground.get_cell_alternative_tile(cell))
	else:
		_square.erase_cell(cell)


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
