extends Node
##
## EventBus — the global signal hub.
##
## Systems emit signals here describing what just happened. Other systems
## subscribe to the ones they care about. Nothing needs a direct reference to
## another system just to react to it.
##
## This is the single most important piece of the architecture for keeping the
## game extensible: a new feature subscribes to existing events instead of
## being stitched into existing code. See rule 2 in CLAUDE.md.
##
## Two rules:
##   1. Signals describe WHAT HAPPENED, never what should happen next.
##      Good: crop_harvested.  Bad: give_player_gold.
##   2. Signal names are past tense.
##
## Signals are declared here before they are used, as living documentation of
## what the game can react to. Some below are not emitted yet — the stage that
## introduces the system starts emitting them.
##

# --- Time -------------------------------------------------------------------

## A new day has begun. Season and year are indices into the calendar.
signal day_started(day: int, season: int, year: int)

## The player has gone to sleep, or run out of energy. Emitted before the
## day actually advances, so systems can settle up first.
signal day_ended(day: int)

## The clock moved on. `minutes` is the time of day in minutes after midnight
## (past midnight it keeps counting: 1 AM is 1500). Emitted every 10 minutes
## of game time (DECISIONS 035).
signal time_changed(minutes: int)

## The clock reached game_rules.tres day_end_minutes (2 AM) with the player
## still up. Emitted during the night, after they've been taken home, so the
## morning can say why they woke up there.
signal stayed_up_too_late()

## The season rolled over. Listeners re-theme tilesets and re-check crops.
signal season_changed(season: int)

## A calendar event (market day) is on today. Emitted each morning just
## after day_started, once per event (DECISIONS 037). Not emitted when a save
## is loaded: anything that needs to know asks GameState.events_today().
signal calendar_event_began(event_id: StringName)

# --- Farming ----------------------------------------------------------------

signal tile_tilled(cell: Vector2i)
signal tile_watered(cell: Vector2i)
signal tile_cleared(cell: Vector2i)

signal crop_planted(cell: Vector2i, crop_id: StringName)
signal crop_grew(cell: Vector2i, stage: int)
signal crop_harvested(cell: Vector2i, crop_id: StringName, amount: int)

## A crop died — wrong season, or left unwatered too long.
signal crop_died(cell: Vector2i, crop_id: StringName)

# --- Player and economy -----------------------------------------------------

signal energy_changed(current: float, maximum: float)
signal energy_exhausted()

signal gold_changed(amount: int, delta: int)
signal item_added(item_id: StringName, amount: int)
signal item_removed(item_id: StringName, amount: int)

## Something was bought from the shop. `cost` is the total paid.
signal item_bought(item_id: StringName, amount: int, cost: int)

## The player put produce in the shipping bin: `count` items, worth `value`
## gold when they sell overnight. Both are 0 if there was nothing to ship.
signal items_shipped(count: int, value: int)

## Overnight, the shipping bin was emptied and paid out `gold`. Emitted during
## the night (before day_started), only if anything was in the bin.
signal shipment_sold(gold: int)

## Produce was sold across a shop counter (not the shipping bin): `amount`
## of one item for `gold`, paid at once.
signal items_sold_to_shop(item_id: StringName, amount: int, gold: int)

## An upgrade was bought from the shop. `cost` is what was paid. Its effect
## has already happened by the time this is announced.
signal upgrade_bought(upgrade_id: StringName, cost: int)

signal tool_selected(tool_id: StringName)
signal tool_upgraded(tool_id: StringName, tier: int)

# --- World ------------------------------------------------------------------

signal location_changed(location_id: StringName)

## A field was bought and its thicket cleared. `plot_id` is the upgrade's id.
signal plot_unlocked(plot_id: StringName)

## Something was put down on, or picked up from, a farm tile (a sprinkler).
## Trees and the bin are part of the farm from the start and don't announce.
signal object_placed(cell: Vector2i, object_id: StringName)
signal object_removed(cell: Vector2i, object_id: StringName)

## The player spoke to someone. `npc_id` is the character's id (a shopkeeper's
## is its shop's id). Whatever should happen next — a conversation, a quest
## step — listens for this; the player doesn't know who it is talking to.
signal npc_talked_to(npc_id: StringName)

## The player read the notice board in town. The town shows what's on it;
## Stage 8's market days and requests can listen too and pin up their own.
signal notice_board_read()

## Something the player should be told, in the HUD's message line.
signal message_posted(text: String)

# --- Meta -------------------------------------------------------------------

signal game_saved()
signal game_loaded()
