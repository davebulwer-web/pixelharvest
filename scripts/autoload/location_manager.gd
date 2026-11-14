extends Node
##
## LocationManager — moves the player between places (DECISIONS 004).
##
## Only the farm exists until Stage 7, so this does little yet. It's here now
## because the hard part of locations isn't the town, it's making sure nothing
## important lives in a scene that gets thrown away on the way out. Building
## the seam early forces that discipline on everything from Stage 2 onward.
##
## How a trip works:
##   1. Something calls go_to(&"town", &"from_farm").
##   2. GameState.location is updated, so the move is part of saved state.
##   3. The current scene is freed and the new location's scene loaded.
##   4. The new scene, in its _ready, asks take_arrival_point() where to put
##      the player — the name of a Marker2D under its SpawnPoints node.
##   5. location_changed is announced.
##

var _locations: Dictionary = {}  # StringName -> LocationDef
var _arrival_point: StringName = &""


func _ready() -> void:
	for location: LocationDef in GameState.RULES.locations:
		_locations[location.id] = location


## Go to `location_id`, arriving at the spawn point named `arrival_point`
## (empty means wherever the scene puts the player by default).
func go_to(location_id: StringName, arrival_point: StringName = &"") -> void:
	var location: LocationDef = _locations.get(location_id)
	if location == null:
		push_error("No location with id '%s' in game_rules.tres" % location_id)
		return
	GameState.location = location_id
	_arrival_point = arrival_point
	var error := get_tree().change_scene_to_file(location.scene_path)
	if error != OK:
		push_error("Could not open '%s' for location '%s'" % [location.scene_path, location_id])
		return
	EventBus.location_changed.emit(location_id)


## Called once by a location scene as it opens. Returns the arrival point and
## clears it, so a later reload doesn't reuse a stale one.
func take_arrival_point() -> StringName:
	var point := _arrival_point
	_arrival_point = &""
	return point
