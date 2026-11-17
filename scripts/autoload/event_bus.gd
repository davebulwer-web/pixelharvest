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

## Today's weather has changed (DECISIONS 046): each night, as the day turns,
## and when a game is started or loaded. GameState.weather has it, and
## GameState.forecast has tomorrow's. The farm and town swap their overlay,
## Daylight its tint, Audio the rain's loop.
signal weather_changed(weather_id: StringName)

## Lightning flashed in a storm and its thunder is due (only a look and a
## sound: scripts/weather_flash.gd). Audio plays the thunder.
signal thunder_rolled()

# --- Farming ----------------------------------------------------------------

signal tile_tilled(cell: Vector2i)
signal tile_watered(cell: Vector2i)

## Tilled soil went back to grass: bare soil left empty overnight (DECISIONS 045).
signal tile_cleared(cell: Vector2i)

## Weeds came up on a tile overnight, or were pulled up (E or the hoe).
signal weeds_sprouted(cell: Vector2i)
signal weeds_pulled(cell: Vector2i)

## Fertiliser went into the soil at `cell` (DECISIONS 058): `fertiliser_id`
## is the bag it came from (growth feed, mulch). Also announced with &"" when
## the soil loses it (it went back to grass, or something was put on it).
signal soil_fed(cell: Vector2i, fertiliser_id: StringName)

## The sickle swung at `cell` (DECISIONS 058), where a crop is ripe. GameState
## picks it into the bag, as E would, so the sickle's handler never touches
## the bag itself (a tool can't use the GameState autoload).
signal crop_cut(cell: Vector2i)

signal crop_planted(cell: Vector2i, crop_id: StringName)
signal crop_grew(cell: Vector2i, stage: int)
signal crop_harvested(cell: Vector2i, crop_id: StringName, amount: int)

## A crop was lost overnight. `cause` says why (DECISIONS 045):
## &"season" (the season turned and it can't grow in the new one),
## &"thirst" (left unwatered too many nights), &"crows" (taken by a crow) or
## &"frost" (couldn't take the cold, autumn's frost: DECISIONS 046).
signal crop_died(cell: Vector2i, crop_id: StringName, cause: StringName)

## The player dug up the crop at `cell` with the trowel (DECISIONS 048).
## `was_seed` is true if it hadn't come up yet: GameState gives the seed back.
signal crop_dug_up(cell: Vector2i, crop_id: StringName, was_seed: bool)

## Aphids landed on the crop at `cell` overnight, or were cleared from it
## (sprayed, or the season turned too cold for them; DECISIONS 048).
signal pests_spread(cell: Vector2i)
signal pests_cleared(cell: Vector2i)

## Overnight, a 3 × 3 block of ripe crops merged into one giant, held at
## `cell` (its front-left corner; DECISIONS 048).
signal giant_grew(cell: Vector2i, crop_id: StringName)

## A giant was picked, at `cell` (its front-left corner). Announced just
## before the crop_harvested that says what it gave (DECISIONS 049: Pip's
## giant pumpkin request counts these).
signal giant_harvested(cell: Vector2i, crop_id: StringName)

## Something wild was picked up (DECISIONS 052): a mushroom in the Woods.
## Pip's and Wren's requests and the day's summary can count these.
signal foraged(item_id: StringName, location_id: StringName)

## The axe chopped something (DECISIONS 053): `what` is &"thicket" (the
## farm's thicket or the Woods' undergrowth) or &"log" (a fallen log in the
## Woods), at `cell` in `location_id`. It gave `amount` of `item_id` (timber),
## which GameState puts in the bag; the farm and the Woods redraw the cell.
signal wood_chopped(location_id: StringName, cell: Vector2i, what: StringName, item_id: StringName, amount: int)

## Fishing (DECISIONS 054). The rod cast a line into `water` (&"pond",
## &"river", &"stream") at `cell` in the current location; the float waits
## `wait_multiplier` times as long as the rules say (a better rod, sooner).
## Fishing (the autoload) takes it from there.
signal line_cast(cell: Vector2i, water: StringName, wait_multiplier: float)

## Something bit: the float went under. Space now to strike.
signal fish_bit()

## Struck in time: a `fish_id` is on the line, and the reel bar is up.
signal fish_hooked(fish_id: StringName)

## A fish was landed: `size` cm, from `water` in `location_id`, and
## `through_ice` if it came up through a hole in winter's ice (DECISIONS
## 055). GameState has put it in the bag and the fish log already. Wren's
## and Pip's requests count these; the day's summary lists them.
signal fish_caught(fish_id: StringName, size: int, location_id: StringName, water: StringName, through_ice: bool)

## The fish on the line got away: too slow to strike, too much slack, or
## left too long without a pull.
signal fish_escaped(fish_id: StringName)

## A hole was cut in the ice at `cell` in `location_id` (DECISIONS 055). It
## stays open until the night freezes it over.
signal ice_hole_cut(location_id: StringName, cell: Vector2i)

# --- Cooking (DECISIONS 056) -------------------------------------------------

## A recipe was learned (a request's reward, or an unlock's: the workbench).
signal recipe_learned(recipe_id: StringName)
## A dish was cooked at the stove.
signal dish_cooked(recipe_id: StringName, dish_id: StringName)
## Something was made at the workbench (DECISIONS 063): `amount` of `item_id`.
signal item_made(recipe_id: StringName, item_id: StringName, amount: int)
## A dish was eaten, giving back `energy` (what it actually gave, after the
## maximum).
signal dish_eaten(dish_id: StringName, energy: float)

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

## Debris on the farm was cleared (DECISIONS 060): stones hoed, a stump dug
## out, brambles or nettles cut or pulled. `object_id` is what it was;
## GameState puts what it gives (stone, timber, fibre) in the bag. It was
## also announced as object_removed.
signal debris_cleared(cell: Vector2i, object_id: StringName)

## Something turned up while clearing debris at `cell` (DECISIONS 061): the
## find `find_id`, for the `nth` time. GameState has already given what it
## gives; the farm shows what it says.
signal found_while_clearing(find_id: StringName, cell: Vector2i, nth: int)

## A tile of an allotment job was done on the Lane (DECISIONS 062): on bed
## `plot` (1 to 8), the `work` (&"weed", &"water", &"dig") at `cell`. The
## Allotments service announces it; the job's request counts it.
signal allotment_worked(plot: int, work: StringName, cell: Vector2i)

## An object that makes something finished a batch overnight (DECISIONS 057):
## `amount` of `item_id` waits in it (honey in a bee hive) until collected.
signal object_made(cell: Vector2i, object_id: StringName, item_id: StringName, amount: int)

## The player took what an object made (E at a hive with honey in it), and
## it went into the bag.
signal object_emptied(cell: Vector2i, object_id: StringName, item_id: StringName, amount: int)

## The player spoke to someone. `npc_id` is the character's id (a shopkeeper's
## is its shop's id). Whatever should happen next — a conversation, a quest
## step — listens for this; the player doesn't know who it is talking to.
signal npc_talked_to(npc_id: StringName)

## The player read the notice board in town. The town shows what's on it;
## Stage 8's market days and requests can listen too and pin up their own.
signal notice_board_read()

## The player took on a request from someone in town (a QuestDef id).
signal quest_started(quest_id: StringName)

## Something counted towards a request in hand: it's now at `progress` of
## `needed` (DECISIONS 038). Deliveries count the bag, so they don't announce
## this; their giver's "?" and quest_completed say enough.
signal quest_progressed(quest_id: StringName, progress: int, needed: int)

## A request was handed in and its reward given.
signal quest_completed(quest_id: StringName)

## A request with a deadline ran out overnight, untouched but for the reward
## missed (DECISIONS 050). `title` is its name in the log, because an order's
## QuestDef is cleared away by the morning and couldn't be looked up then.
signal quest_expired(quest_id: StringName, title: String)

## Something opened up (an UnlockDef id), from a request's reward or the
## calendar overnight (DECISIONS 043). The day's summary lists it.
signal unlocked(unlock_id: StringName)

# --- Festivals (DECISIONS 059) ---------------------------------------------

## The farmer entered a festival's contest: handed `entry` over (the flower
## show's tulip), or signed up for the fishing contest ("a place").
signal festival_entered(event_id: StringName, entry: String)

## A contest the farmer entered has been judged: they came `place` (1 is
## first) and won `prize` (in words: "250g and a bird bath", or "").
signal festival_judged(event_id: StringName, place: int, prize: String)

## A festival's host gave the farmer its keepsake (lantern night's lantern).
signal festival_gift_given(event_id: StringName)

## Something the player should be told, in the HUD's message line.
signal message_posted(text: String)

# --- Meta -------------------------------------------------------------------

signal game_saved()
signal game_loaded()

## A new game was set up (first launch, or Ctrl+N), replacing whatever was
## in memory. Anything that keeps a running tally of the game in hand (the
## day's report) starts again.
signal new_game_started()
