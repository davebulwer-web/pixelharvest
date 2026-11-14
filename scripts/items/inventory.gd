class_name Inventory
extends RefCounted
##
## Inventory — a bag of items and how many of each, in the order they arrived.
##
## The player's bag is one (GameState.inventory) and so is the shipping bin
## (GameState.shipping_bin). It holds ItemDefs, so it doesn't care whether
## something is a tool, seeds or produce.
##
## Order matters only for display: the hotbar shows the bag left to right in
## the order things were first picked up, so the hoe stays where you left it.
##
## There's no size limit and no slots yet. A bag that can fill up is a design
## question for later (it would make the bag an upgrade), not a technical one.
##
## Like FarmData, it's plain data — a RefCounted, not a node — so it lives in
## GameState and survives scene changes.
##

## Each entry is {"item": ItemDef, "count": int}. Never holds a count of 0:
## when the last one goes, the entry goes.
var _stacks: Array[Dictionary] = []

## Only the player's bag announces changes on EventBus. The shipping bin
## filling up isn't "the player gained an item".
var _announces: bool


func _init(announces: bool = false) -> void:
	_announces = announces


func add(item: ItemDef, amount: int = 1) -> void:
	if item == null or amount <= 0:
		return
	var stack := _find(item)
	if stack.is_empty():
		_stacks.append({"item": item, "count": amount})
	else:
		stack["count"] += amount
	if _announces:
		EventBus.item_added.emit(item.id, amount)


## Take `amount` out. Returns false and changes nothing if there aren't that
## many, so a caller can't spend items the player doesn't have.
func remove(item: ItemDef, amount: int = 1) -> bool:
	var stack := _find(item)
	if stack.is_empty() or stack["count"] < amount:
		return false
	stack["count"] -= amount
	if stack["count"] == 0:
		_stacks.erase(stack)
	if _announces:
		EventBus.item_removed.emit(item.id, amount)
	return true


func count(item: ItemDef) -> int:
	var stack := _find(item)
	return 0 if stack.is_empty() else stack["count"]


func is_empty() -> bool:
	return _stacks.is_empty()


## Every item held, in order. Pair with count() for the numbers.
func items() -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for stack in _stacks:
		result.append(stack["item"])
	return result


func clear() -> void:
	_stacks.clear()


func _find(item: ItemDef) -> Dictionary:
	for stack in _stacks:
		if stack["item"] == item:
			return stack
	return {}


# --- Saving ------------------------------------------------------------------
# Saved as a list of ids and counts, in order. Items are found again through
# ContentDB, so a save never holds anything but plain values.

func to_save() -> Array:
	var data: Array = []
	for stack in _stacks:
		data.append({"id": String(stack["item"].id), "count": stack["count"]})
	return data


## Rebuild from to_save()'s list. An item the game no longer has is dropped
## with a warning, so one removed crop can't stop a whole save loading.
static func from_save(data: Array, announces: bool) -> Inventory:
	var inventory := Inventory.new(announces)
	for entry: Dictionary in data:
		var item := ContentDB.item(StringName(entry["id"]))
		if item == null:
			push_warning("Save has an item '%s' the game doesn't know; it's been removed" % entry["id"])
			continue
		# Straight into the list rather than through add(): loading a game
		# isn't the player picking anything up, so nothing is announced.
		var amount := int(entry["count"])
		if amount > 0:
			inventory._stacks.append({"item": item, "count": amount})
	return inventory
