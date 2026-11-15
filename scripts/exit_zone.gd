class_name ExitZone
extends Area2D
##
## ExitZone — a patch of floor that takes the player to another location the
## moment they step on it: the farm gate, a shop door, the doormat inside.
##
## Walk-in doors need no key press and no new player code: the zone watches for
## the Player entering, and asks LocationManager to make the trip. `arrival` is
## the name of the spawn point to appear at in the place on the other side.
##
## A door can be locked: a shop outside its opening hours (DECISIONS 035).
## Then the zone says so on the HUD and stays put; step off and on again to
## try once more.
##

@export var destination: StringName
@export var arrival: StringName = &""

## One trip per zone: stepping on it twice before the scene changes would
## ask for the trip twice.
var _used: bool = false


## Make a zone covering `rect` (in the parent's coordinates).
static func create(rect: Rect2, to: StringName, arrive_at: StringName = &"") -> ExitZone:
	var zone := ExitZone.new()
	zone.destination = to
	zone.arrival = arrive_at
	zone.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	zone.add_child(shape)
	return zone


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body is Player:
		return
	var closed := LocationManager.closed_message(destination)
	if closed != "":
		EventBus.message_posted.emit(closed)
		return
	_used = true
	# Deferred: we're inside a physics callback, and the scene is about to be
	# freed — which can't happen mid-physics.
	LocationManager.go_to.call_deferred(destination, arrival)
