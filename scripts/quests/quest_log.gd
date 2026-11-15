class_name QuestLog
extends RefCounted
##
## QuestLog — which requests the player has taken on and finished, and the
## running count for each. It's the saved half of quests (GameState.quests);
## the Quests service is the half that listens, talks and pays out.
##
## Plain data, like Inventory: it lives in GameState and survives scene changes.
## Requests are kept in the order they were taken, so the log reads in order.
##

const ACTIVE := &"active"
const DONE := &"done"

## quest id -> {"state": ACTIVE or DONE, "progress": int}
var _entries: Dictionary = {}


## ACTIVE, DONE, or &"" if the request has never been taken.
func state(quest_id: StringName) -> StringName:
	return _entries[quest_id]["state"] if _entries.has(quest_id) else &""


func is_active(quest_id: StringName) -> bool:
	return state(quest_id) == ACTIVE


func is_done(quest_id: StringName) -> bool:
	return state(quest_id) == DONE


## What's been counted towards the request since it was taken.
func recorded(quest_id: StringName) -> int:
	return _entries[quest_id]["progress"] if _entries.has(quest_id) else 0


func start(quest_id: StringName) -> void:
	if not _entries.has(quest_id):
		_entries[quest_id] = {"state": ACTIVE, "progress": 0}


func add(quest_id: StringName, amount: int) -> void:
	if is_active(quest_id):
		_entries[quest_id]["progress"] += amount


func finish(quest_id: StringName) -> void:
	if _entries.has(quest_id):
		_entries[quest_id]["state"] = DONE


## The ids of the requests in hand, in the order they were taken.
func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _entries:
		if _entries[id]["state"] == ACTIVE:
			ids.append(id)
	return ids


func done_count() -> int:
	return _entries.values().filter(func(e: Dictionary) -> bool: return e["state"] == DONE).size()


# --- Saving ------------------------------------------------------------------
# Saved as {"quest id": {"state": "active", "progress": 3}, …} (save version 8).

func to_save() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _entries:
		data[String(id)] = {"state": String(_entries[id]["state"]), "progress": _entries[id]["progress"]}
	return data


## Rebuild from to_save()'s dictionary. A request the game no longer has is
## dropped with a warning, like an unknown item, so removing one can't stop a
## save loading.
static func from_save(data: Dictionary) -> QuestLog:
	var log := QuestLog.new()
	for key: Variant in data:
		var id := StringName(key)
		var entry: Variant = data[key]
		if ContentDB.quest(id) == null:
			push_warning("Save has a request '%s' the game doesn't know; it's been removed" % id)
			continue
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var state := StringName(entry.get("state", ""))
		if state != ACTIVE and state != DONE:
			push_warning("Save has request '%s' in an unknown state '%s'; it's been removed" % [id, state])
			continue
		# JSON keeps numbers as floats.
		log._entries[id] = {"state": state, "progress": int(entry.get("progress", 0))}
	return log
