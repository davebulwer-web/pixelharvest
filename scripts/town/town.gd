extends Node2D
##
## Town — the town scene: the road, the square, a door for every shop, and
## the people who live here.
##
## Like the farm it owns no game state. It draws a fixed map (TownLayout) and
## stands its decoration on it, builds a Building for every location whose
## door is on this map and an Npc for every CharacterDef who lives here (so a
## new shop or a new townsperson appears with no edit to this file), and puts
## the arriving player at the spawn point LocationManager asked for. Tools are
## off in town (the farm's tiles aren't here to be hoed), and so is sleeping.
##
## Talking: E on a townsperson or the notice board is announced on EventBus
## (npc_talked_to, notice_board_read); this scene answers with the dialogue
## box. A shopkeeper's id never reaches here, because shopkeepers stand inside.
##
##   Town
##   ├── Ground      (TileMapLayer, same seasonal tilesets as the farm)
##   ├── SpawnPoints (Marker2Ds, made here: one per door, one for the farm gate)
##   ├── Entities    (y-sorted: player, trees, decoration, shop fronts, people)
##   ├── Weather     (the season's overlay — winter's snow — as on the farm)
##   ├── Hud         (the same HUD scene as the farm)
##   └── Dialogue    (the dialogue box, as in the shops)
##

const TILE_PX := 16
const TOWN_ID := &"town"
const FARM_ID := &"farm"

@onready var _ground: TileMapLayer = $Ground
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _spawns: Node2D = $SpawnPoints
@onready var _weather: Node = $Weather
@onready var _dialogue = $Dialogue


func _ready() -> void:
	_player.can_farm = false
	var doors: Array[LocationDef] = LocationManager.buildings_on(TOWN_ID)
	var door_cells: Array[Vector2i] = []
	for def in doors:
		door_cells.append(def.door_cell)

	SeasonLook.apply_ground(_ground)
	var tiles := TownLayout.build(door_cells)
	for cell: Vector2i in tiles:
		GroundTiles.draw(_ground, cell, tiles[cell])

	for def in doors:
		_entities.add_child(Building.create(def))
		_add_spawn(StringName("from_%s" % def.id), Vector2(
				def.door_cell.x * TILE_PX + TILE_PX / 2.0, (def.door_cell.y + 2) * TILE_PX - 2))
	_add_spawn(&"from_farm", TownLayout.ARRIVAL_FROM_FARM)
	_place_objects()
	_place_townsfolk()
	_add_farm_gate()
	_place_player()
	SeasonLook.apply_overlay(_weather)
	_limit_camera()
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	EventBus.notice_board_read.connect(_on_notice_board_read)


func _base_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_PX + TILE_PX / 2.0, (cell.y + 1) * TILE_PX)


func _add_spawn(point_name: StringName, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = String(point_name)
	marker.position = at
	_spawns.add_child(marker)


## Stand every tree, lamp, bench and flower bed from TownLayout.OBJECTS. Each
## is an ObjectDef, so it wears its season's picture if the season has one.
func _place_objects() -> void:
	for cell: Vector2i in TownLayout.OBJECTS:
		var id: StringName = TownLayout.OBJECTS[cell]
		var def := ContentDB.object(id)
		if def == null or def.scene == null:
			push_warning("Town can't place '%s' at %s: no data/objects/ file with that id and a scene"
					% [id, cell])
			continue
		var node: Node2D = def.scene.instantiate()
		node.position = _base_of(cell)
		_entities.add_child(node)
		SeasonLook.skin_object(node, id)


## An Npc for everyone who lives in town, at today's spot.
func _place_townsfolk() -> void:
	for person in ContentDB.characters_in(TOWN_ID):
		if person.spots.is_empty():
			continue  # ContentDB has already said so
		_entities.add_child(Npc.create(person.id, person.sprite, person.spot_on(GameState.day)))


## The way back: the gap beyond the east end of the road.
func _add_farm_gate() -> void:
	var top_left: Vector2i = TownLayout.FARM_GATE[0]
	var rect := Rect2(top_left * TILE_PX, Vector2(TILE_PX, TILE_PX * TownLayout.FARM_GATE.size()))
	_add_zone(rect, FARM_ID, &"from_town")


func _add_zone(rect: Rect2, to: StringName, arrival: StringName) -> void:
	add_child(ExitZone.create(rect, to, arrival))


func _place_player() -> void:
	var point := LocationManager.take_arrival_point()
	var spawn := _spawns.get_node_or_null(NodePath(String(point)) if point != &"" else ^"from_farm") as Marker2D
	if spawn == null:
		push_warning("Town has no spawn point '%s'" % point)
		spawn = _spawns.get_node(^"from_farm")
	_player.position = spawn.position


## Keep the camera inside the town and its border, so it never shows past the
## edge of the world.
func _limit_camera() -> void:
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = -TILE_PX
	camera.limit_top = -TILE_PX
	camera.limit_right = (TownLayout.SIZE.x + 1) * TILE_PX
	camera.limit_bottom = (TownLayout.SIZE.y + 1) * TILE_PX


# --- Talking -----------------------------------------------------------------

func _on_npc_talked_to(npc_id: StringName) -> void:
	var person := ContentDB.character(npc_id)
	if person == null or person.location != TOWN_ID:
		return
	var line := person.line_on(GameState.day)
	if line == "":
		return
	var lines: Array[String] = [line]
	_dialogue.say(person.display_name, lines)


func _on_notice_board_read() -> void:
	_dialogue.say("Notice board", Notices.today())
