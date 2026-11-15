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
## Deadlines and orders (DECISIONS 050): a request with a deadline also keeps
## the day it's due by ("due", a GameState.day_number), and one that ran out
## is EXPIRED. A request made from an OrderTemplate (Rosa's orders, the
## board's jobs) has no file to look up, so its entry also keeps what it was
## made of ("order": which pattern, item, count, gold, day), enough for the
## Quests service to build it again after loading. Orders that are finished
## or ran out are cleared away each morning (forget_old_orders), so the save
## doesn't grow a line a day forever; how many were done is kept as a number.
##

const ACTIVE := &"active"
const DONE := &"done"
const EXPIRED := &"expired"

## quest id -> {"state": ACTIVE, DONE or EXPIRED, "progress": int,
##              "due": int (0: none), "order": Dictionary (only for orders)}
var _entries: Dictionary = {}

## Orders (from templates) handed in, ever. Their entries are cleared away,
## so they're counted here.
var orders_done: int = 0


## ACTIVE, DONE, EXPIRED, or &"" if the request has never been taken.
func state(quest_id: StringName) -> StringName:
	return _entries[quest_id]["state"] if _entries.has(quest_id) else &""


func is_active(quest_id: StringName) -> bool:
	return state(quest_id) == ACTIVE


func is_done(quest_id: StringName) -> bool:
	return state(quest_id) == DONE


## What's been counted towards the request since it was taken.
func recorded(quest_id: StringName) -> int:
	return _entries[quest_id]["progress"] if _entries.has(quest_id) else 0


func is_expired(quest_id: StringName) -> bool:
	return state(quest_id) == EXPIRED


## The day (GameState.day_number) the request must be handed in by, or 0 if
## it has no deadline.
func due_day(quest_id: StringName) -> int:
	return _entries[quest_id].get("due", 0) if _entries.has(quest_id) else 0


## What an order was made of ({"template", "item", "count", "gold", "day"}),
## or an empty dictionary for a written request.
func order_of(quest_id: StringName) -> Dictionary:
	return _entries[quest_id].get("order", {}) if _entries.has(quest_id) else {}


## Take the request on. `due` is the last day it can be handed in (0: no
## deadline); `order` is what an order was made of (empty for a written one).
func start(quest_id: StringName, due: int = 0, order: Dictionary = {}) -> void:
	if _entries.has(quest_id):
		return
	_entries[quest_id] = {"state": ACTIVE, "progress": 0}
	if due > 0:
		_entries[quest_id]["due"] = due
	if not order.is_empty():
		_entries[quest_id]["order"] = order.duplicate()


func add(quest_id: StringName, amount: int) -> void:
	if is_active(quest_id):
		_entries[quest_id]["progress"] += amount


func finish(quest_id: StringName) -> void:
	if not is_active(quest_id):
		return
	_entries[quest_id]["state"] = DONE
	if _entries[quest_id].has("order"):
		orders_done += 1


## The request ran out of time: gone, with nothing lost but its reward.
func expire(quest_id: StringName) -> void:
	if is_active(quest_id):
		_entries[quest_id]["state"] = EXPIRED


## The ids of the requests in hand whose last day is `day_number` or earlier.
func overdue_ids(day_number: int) -> Array[StringName]:
	return active_ids().filter(func(id: StringName) -> bool:
		var due := due_day(id)
		return due > 0 and due <= day_number)


## Clear away orders that were handed in or ran out. Every morning: an
## order is never offered again after its day, so nothing needs them.
func forget_old_orders() -> void:
	for id: StringName in _entries.keys():
		if _entries[id].has("order") and _entries[id]["state"] != ACTIVE:
			_entries.erase(id)


## The ids of the requests in hand, in the order they were taken.
func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _entries:
		if _entries[id]["state"] == ACTIVE:
			ids.append(id)
	return ids


## Requests handed in: written ones still in the log, and every order ever.
func done_count() -> int:
	return orders_done + _entries.values().filter(func(e: Dictionary) -> bool:
		return e["state"] == DONE and not e.has("order")).size()


# --- Saving ------------------------------------------------------------------
# Saved as {"quest id": {"state": "active", "progress": 3}, …} (save version 8).
# Since version 14 an entry may also have "due" (a day number) and, for an
# order, "order" ({"template", "item", "count", "gold", "day"}); and the
# state may be "expired". orders_done is saved beside it by GameState.

func to_save() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _entries:
		var entry: Dictionary = _entries[id]
		var saved := {"state": String(entry["state"]), "progress": entry["progress"]}
		if entry.has("due"):
			saved["due"] = entry["due"]
		if entry.has("order"):
			saved["order"] = entry["order"].duplicate()
		data[String(id)] = saved
	return data


## Rebuild from to_save()'s dictionary. A request the game no longer has is
## dropped with a warning, like an unknown item, so removing one can't stop a
## save loading. An order is kept if its pattern (OrderTemplate) and its item
## are still in the game; the Quests service builds it again from that.
static func from_save(data: Dictionary) -> QuestLog:
	var log := QuestLog.new()
	for key: Variant in data:
		var id := StringName(key)
		var entry: Variant = data[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var order: Dictionary = entry.get("order", {}) if typeof(entry.get("order")) == TYPE_DICTIONARY else {}
		if order.is_empty() and ContentDB.quest(id) == null:
			push_warning("Save has a request '%s' the game doesn't know; it's been removed" % id)
			continue
		if not order.is_empty() and (ContentDB.order_template(StringName(order.get("template", ""))) == null
				or ContentDB.item(StringName(order.get("item", ""))) == null):
			push_warning("Save has an order '%s' for something the game no longer has; it's been removed" % id)
			continue
		var state := StringName(entry.get("state", ""))
		if state != ACTIVE and state != DONE and state != EXPIRED:
			push_warning("Save has request '%s' in an unknown state '%s'; it's been removed" % [id, state])
			continue
		# JSON keeps numbers as floats.
		log._entries[id] = {"state": state, "progress": int(entry.get("progress", 0))}
		if int(entry.get("due", 0)) > 0:
			log._entries[id]["due"] = int(entry["due"])
		if not order.is_empty():
			log._entries[id]["order"] = {"template": String(order["template"]), "item": String(order["item"]),
					"count": int(order.get("count", 1)), "gold": int(order.get("gold", 0)),
					"day": int(order.get("day", 0))}
	return log
