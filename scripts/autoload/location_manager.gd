extends Node
##
## LocationManager — moves the player between places (DECISIONS 004).
##
## The farm, the town and every shop are locations. The seam was built in
## Stage 2, well before the town, because the hard part of locations isn't the
## town, it's making sure nothing important lives in a scene that gets thrown
## away on the way out. It paid off: Stage 7 changed nothing here but three
## small lookups.
##
## How a trip works:
##   1. Something calls go_to(&"town", &"from_farm").
##   2. GameState.location is updated, so the move is part of saved state.
##   3. The current scene is freed and the new location's scene loaded.
##   4. The new scene, in its _ready, asks take_arrival_point() where to put
##      the player — the name of a Marker2D under its SpawnPoints node.
##   5. location_changed is announced.
##

## The farm's id. Named here because the farm and the farmhouse both need it.
const FARM_ID := &"farm"

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


## The location the player is in now, or null if GameState names one that
## game_rules.tres doesn't list.
func current() -> LocationDef:
	return _locations.get(GameState.location)


## Every location, in game_rules.tres order. The town uses it to find the
## buildings whose doors it should show.
func all() -> Array[LocationDef]:
	var result: Array[LocationDef] = []
	for location: LocationDef in _locations.values():
		result.append(location)
	return result


## Every location whose door is on `location_id`'s map (the town's shops, the
## farm's farmhouse), in game_rules.tres order. The map builds a Building for
## each, so a new building is data, never an edit to the map's code.
func buildings_on(location_id: StringName) -> Array[LocationDef]:
	var result: Array[LocationDef] = []
	for location: LocationDef in _locations.values():
		if location.outside == location_id and location.exterior != null:
			result.append(location)
	return result


## Why the player can't go into `location_id` right now, in words for the
## HUD, or "" if they can: a building that hasn't opened up yet (DECISIONS
## 043), or a shop outside its opening hours (DECISIONS 035). A door asks this
## before it takes the player through, and the building shuts its doorway.
func closed_message(location_id: StringName) -> String:
	var location: LocationDef = _locations.get(location_id)
	if location == null:
		return ""
	if not GameState.has_unlock(location.requires_unlock):
		if location.locked_message != "":
			return location.locked_message
		return "%s is shut." % location.display_name
	if location.shop == null:
		return ""
	var shop := location.shop
	if shop.is_open_at(GameState.minutes):
		return ""
	return "%s is closed. Open %s" % [shop.display_name, shop.hours_text()]


## Called once by a location scene as it opens. Returns the arrival point and
## clears it, so a later reload doesn't reuse a stale one.
func take_arrival_point() -> StringName:
	var point := _arrival_point
	_arrival_point = &""
	return point
