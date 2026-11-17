class_name Exits
extends RefCounted
##
## Exits — builds a place's ways out from its LocationDef.exits (DECISIONS
## 060). Each map scene calls add() once as it opens; nothing else about a
## road between two places is code.
##
## For each ExitDef it adds:
##   - an ExitZone over the gap's cells, going to `to` and arriving at
##     "from_<this place>" there;
##   - a Marker2D called "from_<to>" at the exit's arrival cell, under the
##     scene's spawn points, for whoever comes back in this way.
##

const TILE_PX := 16


## Add the ways out of `location` to `scene`, and their arrival points to
## `spawns` (the scene's SpawnPoints node).
static func add(scene: Node, location: LocationDef, spawns: Node) -> void:
	if location == null:
		return
	for exit in location.exits:
		if exit == null or exit.cells.is_empty():
			continue
		scene.add_child(ExitZone.create(_rect_of(exit.cells), exit.to,
				StringName("from_%s" % location.id)))
		var marker := Marker2D.new()
		marker.name = "from_%s" % exit.to
		marker.position = arrival_position(exit.arrival)
		spawns.add_child(marker)


## Where someone arriving at `cell` stands, in pixels: the middle of the
## cell, feet a little below its centre (the same spot the old hand-placed
## markers used).
static func arrival_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, cell.y * TILE_PX + 12)


## Every gap cell of `location`'s exits: the map draws them as path.
static func gap_cells(location: LocationDef) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if location == null:
		return result
	for exit in location.exits:
		if exit != null:
			result.append_array(exit.cells)
	return result


## The rectangle, in pixels, covering every cell of `cells`.
static func _rect_of(cells: Array[Vector2i]) -> Rect2:
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return Rect2(Vector2(low * TILE_PX), Vector2((high - low + Vector2i.ONE) * TILE_PX))
