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

## The season rolled over. Listeners re-theme tilesets and re-check crops.
signal season_changed(season: int)

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

signal tool_selected(tool_id: StringName)
signal tool_upgraded(tool_id: StringName, tier: int)

# --- World ------------------------------------------------------------------

signal location_changed(location_id: StringName)
signal plot_unlocked(plot_id: StringName)

# --- Meta -------------------------------------------------------------------

signal game_saved()
signal game_loaded()
