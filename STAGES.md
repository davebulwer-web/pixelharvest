# Pixel Harvest — stage plan

**Current stage: 25 — almanac and year review.** Session 1 (the almanac on L, the mayor's year review and title at lantern night, year 2's first content; DECISIONS 085, save version 26) is built, waiting for Dave to try it. Stage 24 (art: people and the UI) is complete: the code session and the art were tested and committed by Dave (2026-11-19), and the side tests that followed (cozy ground, calm cliffs, harbour, pack props and wood UI, forgiving E, furnished rooms and homes, Dave's scenery; DECISIONS 076-084) were all kept by Dave (2026-11-20 and 21). Stage 23 (art: the world) is complete: all five sessions tested and committed by Dave (2026-11-19). Stage 22 (the tavern and people on the move) is complete: both sessions tested and committed by Dave (2026-11-18). Before that, from Stage 22: session 2 (Nell's tavern, the Wheatsheaf: rumours, the chalkboard, darts night, hot meals; Nell, Dot and Tam's requests; homes for the mayor, Wren and Ivy and the town hall, the town grown to 48 × 32; evenings at the tavern; DECISIONS 068, no save change) is built, waiting for Dave to try it. Session 1 (weekdays, schedules, people who walk; DECISIONS 067) is tested and committed by Dave (2026-11-18). Stage 21 (the Cove) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-17). Stage 20 (early days) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-17). Stage 19 (the Lane and the bigger farm) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-17). Stage 18 (festivals) session 1 is tested and committed by Dave (2026-11-17); its session 2 and art are still open. Stage 17 (greenhouse, bees and late tools) is complete apart from its Pixellab art: session 2 (fertilisers, the sickle, the brass sprinkler; save version 19) tested and committed by Dave (2026-11-16). Stage 17 session 1 (the farm's old greenhouse, mended by Ivy's last request, with a plot inside that ignores seasons and weather; bee hives and honey; save version 18) is tested and committed by Dave (2026-11-16). Stage 16 (kitchen and cooking) is complete apart from its Pixellab art: tested and committed by Dave (2026-11-16). Stage 15 (fishing with Wren) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-16). Stage 14 (the Woods and foraging) is complete apart from its Pixellab art, which waits for an art session: both sessions tested and committed by Dave (2026-11-16). Stage 13 (questlines) is complete: both sessions tested and committed by Dave (2026-11-15); still to come from it are Ivy's Pixellab art and Dave playing a full year. Stage 12 (crops with rules) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-15). Stage 11 (hazards and weather) is complete: both sessions tested and committed by Dave (2026-11-15); pests and storm-flattening moved to Stage 12. Stage 10 (pacing and unlocks) is complete: Dave played the spring and the pacing looks good (2026-11-15). Stage 9 session 1 (feel) is built; its release half moved to Stage 20. Stages 10–20 come from `ROADMAP.md`, agreed by Dave on 2026-11-15: read it before starting any of them. The clock runs at 5 seconds per 10 game minutes since 2026-11-16 (DECISIONS 051).

Stages 0–3 are the real investment. Get them right and 4–9 are genuinely additive; rush
them and there'll be a rebuild around Stage 5. Realistically 20–30 sessions in total.

Model guidance: Opus where a wrong decision is expensive to unwind — architecture, the
first implementation of a pattern, hard debugging. Sonnet 5.5 once the pattern exists and
the work is more of the same. Haiku for mechanical bulk edits.

---

## Stage 0 — Project setup · 1 short session · Sonnet 5.5

- [x] `project.godot` with pixel-art settings (nearest filtering, 640×360, snapping)
- [x] Folder structure
- [x] `.gitignore` and `icon.svg`
- [x] `EventBus` autoload with the full signal vocabulary declared
- [x] `InputActions` autoload registering 10 actions
- [x] Placeholder `main.tscn` that proves the project runs
- [x] `CLAUDE.md`, `DESIGN.md`, `DECISIONS.md`, `STAGES.md`, `art/STYLE.md`
- [x] Verified: headless import and run, no errors
- [x] Dave confirms the project opens in Godot and F5 shows the banner
- [x] Git initialised, remote added, first commit pushed (2026-11-14)

## Stage 1 — Walking skeleton · 1–2 sessions · Opus

Built against generated placeholder art first, so code progress doesn't wait on asset
production. The real Pixellab sprite drops into the same slot with no code changes.

**1a — mechanics on placeholder art**

- [x] Placeholder player sprite sheet, 32×32, 4 directions × (2 idle + 4 walk)
- [x] Placeholder ground tileset, 16×16, in Harvest 32, plus a tree prop
- [x] `SpriteFrames` resource; `AnimatedSprite2D` with 4-direction idle and walk
- [x] `CharacterBody2D` player with movement and animation state
- [x] `TileMapLayer` with ground tileset and collision
- [x] `Camera2D` following the player, pixel-snapped, ~20×11 tiles visible
- [x] Y-sorting so the player passes behind tall objects
- [x] Verified in a rendered recording: animation switches correctly per direction,
      player stops dead against the tree trunk, sorts in front when below it and
      behind when above it
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**1b — real art**

- [x] Agree the character's look; generate in Pixellab from the `art/STYLE.md` template
- [x] Save the approved sprite as `art/reference.png` — the style anchor for everything after
- [x] Build `SpriteFrames` from Pixellab's JSON rather than assumed geometry
- [x] Verify against spec (size, frame grid, transparency, palette) and swap it in
- [x] Rebuild the palette from the art; every asset now sits exactly on it
- [x] Log the generation in `art/STYLE.md`
- [x] Verified in a rendered recording: 8-frame walk cycle plays in all four directions
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Left over for later:** `player_placeholder.png` is now unused and can be deleted
whenever convenient; the tree and ground tiles are still placeholder and get replaced
in Stage 6 alongside the seasonal tilesets.

**Why this stage first:** it proves the whole Pixellab → Godot pipeline end to end before
any game systems exist. If the art pipeline has a problem, this is the cheapest place to
find it.

## Stage 2 — Core loop and seams · 3–4 sessions · Opus

**Session 1 (2026-11-14) — data, tools, tilling and watering**

- [x] `FarmData` — authoritative tile state (`FarmTile` per cell), entirely separate from
      the tilemap; `FarmLayout` builds the starting farm; `main.gd` only draws it
- [x] `GameState` autoload — gold, day, season, energy, tools, the farm; starting values
      from `data/game_rules.tres`
- [x] Tool interface: `ToolDef` + `ToolAction` (DECISIONS 018); hoe and watering can act on
      the tile in front of the player, shown by an outline cursor
- [x] Energy charged per action, only when the action does something
- [x] `CropDef` resource and `data/crops/parsnip.tres` (DECISIONS 017)
- [x] Stopgap HUD: selected tool and energy
- [x] Verified headless and in a rendered recording: tilling, watering, tool switching,
      no-ops on path/pond/tree/cliff cost no energy
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Session 2 (2026-11-14) — plant, grow, harvest, sleep**

- [x] Seeds as a tool (`PlantAction`), unlimited until the inventory (DECISIONS 020)
- [x] Harvest a ready crop with E; regrowing crops drop back a stage and come again
- [x] `TimeSystem` — Enter sleeps, or energy at zero ends the day; watered crops advance
      one stage overnight, soil dries, energy refills
- [x] Crop sprites per growth stage (placeholder parsnip sheet,
      `assets/sprites/crops/parsnip_placeholder.png`), Y-sorted with the player
- [x] HUD shows the day; morning fades in; harvest message
- [x] Verified headless (energy-out ends the day after the last action lands; regrow
      timing) and in a rendered recording: till, water, plant, five days, harvest
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Session 3 (2026-11-14) — the seams**

- [x] `LocationManager` seam (farm only for now), `LocationDef` resources, boot scene,
      spawn points — see DECISIONS 004, 021
- [x] `SeasonTheme` swap hook, wired with one theme (spring) — see DECISIONS 005, 021
- [x] Verified: farm scene reloaded mid-game keeps tilled soil, crop, tool and energy, and
      places the player at the spawn point; a test second theme repaints the ground
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**The whole game in miniature.** Everything after this is content or convenience.

## Stage 3 — Save and load · 1 session · Opus

Session 1 (2026-11-14) — see DECISIONS 022.

- [x] Minimal `ContentDB` (id → `CropDef`/`ToolDef`) pulled forward from Stage 4
- [x] Versioned save file (`user://save.json`, JSON) with `save_version` and an upgrade chain
- [x] Serialise `FarmData` and `GameState` (gold, calendar, energy, tools, selected tool,
      location, whole farm). Inventory and upgrades don't exist yet; each joins the save
      with a version bump in Stages 4 and 5
- [x] Save at the end of every night, load on launch, F9 for a new game; F6 on the farm
      scene never saves
- [x] Deliberately broke the format (version 1 → 2: tool by id, terrain by name) and
      migrated `tests/saves/v1_example.json` through it
- [x] Verified headless: save/reload round trip, v1 upgrade, damaged / newer / incomplete
      saves set aside, unknown crop and tool dropped, F6 doesn't save, F9 leaves the file
      alone. Rendered recording: plant two tiles, sleep, relaunch — sprouts still there
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Early, not late.** Retrofitting versioning after there's a save worth keeping is misery.

## Stage 4 — Content pipeline and economy · 2–3 sessions · Opus, then Sonnet

Session 1 (2026-11-14) — see DECISIONS 023.

- [x] `CropDef` resource script, including `regrow_days` (done in Stage 2, DECISIONS 017);
      `sell_price` moved to the produce item
- [x] `ContentDB` loads crops and every item (tools, seeds, produce), lists the shop's
      stock, and checks content hangs together at startup, naming the file to fix
- [x] Convert the Stage 2 hardcoded crop to a resource (done in Stage 2, DECISIONS 017)
- [x] Inventory system: `ItemDef`, `Inventory`; the hotbar is the usable items in the bag;
      seeds are counted and used up
- [x] Shipping bin: E ships all produce, sold overnight, gold at dawn; generic
      `interactable` group for things E can use
- [x] Menu-based seed shop on B (replaced by the town in Stage 7); pauses the game
- [x] HUD: season, day, gold, energy, value waiting in the bin, hotbar with icons and counts
- [x] Five crops: radish, parsnip, potato, cabbage, green bean (regrowing)
- [x] Save version 3 (inventory replaces tools; bin added to old farms);
      `tests/saves/v2_example.json` added
- [x] Verified headless (over 30 checks: starting kit, seeds used up, buying, can't overspend,
      shipping, overnight sale, bean regrow, save round trip, v1 and v2 upgrades, bad saves,
      broken content reported) and in a rendered recording: harvest four crops, ship them,
      shop, buy, sleep, morning shows the sale
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Left over:** the four new crops, all item icons and the shipping bin are placeholder art
(generated locally, on palette). Real versions are a Pixellab job, from the cloud
environment that can reach it (DECISIONS 019), once Dave has approved the looks.

## Stage 5 — The incremental spine · 2–3 sessions · Opus to design, Sonnet to build

Session 1 (2026-11-14) — see DECISIONS 024.

- [x] `ToolDef` with tiers (`ToolTier`: name, energy, length × width); the cursor outlines
      every tile a swing will cover
- [x] Hoe and watering can at 1 → 3 → 9 tiles (wide, then great)
- [x] Energy upgrades: Packed lunch, Hearty breakfast, Farmer's stamina (+25, +25, +50)
- [x] Sprinklers (4 tiles) and big sprinklers (8 tiles): bought, placed with Space, picked
      up with E, water at dawn; `ObjectDef` resources replace the hardcoded object list
- [x] Plot unlocking: three fields start as thicket and are cleared when bought
- [x] `UpgradeDef` + `UpgradeEffect` resources; the shop gains an Upgrades column
- [x] Save version 4 (upgrades saved, max energy worked out); `tests/saves/v3_example.json`
- [x] Verified headless (78 checks: tiers and areas, energy charging, offers and
      prerequisites, fields, sprinklers overnight, pick-up, save round trip, v1/v2/v3
      upgrades, bad saves) and in a rendered recording: buy four upgrades, wide hoe, wide
      can, place a sprinkler, sleep
- [~] First balance pass: numbers set and reasoned (DECISIONS 024); needs Dave's play to
      judge whether the curve feels right
- [x] New game moved from F9 (the editor's pause key) to Ctrl+N
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

**Left over:** thicket, sprinklers and the energy/field icons are placeholder art.

## Stage 6 — Seasons made real · 2 sessions · Sonnet 5.5

Session 1 (2026-11-14) — mechanics, on placeholder art. See DECISIONS 025.

- [x] Calendar: 28-day seasons (`days_per_season` in game_rules.tres), year rollover;
      HUD shows "Spring · Day 5 · Year 1"
- [x] Crops gated by season (`CropDef.seasons`); seeds can't be planted out of season and
      grey out on the hotbar; the shop says when each crop grows
- [x] Out-of-season crops die on the night the season turns; the morning says how many
- [x] `SeasonTheme` resources for all four seasons; ground, trees and overlay swap on
      `season_changed`
- [x] Winter snow overlay (falling snow, `scenes/snowfall.tscn`)
- [x] Save version 5 (`day` is the day of the season); `tests/saves/v4_example.json`
- [x] Verified headless (50 checks: calendar, year rollover, planting gate, deaths and
      survivors at the turn, event order, re-theming, save round trip, v1–v4 upgrades,
      clamping, newer save refused) and in a rendered recording through all four seasons
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

Session 2 (2026-11-14) — real art, from the cloud environment that reaches Pixellab (DECISIONS 019, 026):

- [x] Real base ground tileset and tree (Pixellab), same atlas layout including the
      thicket column. See DECISIONS 026
- [x] Summer, autumn and winter tilesets via image-to-image from that base
- [x] Autumn and winter trees (snowy bin and sprinklers not done)
- [x] Palette 33 → 41 colours (snow, ice, autumn orange, olive); all new art on it
- [x] Verified: Godot 4.7.2 import clean, headless run clean, rendered all four seasons
- [x] Dave confirms the look on Windows and merges it (PR #3, 2026-11-14)

## Stage 7 — The town · 2–3 sessions · Sonnet 5.5

Session 1 (2026-11-14) — the town, three shops, doors and shopkeepers on placeholder art. See DECISIONS 027.

- [x] Town scene and transitions via `LocationManager`: a gate at the west end of the farm
      path, the town's east road leads back; walk-in `ExitZone` doors
- [x] Building exteriors and a shared shop interior (one scene, the `ShopDef` decides whose)
- [x] Seed shop, general store (also buys produce, 80%), blacksmith (sprinklers, tool upgrades)
- [x] Shopkeeper sprites and simple dialogue (a greeting a day, then the menu)
- [x] Shops are data: `ShopDef` + `LocationDef`; what a shop sells is a filter over `ContentDB`
- [x] B shop key removed; farming, harvesting and sleeping switched off away from the farm
- [x] Save version 6 (the farm gate); `tests/saves/v5_example.json`
- [x] Verified headless (46 checks: gate both ways, every shop door in and out, arrival
      points, dialogue then menu, buying, selling, shop stock and upgrade categories, no
      farming or sleeping in town, sleeping on the farm still works, a version 5 save
      upgraded and walked through the gate) and in a rendered recording of the whole trip
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

- [x] Real town art from Pixellab (2026-11-14, DECISIONS 028): three shop fronts, three
      shopkeepers, counter, shelf and the interior tileset, all on the 41-colour palette.
      Drop-in replacements for the placeholders, same sizes and doorways.
- Not seasonal: the shop fronts and interiors have no winter version; the town's ground and
  trees use the farm's seasonal art.

Session 2 (2026-11-14) — a designed town, townsfolk and a notice board, on placeholder art. See DECISIONS 029.

- [x] Designed town map (`TownLayout`): a paved square south of the road with a fountain,
      benches and lamps; flower beds and lamps along the shop fronts; a fenced flower
      garden; a path up to the pond; trees moved to frame it all
- [x] Decoration as `ObjectDef`s (fountain, bench, lamp post, flower bed, fence, notice
      board) placed from `TownLayout.OBJECTS`; winter has a frozen fountain and snowy beds
- [x] `CharacterDef` resources (`data/characters/`): Mayor Bramble in the square and Wren
      the angler by the pond; a different spot and a new line each day; E to talk
- [x] Notice board: the date and days left in the season (warns from three days out),
      what grows now and where to buy it, what grows next season
- [x] `ContentDB` loads and checks characters; no save change (version stays 6)
- [x] Verified headless (56 checks: every object stands, every door, the notice board and
      both townsfolk can be walked up to, talking and paging, notices in all four seasons
      and at the season's end, spots change by day, shop doors and keepers unchanged, farm
      gate both ways, a version 5 save still upgrades) and rendered in spring and winter
- [x] Dave confirms it plays correctly on Windows (2026-11-14)

- [x] Real art from Pixellab for every session 2 piece (2026-11-14, DECISIONS 030): fountain
      and frozen fountain, bench, lamp post, flower bed and snowed bed, fence, notice board,
      Mayor Bramble and Wren. Drop-in replacements, same sizes, feet/base on the bottom row.

**Not done / for a later session:** shop opening hours (done in session 4), townsfolk who
walk about.

**Grass variety (2026-11-15, DECISIONS 031):** grass tiles turned and mirrored per cell to
hide the repeat, plus eight small seasonal details per season (tufts, flowers, leaves, snow
pieces) in row 1 of each ground image. Then (DECISIONS 032) a calmer dirt path with its own
details, a cobbled town square, and a snow-covered winter thicket. Cosmetic only, no save change.

- [x] Dave confirms it looks right on Windows (2026-11-15)

Session 3 (2026-11-15) — the farmhouse and bed, on placeholder art. See DECISIONS 033.

- [x] Farmhouse on the farm, north of the path: a `LocationDef` with its door on the farm,
      built as a `Building` like the shops (`LocationManager.buildings_on`)
- [x] Inside: bed, table, rug, door back out (`farmhouse.tscn`, `scripts/farm/farmhouse.gd`)
- [x] E at the bed ends the day (`Bed`); Enter no longer sleeps, it says where the bed is
- [x] Every morning starts at home: running out of energy elsewhere takes you home first
      (`home_location` in game_rules.tres); a new game starts beside the bed
- [x] The house's ground is `BUILDING` terrain in FarmData: no hoeing, planting or sprinklers
- [x] Save version 7 (house cells cleared on old farms, sprinklers there back in the bag);
      `tests/saves/v6_example.json`
- [x] Verified headless (42 checks: new game in the house, footprint can't be worked, Enter
      does nothing, out the door and back, walls solid, bed ends the day and saves v7 at
      home, collapsing in the field wakes you at home with the bin's sale shown, town and
      shops unchanged, v6 and v5 saves upgrade and open in the house) and rendered
      (house in spring and winter, inside, going to bed)
- [x] Dave confirms it plays correctly on Windows (2026-11-15)

Session 3 art (2026-11-15) — real farmhouse art and the animated fountain. See DECISIONS 034.

- [x] Farmhouse exterior (80×64, door centred at the bottom), bed (16×32) and table (16×16)
      redrawn with Pixellab (pixflux, the placeholder as init image, palette as colour image)
- [x] Winter farmhouse with a snowy roof (`farmhouse_winter.png`, recoloured by script),
      worn in winter through `SeasonTheme.object_sprites` like the tree and fountain
- [x] The town fountain bubbles: Dave's 9-frame Pixellab animation, played by
      `SheetAnimation`; winter's frozen fountain stays still
- [x] Verified headless and rendered (house in spring and winter, inside, fountain in both)
- [x] Dave confirms the look on Windows and merges it (PR #8, 2026-11-15)

Session 4 (2026-11-15) — the clock and shop opening hours. See DECISIONS 035.

- [x] Dave chose a ticking clock (of three options): 6 AM to 2 AM, 10 minutes per 7 real
      seconds, stopped while the game is paused (shop menu, dialogue)
- [x] `GameState.minutes`; `TimeSystem` runs the clock and announces `time_changed`;
      numbers in game_rules.tres (`day_start_minutes`, `day_end_minutes`,
      `seconds_per_ten_minutes`, `late_warning_minutes`)
- [x] HUD shows the time after the date; a warning at midnight; at 2 AM you collapse and
      wake at home ("You stayed out too late"), the same night as the bed or no energy
- [x] Shop opening hours on `ShopDef` (`opens_at`, `closes_at`): seeds 9–5, general store
      8–8, blacksmith 10–4. A closed shop's door won't open and says when it does; after
      closing the keeper turns you away but you can walk out
- [x] Snag (Dave, 2026-11-15): at a closed shop the player walked into the doorway and
      vanished behind the building. The closed doorway is now solid; you stop in front
- [x] Notice board lists the opening hours; `Clock` formats times everywhere
- [x] No save change (version stays 7): the game saves at dawn, so loading starts at 6 AM
- [x] Verified headless (45 checks: clock ticks in tens and stops when paused, every shop's
      hours at the edges, closed door keeps you out and says why, open door lets you in,
      keeper greets then menu when open, turns you away after closing, leaving a closed
      shop, notice board hours, midnight warning, 2 AM ends the day at home with the
      message and a save, bed and no-energy still end the day and reset the clock, save
      still v7, load and a v6 save start at 6 AM) and rendered (closed door, closed keeper,
      midnight warning, waking at home)
- [x] Dave confirms it plays correctly on Windows (2026-11-15, committed)
- [x] Dave confirms the closed-door snag fix (2026-11-15)

Evening light (2026-11-15) — see DECISIONS 036.

- [x] Farm and town darken with the clock (golden at 6:30 PM, dusk at 8, night from 11);
      interiors stay lit; colours editable on `scenes/daylight.tscn`
- [x] Winter's chill moved into `SeasonTheme.light_tint` (one tint per scene)
- [x] Town lamp posts glow at night (`night_lights` group)
- [x] Verified headless (21 checks: tint by time, fades, lamps off by day and on at night,
      interiors untinted, winter tint, dawn after the night) and rendered through the
      evening in spring and winter
- [x] Dave confirms it looks right on Windows (2026-11-15)

**For later:** windows that glow at night. Townsfolk still stand in one spot all day.

## Stage 8 — Events and quests · 2–3 sessions · Sonnet, Haiku for bulk

Session 1 (2026-11-15) — calendar events and market day, on placeholder art. See DECISIONS 037.

- [x] `CalendarEvent` resource (`data/events/`); market day on day 3 and every 7 days after
      (days 3, 10, 17, 24 of each season); worked out from the date, not saved
- [x] `EventBus.calendar_event_began` each morning; HUD date and morning message say
      "Market day"; the notice board says it's today (with hours) or when the next one is
- [x] Market stalls (`StallDef`: a `ShopDef` + cell + picture) in the square, 8 AM – 2 PM,
      packed away after closing: Rosa buys produce at 125% paid now; Fennel sells rare
      seeds (strawberry, melon, pumpkin) found nowhere else (`ItemDef.sold_only_by`)
- [x] Shopkeeper talking moved into `ShopCounter`, shared by shop interiors and stalls
- [x] No save change (version stays 7)
- [x] Verified headless (68 checks: market days through the season turn, days until the
      next, who sells what, 125% price, stalls only on market day, walking up to a counter,
      greeting then menu at both stalls, not open yet / packed away at 2 PM / none when
      arriving late, mayor and notice board don't open a menu, indoor shops unchanged,
      the morning announcement, strawberry grows and regrows, save round trip) and rendered
      (square on market day, both menus, the notice, the evening, winter)
- [x] Dave confirms it plays correctly on Windows (2026-11-15, committed)

**Left over:** real Pixellab art for the two stalls, Rosa and Fennel, the three crops and
their six icons (all placeholder now).

Session 2 (2026-11-15) — requests (quests), on placeholder art. See DECISIONS 038.

- [x] `QuestDef` resources (`data/quests/`): who asks, a goal, their words, a reward (gold
      and items), and when it's offered (`first_day`, `seasons`, `on_event`, `requires`)
- [x] Goals are small scripts (`scripts/quests/`): bring items (`DeliverGoal`), harvest a
      crop (`HarvestGoal`), sell produce worth so much (`SellGoal`). The `Quests` autoload
      counts them from signals EventBus already had: no farming, shop or bin code changed
- [x] Three quest givers: Mabel the baker (new; parsnips, then potatoes, then an autumn
      pumpkin for a sprinkler), Pip (new; harvest 3 strawberries, asked on market day in
      spring) and the mayor (sell 200g of produce, from day 1)
- [x] Talk to them: they ask, remind you with your progress, and take it in and pay.
      "!" over someone's head means they have something to ask, "?" that you have it
- [x] J opens the request log (top right); the notice board says who wants a hand
- [x] Save version 8 (requests taken and finished); v1–v7 saves load with none taken
- [x] Verified headless (94 checks: plurals and reward text, who offers what on which
      day, one at a time, reminders with progress, ready message and markers, hand-in
      takes the items and pays, chains, seasons, market-day only, a real strawberry
      harvest and real bin and shop sales counted, the notice board, the town's talk,
      markers and log, save round trip, v1–v7 saves) and rendered (markers, Mabel
      asking, the log, "?" over Mabel, the hand-in, the notice)
- [x] Dave confirms it plays correctly on Windows (2026-11-15, committed)

**Left over:** real Pixellab art for Mabel and Pip (recoloured placeholders now).

Session 3 (2026-11-15) — decorations for the farm, on placeholder art. See DECISIONS 039.

- [x] Decorations are items you place like sprinklers: Space puts one on open grass, E
      picks it back up. They do nothing but look nice and cost no energy to place
- [x] `PlaceDecorationAction` marks an item as a decoration; `ShopDef.sells_decorations`
      decides who sells them. Marlow's general store does, cheapest first
- [x] Six decorations (`data/decorations/` + `data/objects/` + `scenes/decorations/`):
      fence 15g, hay bale 40g, flower bed 60g (snowed over in winter), scarecrow 150g,
      lamp post 250g (lights up at night like the town's), and a sundial that isn't sold
- [x] The sundial is a request reward: the mayor's second request, "The pride of the
      valley" (sell 1000g of produce, after his first), gives 100g and the sundial
- [x] No save change (version stays 8): placed decorations are farm objects by id, and
      carried ones are items, both of which the save already holds
- [x] Verified headless (114 checks: every decoration is an item that gives itself back,
      who sells what, buying and refusing, placing with Space at no energy cost, refused on
      the path, the doorstep, a crop or another object, placed on bare tilled soil, picked
      up with E and put down again, solid to walk into, fences in a row, the lamp dark by
      day and lit at night and on coming back at night, the flower bed in winter and
      spring, nothing watered overnight, save round trip, the mayor's chain and the
      sundial reward, v5–v7 saves still load) and rendered (farm by day, at night, in
      winter, Marlow's menu)
- [x] Dave confirms it plays correctly on Windows (2026-11-15, committed)

**Left over:** real Pixellab art for the scarecrow, hay bale and sundial, and the icons for
the scarecrow and lamp post (placeholders now; fence, flower bed and lamp reuse town art).

Session 4 (2026-11-15) — difficulty, chosen at new game, on placeholder UI. See DECISIONS 040.

- [x] `DifficultyDef` resources (`data/difficulties/`): starting gold, sell prices, shop
      prices, energy per swing and grow times, each a multiplier. Relaxed, Standard (all
      1.0, the game as it was) and Hard, listed in `game_rules.tres`
- [x] Each multiplier applied in the one place that owned the number: Economy's prices
      (bin, counters, stall, upgrades), the starting gold, the tool swing, crop growth
      (rounded along the way, never under a day a stage; the shop shows the scaled days)
- [x] "How would you like to play?" menu at first launch (no save) and on Ctrl+N; starts
      on Standard, says what each one changes; Esc from Ctrl+N goes back to the game
- [x] Save version 9 (difficulty by id); v1–v8 saves load as Standard;
      `tests/saves/v8_example.json` added
- [x] Verified headless (133 checks: the three in order and the default, the boot menu
      appears with no save, pauses, starts on Standard, can't be escaped, arrows and
      Enter pick Hard, 50g, hard prices for seeds, produce, upgrades, the stall's rate on
      top, the bin overnight, buying, relaxed and standard prices, every crop's standard
      times unchanged and hard totals right, real growing at three speeds, a real hoe
      swing in the farm scene costs 125%, save round trip, unknown id, v1–v8 saves,
      writes v9, Ctrl+N opens over the farm paused, doesn't stack, Esc keeps the game,
      Ctrl+N to Relaxed gives 200g and wakes at home, shop shows the hard days) and
      rendered (the menu at first launch, and over the farm)
- [x] Dave confirms it plays correctly on Windows (2026-11-15, committed)

**Stage 8 art (2026-11-15, DECISIONS 041):** real Pixellab art for the stalls, Rosa, Fennel,
Mabel, Pip, the three crops with their icons and seed packets, and the decorations.
- [x] Dave confirms the look in game (2026-11-15)

**Left over:** the difficulty menu is placeholder UI until Stage 9's
title screen. The numbers are first guesses for Stage 9's balance pass.

**The architecture's exam.** If quests need changes to the farming code, something went
wrong earlier.

## Stage 9 — Feel · 1 session · Sonnet 5.5

Was "feel, balance and release". On 2026-11-15 Dave agreed the content roadmap
(`ROADMAP.md`): the game needs its content before balancing is worth doing, so the release
half (title screen, settings, save slots, balance pass, export) moved to Stage 20.

- [x] Sound effects and music
- [x] Particles, screen shake, harvest pops — the juice
- [x] Day-end summary screen

Session 1 (2026-11-15) — sound, music, juice and the day's summary. See DECISIONS 042.

- [x] `Audio` autoload plays a sound for each EventBus event (19 sounds in
      `data/audio/sound_bank.tres`), pitch varied a little, once per frame, not overnight
- [x] Music per location (`LocationDef.music`): a farm tune and a town tune; shops and
      the farmhouse carry their outside's tune on; crossfades between them
- [x] `Music` and `SFX` buses (`default_bus_layout.tres`); M mutes everything until the
      settings screen
- [x] All sounds and both tunes made by `art/build_sounds.py` (synthesised, no samples)
- [x] `FarmEffects`: dirt, water, leaf and dust bursts; the harvest pops up out of the
      ground; camera jolts on harvest and collapse (`ScreenShake`); crops and the bin
      squash and stretch
- [x] The HUD shows "+40g" / "-15g" under the purse as gold comes and goes
- [x] `DayReport` keeps the day's tally; `DaySummary` shows it each morning on black
      before the fade-in (Space, E or Enter); cleared by loading or a new game
- [x] No save change (version stays 9)
- [x] Verified headless (94 checks: every sound loads, both tunes loop, who plays which
      tune, the farmhouse and shops carry the tune on, no door sound at launch, the door
      sound, till/water/plant/harvest/ship/nope/coins sounds, one sound per frame,
      unknown sound silent, particles appear and free themselves, the crop squashes and
      springs back, the harvest pop, the camera shakes and settles at zero, the gold
      float, M mutes and unmutes, the tally of harvest, planting, watering, spending,
      the bin, sales and rewards, the summary after a night, after collapsing in the
      field, paused under it, early key ignored, Space and E close it, "Saved" after,
      quiet day, a fresh tally next day, none after loading a save or a new game, the
      town tune and the shop carrying it, a clean quit) and rendered (dirt and water
      bursts, the harvest pop, the gold float, the summary, a quiet day)
- [ ] Dave confirms it plays (and sounds) right on Windows

---

## Stages 10–20 — the game on top of the engine

Agreed by Dave on 2026-11-15. The detail (the year's arc, every questline, the crop list,
hazards, what art each needs) is in `ROADMAP.md`; each stage below names its sections.
Playtest checkpoints: Dave plays one spring after Stage 10, and a full year after Stage 13.
Stages 14–19 can be reordered.

## Stage 10 — Pacing and unlocks · 2 sessions · Opus

ROADMAP sections 3 and 4.

**Session 1 (2026-11-15) — unlocks, shop stock and the first week (DECISIONS 043)**

- [x] Unlocks: `UnlockDef` in `data/unlocks/`, a saved list of names (`GameState.unlocks`);
      `QuestDef.reward_unlocks`; `requires_unlock` on items, upgrades, requests and locations
- [x] Calendar unlocks (`UnlockDef.on_day`) open overnight; the forge opens on spring day 8
- [x] Shops show only unlocked stock: Hollis starts with parsnip and radish; potatoes after
      the mayor's first request, green beans on summer day 1, cabbage on autumn day 1
- [x] The first week rewritten: the mayor's "first pull" opener (then his 200g welcome),
      Mabel from day 5, Pip on market days
- [x] The morning summary announces what opened and who has something new to ask; the
      notice board pins up what opens in the coming week
- [x] Save version 10; old saves get every unlock (they had everything open)
- [x] Verified: a scripted run through spring days 1–15, checking what's offered each
      morning (61 checks), old saves v1–v9, and rendered shots of the shut forge, the
      mayor's request, the summary and Hollis's shelves
- [x] Dave confirms it plays correctly on Windows (tested and committed 2026-11-15)

**Session 2 (2026-11-15) — people who arrive, and Brann's test (DECISIONS 044)**

- [x] `requires_unlock` on characters (someone appears) and calendar events; Mabel now
      arrives on spring day 5 (`mabel_arrives`) and isn't in town before
- [x] Shopkeepers as request givers (`giver` = a shop id), with the "!" and "?" over them;
      a shopkeeper only asks once their shop is open to you
- [x] Brann's first request, "Brann's test" (sell 300g, from day 8) → `great_tools` (great
      hoe and can) and `north_field_deed` (Marlow's north field, and so the fields after it)
- [x] Season-end warning in the morning summary as well as on the notice board; the mayor
      mentions the old bridge (a line only)
- [x] Verified: a scripted run through spring days 1–9 (66 checks: who's in town, who
      asks, the summary's news, the forge's markers, the unlocks, a gated test event,
      old saves v1–v9) and rendered shots of Brann's "!", his request and the menu after
- [x] Dave confirms it plays correctly on Windows (2026-11-15)
- [x] Dave plays one spring to judge the pacing: "Pacing looks good" (2026-11-15)

Moved to Stage 13 (they need its new goal kinds): Hollis's line ("one of every spring
crop" is a ship-variety goal) and the mayor's bridge request (a donate-gold goal).

## Stage 11 — Hazards and weather · 2 sessions · Opus, then Sonnet

ROADMAP section 7.

**Session 1 (2026-11-15) — thirst, weeds, crows and the scarecrow (DECISIONS 045)**

- [x] Thirst: a crop unwatered 2 nights wilts (tinted), a 3rd and it dies; watering perks
      it up; ripe crops never go thirsty; the summary warns what will die tonight
- [x] Weeds from spring day 6 (`weeds_arrive`): on tilled soil and grass beside crops, at
      most 8 a night; stop growth; E pulls (1 energy) or the hoe digs out; **fibre** item;
      bare soil sometimes reverts to grass
- [x] Crows from spring day 15 (`crows_arrive`): with more than 16 unguarded crops they
      may take 1–2 a night; a crow stands on the spot in the morning and flies off as you
      come near; the scarecrow guards a radius of 8
- [x] `data/hazard_rules.tres` (HazardRules) holds every number; `hazard_multiplier` and
      `thirst_kills` on DifficultyDef (Relaxed 0.5 and no thirst deaths, Hard 1.5)
- [x] Save version 11 (weeds and dry nights on tiles); `tests/saves/v10_example.json`
- [x] Verified: 85 scripted checks (thirst on Standard and Relaxed, weeds before and after
      day 6, caps per difficulty, hoe and E, crows with and without a scarecrow, a full
      night through TimeSystem, save round trip, old saves v1–v10) and rendered shots
- [x] Dave confirms it plays correctly on Windows (tested and committed 2026-11-15)

**Session 2 (2026-11-15) — weather and frost (DECISIONS 046)**

- [x] `WeatherDef` in `data/weather/`: sunny, rain, storm, heatwave, snow, frost. What each
      does is switches on the file (waters the farm, thirst per dry night, keeps crows
      away, kills tender crops) plus its overlay, tint and sound loop
- [x] Odds per season on `SeasonTheme.weather_odds` (spring sunny 6 / rain 3; summer
      sunny 6 / rain 1 / storm 1 / heatwave 2; autumn sunny 5 / rain 3 / storm 2; winter
      sunny 1 / snow 1) and weather fixed by date on `fixed_weather` (spring day 1 sunny,
      autumn day 28 frost)
- [x] Tomorrow's weather is chosen a day ahead and is never wrong: in the morning summary
      and on the notice board; today's is on the HUD's top line
- [x] Rain and storm water every tilled tile in the morning; a heatwave makes an unwatered
      crop wilt after one night; crows stay away after a storm
- [x] Frost on autumn day 28 kills crops that can't grow in winter a night early, warned
      from day 25 on the board and in the summary (parsnips and cabbages survive it)
- [x] Rain and storm overlays (falling drops; lightning flashes and thunder in a storm),
      grey or warm tints through Daylight, a rain loop (quieter indoors), `thunder` sound;
      winter's snowfall now falls only on snowy days
- [x] Save version 12 (today's weather and the forecast); `tests/saves/v11_example.json`
- [x] Verified: 178 scripted checks (odds over 10,000 draws, fixed days, rain watering,
      heatwave thirst on Standard and Relaxed, storm and crows, frost and its warnings,
      save round trip, old saves v1–v11, overlays, the rain loop indoors and out, a whole
      year of nights) and rendered shots
- [x] Dave confirms it plays correctly on Windows (tested and committed 2026-11-15)
- [x] Save version 11 (session 1), 12 (session 2)
- [ ] Pixellab: weeds (4 seasons), crow, aphids

Moved to Stage 12, because each needs something it adds: pests (aphids, autumn day 1; the
roadmap's counter is flowers nearby, and flowers are a Stage 12 crop rule) and the storm
flattening tall unfenced crops (corn, sunflower and trellis crops are Stage 12's).

## Stage 12 — Crops with rules · 2 sessions + art · Opus, then Sonnet

ROADMAP section 6.

**Session 1 — rules, storms, the first wave** (2026-11-15, DECISIONS 047, no save change)

- [x] New CropDef rules: bunches (`harvest_max`), trellis (`solid`), perennial,
      overwintering (`plant_seasons`, `rests_in`), hardy (`needs_water`), water-loving
      (`near_water`), weather-loving (`loves_weather`), seed-returning (`seed_chance`),
      tall; flowers as `ItemDef.tags`
- [x] From Stage 11: storms flattening tall unfenced crops (`WeatherDef.flattens_tall_crops`,
      `ObjectDef.shelters_radius` on the garden fence)
- [x] First wave of 8 crops (spring onion, pea, rhubarb, garlic, sunflower, watercress, corn,
      kale) on placeholder art; Hollis's catalogue by season and unlock (new `hollis_winter`)
- [x] Save version: unchanged (12): nothing new is saved
- [x] Verified in the sandbox: headless import and run clean, 385 harness checks, rendered
      farm in summer and winter, the player stopped by a pea trellis
- [x] Dave confirms it plays correctly on Windows (tested and committed 2026-11-15)

**Session 2 — pests, giants, the rest** (2026-11-15, DECISIONS 048, save version 13)

- [x] From Stage 11: aphids from autumn day 1 (unlock `pests_arrive`): they stop a crop
      growing and spread to its neighbours; flowers within 2 tiles slow them; the cold
      clears them. Pest spray at Marlow's (20g a dose)
- [x] The trowel: digs up a crop on purpose (a seed not yet up goes back in the bag); in
      the starting kit, and given to older games by the save upgrade
- [x] Giant pumpkin and melon (a ripe 3 × 3 block, 15% a night, gives 15); the apple tree
      (Fennel's 600g sapling, 2 × 2, hardy, perennial, 28 days then 3 apples every 3)
- [x] The other nine crops of ROADMAP 6.2 as data: tulip, tomato, chilli (heatwave-loving),
      blueberry, beetroot, cranberry, leek, Brussels sprouts, snowdrop; green bean a tall
      trellis crop at 25g. Chilli is at Fennel's until Hollis's line (Stage 13)
- [x] Save version 13 (aphids, giants, the trowel); `tests/saves/v12_example.json`
- [x] Verified in the sandbox: headless import and run clean, 163 harness checks (aphids'
      odds and flowers over 400 tries, the trowel, giants and their covered tiles, the
      tree through a year, saves v1–v12, shops, a real autumn of nights), rendered farm
      with a giant, trees and aphids, the player stopped by the giant
- [x] Dave confirms it plays correctly on Windows (tested, committed and pushed 2026-11-15)
- [ ] Pixellab: crop strips, icons and seed packets for all 17 new crops; the apple tree
      (4 seasons); two giant sprites; aphids, trowel, pest spray

## Stage 13 — Questlines · 2 sessions · Sonnet (Haiku for bulk text)

ROADMAP section 5.

**Session 1 — the lines and Ivy** (2026-11-15, DECISIONS 049, no save change)

- [x] New goal kinds: give gold (`DonateGoal`), bring any of (`DeliverAnyGoal`), bring one
      of each (`DeliverEachGoal`, in place of "ship variety"), grow a giant (`GiantGoal`,
      new EventBus `giant_harvested`). Forage and catch are wired up in Stages 14–15
- [x] Every line that can be done today, as data: the mayor's bridge (500g → `woods_bridge`,
      before the pride of the valley); Hollis's spring, summer and autumn sets (early
      catalogues, rhubarb crowns and chilli move to his shelves); Mabel's summer tarts and
      winter leek pies; Pip's giant pumpkin; Ivy's autumn basket and snowdrops
- [x] Ivy, arriving on autumn day 3 (`ivy_arrives` on her CharacterDef), by the ruined
      glasshouse behind the general store; placeholder art for both
- [x] Save version: unchanged (13)
- [x] Verified in the sandbox: headless import and run clean, 65 harness checks (every new
      request offered on its day, handed in and paid; the bridge's gold; one-of-each and
      any-of hand-ins; a real giant pumpkin grown and picked; Ivy's arrival; Hollis's and
      Fennel's shelves; a half-paid bridge through a save; saves v1–v12), rendered town with
      Ivy, the glasshouse and the request log
- [x] Dave confirms it plays correctly on Windows (tested and committed 2026-11-15)

**Session 2 — repeatable requests** (2026-11-15, DECISIONS 050, save version 14)

- [x] Deadlines (`deadline_days` on a request: it runs out overnight, no penalty but the
      lost reward; the request log, reminders and the morning summary say when, and what ran out)
- [x] Order patterns (`OrderTemplate`, `data/orders/`): requests made fresh each day from a
      list of items, picking only what's in season and on sale, paying a multiple of the bin
- [x] Rosa: her first crate (8 vegetables, any mix, market day from spring day 10) opens her
      market orders (`rosa_orders`): three to choose from each market day, 150% of the bin,
      due by the next market day
- [x] The notice board's daily job from spring day 8 (`board_jobs`): one a day for Marlow,
      Mabel, Brann (fibre) or the mayor (flowers), due that night, handed in at the board,
      which wears a "!" or "?" like a person
- [x] The dialogue box can ask a question with answers to pick (W/S, E; Esc says no)
- [x] Save version 14 (deadlines, orders, orders handed in); `tests/saves/v13_example.json`
- [x] Verified in the sandbox: headless import and run clean, 539 harness checks (a board job
      every day for a year, in season and under its caps; the same offers however often asked;
      taking, reminding, handing in, turning down, running out through real nights; Rosa's
      crate and orders in every season; an order through a save and load; a written request
      with a deadline; the question box's keys; saves v1–v13), rendered Rosa's choice, the new
      request, her menu after, the board's job and the request log with due days
- [x] Dave confirms it plays correctly on Windows (committed and pushed as "Stage 13b", 2026-11-15)
- [ ] Pixellab: Ivy (and the ruined glasshouse)
- [ ] Dave plays a full year

Waiting for later stages: Ivy's glasshouse restoration (timber, 1,500g and a fish → the
greenhouse; Stages 14, 15, 17), Brann's sprinkler and sickle lines (14, 17), Wren's line
(15), Mabel's kitchen lessons (16), Pip's biggest fish and snowman (15, 18–19), the mayor's
harvest fair and year review (18, 19). Pip's mushroom hunt came in Stage 14.

## Stage 14 — The Woods and foraging · 2 sessions + art · Opus, then Sonnet

ROADMAP sections 8 and 9. Reverses DESIGN.md's "no foraging" (updated 2026-11-15).

**Session 1 — the bridge, the Woods and foraging** (2026-11-16, DECISIONS 052, no save change)

- [x] A river along the top of the town; the pond path carries on up beside the pond to
      the bridge. Broken (walking up to it says why) until the Woods open
- [x] The Woods open on summer day 1 once the mayor's bridge is paid for, or the morning
      after it's paid for if that's later (`woods_open`, a calendar unlock that `needs`
      `woods_bridge`); the board pins it up a week ahead, the morning summary announces it
- [x] The Woods (48 × 32): five glades joined by paths, a stream down the east side with a
      footbridge, undergrowth at the glades' edges (for session 2's axe), close-set trees
      everywhere else; the seasons' ground and trees; its own tune
- [x] Forage (`ForageDef`, `data/forage/`): 14 kinds over the four seasons (mushrooms,
      berries, flowers, nuts, holly, pine cones; worms on rainy days). Each morning 10 spots
      among the glades and path edges get something, picked by weight; E picks it up, free
      of energy; picked spots stay picked until morning
- [x] Pip's mushroom hunt (autumn, once the Woods are open): a chanterelle, a penny bun and a
      puffball → 200g
- [x] Wren's third spot moved off the new path (to 30, 6); the mayor's bridge request
      names the river at the top of town
- [x] Save version: unchanged (14). Nothing new is saved: the forage follows from the date
- [x] Verified in the sandbox: headless import and run clean, 3,671 harness checks (when the
      Woods open, paid early, late or never, and through a loaded save; the board's notice;
      a year of forage days: the same spots however often asked, ten a day, all in season,
      worms only in the rain, every kind turns up; every forage spot reachable on foot;
      walking up to the broken bridge, over the whole one into the Woods and back; picking
      up with E, staying picked after a trip out, gone by morning; Pip's hunt; passing out
      in the Woods; saves v1–v13), rendered the Woods in summer, autumn and winter and the
      bridge broken and whole
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-16)

**Session 2 — the axe and timber** (2026-11-16, DECISIONS 053, save version 15)

- [x] The axe: at Marlow's from spring day 8 (`axe_on_sale`), 150g, 4 energy a swing. It
      chops the farm's thicket a tile at a time for 1 timber (the ground becomes grass: a
      slow, cheap way into a field, which stays on sale while any thicket is left)
- [x] In the Woods: the undergrowth (1 timber a tile; grows back when the season turns)
      and 3 fallen logs a day (3 timber each), placed by the date like forage, never on
      forage or in anyone's way. The axe is the first tool that works off the farm
      (`ToolAction.can_use_away`/`apply_away`, asked of the Woods)
- [x] Timber (2g at the bin); wood chips and a chop sound (`art/build_sounds.py`)
- [x] Brann's sprinkler line: sprinklers now wait for it. **The sprinkler design**
      (summer day 5: 20 timber + 200g → a sprinkler, and sprinklers on his shelf);
      **Better pipes** (summer day 19: 40 timber + 600g → a big sprinkler, and big
      sprinklers on his shelf). New goal kind `CommissionGoal` (items and a fee)
- [x] Ivy's **glasshouse frame** (autumn or winter, after her basket: 50 timber → 300g and
      the unlock `glasshouse_frame`, for Stage 17's restoration to follow on from).
      Wren's worms wait for fishing (Stage 15)
- [x] "20 timber", "12 fibre": names that stay the same in the plural
- [x] Save version 15 (undergrowth cleared this season); older games keep sprinklers on
      sale (both of Brann's sprinkler requests ticked off); `tests/saves/v14_example.json`
- [x] Verified in the sandbox: headless import and run clean, 192 harness checks (the axe's
      day on Marlow's shelf and nobody else's; chopping farm thicket with Space, its cost,
      walking onto it, tilling it, a whole field chopped taking it off sale, saved; the
      Woods' undergrowth and logs chopped with Space, staying chopped after a trip out,
      new logs next morning, undergrowth kept through a save and back at the season's
      turn; too tired to chop; a year of log days: three a day, the same however often
      asked, off the forage, apart, and every forage spot and log reachable; both of
      Brann's requests and Ivy's, gold and timber taken, rewards and shelves; saves
      v1–v14), rendered the farm with a field half chopped and the Woods with logs and
      cleared undergrowth
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-16)

**Art**

- [ ] Pixellab: woods tileset (4 seasons), bridge (whole and broken), footbridge, 14 forage
      icons, axe, timber, fallen log

## Stage 15 — Fishing with Wren · 1–2 sessions + art · Opus

**Session 1 — the rod, the bite and the reel** (2026-11-16, DECISIONS 054, save version 16)

- [x] The fishing rod (`FishAction`): Space facing water casts, 2 energy. The farm's pond,
      the town's pond and river, the Woods' stream (`water_at` on the town and the Woods;
      the tile cursor shows where it would cast). Frozen in winter: the rod greys out
- [x] The minigame (`Fishing` autoload, `FishingLine` look): the float waits, goes under
      with a "!" (Space to strike), then the reel bar (Space with the marker in the green;
      three slack pulls and it's gone). E reels in; going anywhere reels in. The farmer
      stands still while the line is out; the clock keeps running
- [x] Fish as data: 15 `FishDef`s in `data/fish/` (water, place, seasons, hours, weather,
      weight, size, fight); every number of the minigame in `data/fishing_rules.tres`
- [x] Bait (halves the wait); the fish log (how many of each, and the biggest); "Caught"
      in the morning summary; cast, bite and splash sounds (`art/build_sounds.py`)
- [x] Wren's line, parts 1–2: **Wren's worms** (summer day 2, once the Woods are open:
      5 worms → the rod) and **Something for supper** (catch 3 fish → 10 bait, and bait
      at Marlow's). New goal kind `CatchGoal` (any fish, one kind, one water, a size)
- [x] Save version 16 (the fish log); `tests/saves/v15_example.json`
- [x] Verified in the sandbox: headless import and run clean, 141 harness checks (the data:
      something biting in every water, season and hour; hours and weather rules; casting
      at the farm's pond, the town's pond and river, the Woods' stream; no cast on land or
      in winter, and no energy taken; standing still and the hotbar locked while fishing;
      strike, reel and land; too slow, too soon, three slack pulls, left too long, E, and
      walking away; bait; a natural cast played in real time; Wren's two requests, the
      rod, the bait and Marlow's shelf; `CatchGoal`'s kinds; the summary row; the log
      saved and loaded; saves v1–v15), rendered the float, the bite and the reel bar at
      the farm's pond and the town's
- [x] Dave confirms it plays correctly on Windows (committed as "Stage fishing", 2026-11-16)

**Session 2 — the ice and the rest of Wren's line** (2026-11-16, DECISIONS 055, no save change)

- [x] Ice fishing: in winter, Space with the rod on the ice cuts a hole (the cast's 2
      energy, the chop sound); Space at the hole fishes through it, slower (×1.5). Facing
      up, the hole goes a tile further so the hat doesn't hide it. Holes freeze over in
      the night (never saved); `fish_caught` says `through_ice`
- [x] Lures (`LureDef`, kept, never used up, bait stays in the tin): Wren's winter lure
      (winter, ×0.5) and Pip's spinner (spring to autumn, ×0.75)
- [x] The fine rod: a tier of the rod (×0.6 wait), given by a request
      (`QuestDef.reward_upgrades`; `UpgradeDef.gift_only` keeps it off Brann's shelf)
- [x] Wren's line, parts 3–4: **The river fish** (from summer day 15: a fish from the
      Woods' stream → the fine rod) and **Ice and patience** (winter: a fish through the
      ice → the winter lure). Part 5 (the legendary fish) is year 2
- [x] The summer contest hook: `fishing_contest` on summer day 14 every year, and Wren's
      one-day request (a fish of 25 cm or more from the town pond → 300g). The festival
      proper (rivals, judging) is Stage 18
- [x] **Pip's biggest fish** (a fish of 40 cm or more → Pip's spinner)
- [x] Ivy's restoration, parts 2–3: **The glass** (1,500g → `glasshouse_glazed`) and
      **Ivy's first planting** (autumn: pumpkin, cranberry, beetroot and any fish → 500g
      and `glasshouse_restored`, which Stage 17's greenhouse should wait for).
      `DeliverEachGoal.and_one_of` ("and a fish")
- [x] The notice board: Wren's fish jobs (`board_wren`, 1–3 of a fish biting this season)
- [x] Verified in the sandbox: headless import and run clean, 85 harness checks (the data;
      the rod usable in winter; cutting a hole in the town pond by pressing Space, its
      energy, its picture; casting through it, the bite, strike and reel, the catch marked
      through the ice and a winter fish; bait and lure, the fine rod and the spinner in the
      wait; holes freezing overnight, still open after a trip to the Woods and back; the
      farm's pond, facing right and up; the contest on its day and its rules; Wren's river
      fish and fine rod; ice and patience; Pip; Ivy's glass and planting, the cheapest fish
      handed in; the board's fish in summer and winter; save and load), rendered the hole,
      the float through it and the farm's pond in winter
- [x] Dave confirms it plays correctly on Windows (committed and pushed as "Stage 15b", 2026-11-16)

**Art**

- [ ] Pixellab: 15 fish icons, rod, bait, bobber, ice hole, winter lure, spinner

## Stage 16 — Kitchen and cooking · 1 session + art · Sonnet

Energy food only (narrows DECISIONS 006; no selling chains).

**Session 1 — the stove, recipes and eating** (2026-11-16, DECISIONS 056, save version 17)

- [x] Recipes as resources: `RecipeDef` in `data/recipes/` (the dish, particular things,
      and "any fish / any mushroom / any 3 fruit" by tag, the cheapest going in first);
      a new `fruit` tag on eight fruits
- [x] Dishes are ToolDefs with an `EatAction` in `data/dishes/`: ten of them, 30 to 70
      energy, never sold. On the hotbar like seeds; Space eats one anywhere (the farm,
      town, shops, the Woods), up to the day's maximum; not when already full.
      `ToolAction.used_on_self()`
- [x] Cook at the farmhouse: a stove by the back wall (cold until the kitchen opens:
      E says Mabel could teach you). E at a lit stove opens the cooking menu: every
      recipe known, what goes in and what you have, Space cooks one, Esc leaves. Free
      and instant
- [x] Mabel's kitchen lessons (after the tarts, summer day 15 on, summer or autumn: a
      tomato, a green bean, a potato and some fruit → the farmhouse kitchen, tomato
      soup, potato and bean hash, fruit crumble). Her leek pies (winter) now also give
      her recipe book (six more); Wren's river fish teaches grilled fish.
      `QuestDef.reward_recipes`
- [x] Saved: the recipes known and how often each was cooked (`recipes`, save version
      17). v16 → v17 gives the recipes of those two requests if already finished
- [x] Sounds: a sizzle at the stove, a munch when eating (art/build_sounds.py
      `build_cooking`)
- [x] Verified in the sandbox: headless import and run clean, 116 harness checks (the
      data; eating with Space on the farm and in a shop, full, capped, the last one
      leaving the hotbar, the farm untouched; Mabel's lessons offered on summer day 15
      and not before, the reward text, the kitchen and three recipes, the cheapest fruit
      handed in; cooking, the missing text, the cheapest fruit and fish going in; the
      recipe book; E at the lit stove opening the menu, pausing, Space cooking, Esc
      closing; the cold stove; save and load; saves v1–v16, and v16 with the leek pies
      done), rendered the stove lit, the menu and a dish on the hotbar
- [x] Dave confirms it plays correctly on Windows (committed as "Stage 16", 2026-11-16)

**Art**

- [ ] Pixellab: stove (lit and cold), ten dish icons

## Stage 17 — Greenhouse, bees and late tools · 2 sessions + art · Sonnet

**Session 1 — the greenhouse and bees** (2026-11-16, DECISIONS 057, save version 18)

- [x] The farm's old greenhouse, west of the farmhouse: broken and shut from the start
      (`LocationDef.locked_exterior`), mended by Ivy's fourth request, **A glasshouse of
      your own** (after her first planting: 30 timber and 800g → `farm_greenhouse` and
      five strawberry seeds). A snowy roof in winter
- [x] Inside: an 8 × 6 plot, dug over, with a walkway round it (`GreenhouseLayout`). A
      second FarmData (`GameState.greenhouse`, `under_glass`): every tool, seed,
      sprinkler, hive and the trowel work in it; any seed goes in whatever the season;
      no rain, frost, storms, heatwave, crows, aphids or weeds; nothing dies at the
      season's turn; thirst still counts. `GameState.plot_here()`,
      `tool_usable_here()`; `greenhouse.gd` extends `main.gd`
- [x] Bee hives (Marlow's, 500g, from summer day 1): placed like a sprinkler; a jar of
      honey every 3 nights from spring to autumn (all year under glass), two with a
      flower within 4 tiles (a flowering crop or a flower bed). E collects (a jar shows
      over a full hive), E at an empty hive picks it up. Honey sells for 80g; the
      morning summary says when there's honey. `ObjectDef.makes`, `FarmData.run_makers()`
- [x] Save version 18 (the greenhouse's plot; honey in the making). v17 → v18 clears the
      greenhouse's cells on older farms and gives back what stood there;
      `tests/saves/v17_example.json`
- [x] Verified in the sandbox: headless import and run clean, 159 harness checks (the
      layout and the footprint on a new farm; the shut door and broken picture; Ivy's
      request, its cost and reward, the picture mended at once; walking in; strawberries
      planted in winter with Space, and not on the farm; watering, the wet soil drawn;
      the walls untouched by the hoe; nights in the greenhouse, no rain inside, growing to
      ripe in winter, the thirst warning; the season's turn killing nothing; harvesting
      with E; hives on sale only at Marlow's from summer; placing, three nights, the
      flower bed's bonus, a full hive waiting, collecting, picking up, sleeping in winter,
      working under glass, a tulip's bonus; save and load; saves v1–v17, and v17's
      greenhouse cells given back), rendered the broken and mended greenhouse (and in
      winter), the plot planted, a full greenhouse in winter and the honey jar over hives
- [x] Dave confirms it plays correctly on Windows (committed and pushed as "Stage 16a", 2026-11-16)

**Session 2 — late tools** (2026-11-16, DECISIONS 058, save version 19)

- [x] Fertilisers (`FertiliserDef`, a ToolDef with a `FertiliseAction`): Space on tilled
      soil puts a bag in, and the soil keeps it through harvests until it goes back to
      grass or something is put on it (a picture of it lies on the soil). **Growth feed**
      (Marlow's, 40g, from spring day 22): seeds sown in it come up at once, a stage
      ahead (a parsnip in 3 nights, not 4). **Mulch** (Ivy's autumn basket now gives ten
      and puts it on Marlow's shelf, 25g): watered soil stays wet a night longer. Both
      work in the greenhouse
- [x] The sickle (`SickleAction`): Space cuts weeds (fibre) and picks ripe crops, leaving
      unripe ones. Brann's **Sickle work** (after better pipes, from autumn day 5: 30
      fibre → the sickle); the wide sickle (3 in a row, 400g) and great sickle (3 × 3,
      1200g) at his forge
- [x] The brass sprinkler (24 tiles): Brann's last request, **The brass sprinkler**
      (after the sickle, winter from day 10: 3 velvet shanks and 2500g → one, and more
      on his shelf at 2000g)
- [x] Save version 19 (fed soil on a tile); v18 → v19 gives Ivy's mulch to games that had
      finished her autumn basket; `tests/saves/v18_example.json`
- [x] Verified in the sandbox: headless import and run clean, 137 harness checks (the
      data and the shelves by date; feeding with Space, its cost, not twice; fed and plain
      parsnips side by side, 3 nights against 4; feed kept after harvest; a seed just sown
      moved on and dug up for its seed; no feed on a growing crop; feed gone with the soil
      or under a sprinkler; the greenhouse; mulch with Space, wet two nights, rewatered,
      saved; Brann's sickle request by date and order, its reward and shelf; the sickle
      on weeds, ripe and unripe crops with Space; the great sickle's 3 × 3 for 4 energy;
      a giant picked once; the sickle in the greenhouse; the brass request only in
      winter, gold and shanks taken, the shelf; the brass sprinkler placed with Space,
      watering all 24 tiles, picked up with E; Ivy's basket giving mulch; save and load;
      saves v1–v18), rendered fed, mulched and plain soil on the farm and in the
      greenhouse, the brass sprinkler's wet square and the great sickle's cursor
- [x] Dave confirms it plays correctly on Windows (committed and pushed as "Stage 17", 2026-11-16)

**Art**

- [ ] Pixellab: greenhouse (outside, broken, winter, inside), hive, honey, sickle,
      fertiliser, brass sprinkler

## Stage 18 — Festivals · 1–2 sessions · Sonnet

**Session 1 — the four festivals** (2026-11-16, DECISIONS 059, save version 20)

- [x] Festivals are `CalendarEvent`s with a host (who stands at the festival all day), a
      contest (`ContestDef`: a rule, rivals, prizes, judged at a set time), a keepsake
      and decorations for the day; the `Festivals` autoload runs them
- [x] **Spring flower show** (spring 24, the mayor, judged 2 PM): your best flower, +10
      points for each flower bed on your farm (up to 5); 1st 250g and a bird bath
- [x] **Summer fishing contest** (summer 14, Wren at the pond, judged 2 PM): sign up, then
      the biggest fish from the town pond; 1st 400g and an angler's cup. Replaces Wren's
      one-day request (its file is deleted by hand)
- [x] **Autumn harvest fair** (autumn 21, the mayor, judged 3 PM): your best crop by value;
      1st 500g and the harvest fair cup
- [x] **Lantern night** (winter 28, the mayor): lanterns round the square, and a paper
      lantern (it glows) for your farm
- [x] Notice board and morning summary say when judging is; the night's summary lists
      your place
- [x] Save version 20 (the festival log, for the year review); `tests/saves/v19_example.json`
- [x] Verified in the sandbox: headless import and run clean, 106 harness checks (the
      dates; hosts and their spots; no flowers, then the best three offered with the
      flower beds' points; turning it down; entering, the tulip taken, the waiting line;
      judging at 2 PM and not before; the prize and the log; results read out; same dice
      same day; the notices; the contest needing a rod, signing up, only town-pond fish
      after signing up counting, a later fish not; signed up with nothing; the fair's
      choices (no honey or fish), judged at the day's end; the lantern given once;
      decorations; save and load; saves v1–v19), rendered the square on flower show day,
      the mayor's question and results, the pond on contest day, the fair, lantern night
      and the prizes on the farm at night
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

**Session 2 (if wanted)**

- [ ] "A giant pumpkin wins the fair outright" (needs a giant counted in the log, or a
      giant item)
- [ ] Anything Dave wants changed after playing a festival (rivals' scores, prizes, places)

**Art**

- [ ] Pixellab: festival decorations (flags, show tables, contest sign, lanterns), the
      trophies (bird bath, angler's cup, harvest fair cup, paper lantern)

## Stages 19–26 — a bigger world and a fuller early game

Agreed by Dave on 2026-11-17: `ROADMAP.md` section 13 (13.6 is the stage table). They
replace the old Stage 19 (almanac, year review, life in town) and Stage 20 (balance and
release): "life in town" moved into Stage 22, the rest of the old 19 is Stage 25 and the
old 20 is Stage 26. The font and UI theme, and the portraits, can run alongside in an art
thread; building art waits for Stage 19's size rule, walk cycles for Stage 22.

## Stage 19 — The Lane and the bigger farm · 2 sessions · Opus

ROADMAP 13.2 and 13.3 (#1, #2). Placeholder art at the new building size; no Pixellab.

**Session 1 (2026-11-17) — ways out as data, the Lane, the farm grows (DECISIONS 060, save version 21)**

- [x] Exits are data: `ExitDef` (where it leads, the gap's cells, where you arrive) on
      `LocationDef.exits`, built by `Exits`; the farm, the Lane, the town and the Woods
      use it (the town's bridge to the Woods stays its own, as it changes with the unlock)
- [x] **The Lane** (64 × 24) between the farm and the town: the lane itself, hedgerows
      both sides with gaps, the allotments (fenced beds, for Stage 20's odd jobs), a
      stream with a ford, trees, and a signpost where the cliff path to the Cove will go
      (shut until Stage 21). Farm gate → Lane → town; it plays the farm's tune
- [x] **Hedgerow forage** from day 1: 6 spots a morning along the lane's verges, with
      the existing `ForageDef`s (`found_in` gains `lane`): primroses and wild garlic,
      elderflower and new wild raspberries, blackberries, hazelnuts and new sloes, holly
      and new rosehips
- [x] **The farm grows to 48 × 32.** The old 30 × 20 stays at the same cells; the new
      ground east and south is overgrown: stones (the hoe; 2 stone), stumps (the axe; 3
      timber), brambles (E, 4 energy, or the sickle; fibre), nettles (E, 3 energy, or the
      sickle; fibre), and a few trees. Debris is an `ObjectDef` with `clears_to`; a tool
      says what it clears (`ToolAction.clears`). New item: stone
- [x] Save version 21: the farm's new ground and cliffs, laid exactly as a new game's;
      `tests/saves/v20_example.json` (the v19 example brought up by the real v20 build)
- [x] Verified in the sandbox: headless import and run clean, 304 harness checks (the
      new farm's size, border, gate and old cells; debris on new ground only; clearing
      with each tool and by hand, energy, what each gives, too tired, not from town; trees
      not clearable; save round trip; saves v1–v20 upgraded, new ground matching a new
      game's, v20's old cells kept; the Lane's forage in all four seasons; walking farm →
      Lane → town → Lane → farm and Woods → town, arriving at the right spots; the
      signpost; picking hedgerow forage; a night's sleep and a v21 save), rendered both
      ends and the middle of the Lane, the allotments, the signpost, the farm's new ground
      and the town's east end
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17: "feels much more
      like a world now")

**Session 2 (2026-11-17) — finds, the building size, Pip's and Dot's (DECISIONS 061, save version 22)**

- [x] Finds while clearing (`FindDef`, data/finds/): five pages of the old farmer's
      notebook, a rusty tool head (Brann fits a handle for 50g from day 8: the old
      farmer's axe), an old seed tin each season, the cover of a buried well (leaves the
      old well standing); rolled from the cell and the day, at most one a day, shown in a
      dialogue box on the farm
- [x] The building size rule (art/STYLE.md): door opening at least 24 × 36 px in the
      middle of the bottom row, buildings about 1.5 × the old, varied roofs; `Building`
      handles even widths (the doorway on two whole cells)
- [x] The Lane's buildings as exteriors at the new size (placeholder, 128 × 96): Pip's
      family's thatched cottage (north gap) and Dot's catslide shed and yard with her cart
      (south gap); their doors say who lives there (`LocationDef.door_words`)
- [x] Travel time measured walking: farmhouse door → town square 40 game minutes
      (20.8 real seconds); left for Stage 26's look at the clock
- [x] Save version 22 (finds); `tests/saves/v21_example.json`
- [x] Verified in the sandbox: headless import and run clean, 484 harness checks (the
      finds' order, days, seasons, debris kinds, limits, dice and pages; a simulated
      spring of clearing; the seed tin's seeds; the tool head, its unlock and Brann's
      request start to finish; the well left standing; save round trip; saves v1–v21; the
      buildings' footprints, doorways and door words; the old buildings unmoved; no trees
      on the plots; walking up to both doors and along their paths; the walk to town), and
      rendered a find's dialogue after a real hoe swing, the old well, Pip's cottage with
      the farmer at the door, and Dot's yard
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

## Stage 20 — Early days · 2 sessions · Opus, then Sonnet

ROADMAP 13.3 (#3, #4, #7, #8, #9) and the first fortnight rewritten. Split in two on
2026-11-17: session 1 the time-and-energy jobs on the Lane (Opus: a new shape of request),
session 2 the workbench, where to sell and the bakery (Sonnet: patterns that exist).

**Session 1 (2026-11-17) — odd jobs at the allotments, Dot's errands (DECISIONS 062, no save change)**

- [x] Requests can be handed to someone other than who asked (`QuestDef.hand_in_to`) and
      be due by a time of day (`QuestDef.due_minute`), running out there and then; a goal
      can come with something to carry (`on_taken`/`on_expired`) or finish itself the
      moment it's done (`finishes_itself`)
- [x] Order patterns of two new kinds: `ErrandTemplate` (Dot's parcels) and `JobTemplate`
      (allotment jobs); a pattern can be `always_up` beside the place's others
- [x] **Dot** at her gate on the Lane from day 1 (placeholder sprite). Day 1: a letter for
      the mayor (15g, opens her daily errands). Then two errands a day to choose from: a
      parcel, letter or flour sack to someone about that day, by noon, 2, 4 or 6 PM, 20–35g
      on delivery; a shopkeeper only by a time their shop is open. Late: gone, and the
      parcel goes back to Dot
- [x] **Odd jobs at the allotments**, chalked on the holders' slate by their gate: weed a
      plot (4–8 weeds: E, the hoe or the sickle), water a plot before noon (the can), dig
      over a plot (the hoe); one of each a day (no weeding or watering in winter), each on
      a different bed, all three can be done one after another; paid on the spot. The beds
      show the work wanted, a tile outline shows where the tool will act, and walking off
      and back keeps what's done (`Allotments` service)
- [x] No save change: jobs and errands are due the day they're taken and the game saves in
      the morning, so none is ever in a save (Stage 20 session 2 takes save version 23)
- [x] Verified in the sandbox: headless import and run clean, 999 harness checks (the
      first errand start to finish; 59 days of errands: same twice, different people,
      about, shops open, pay; taking, delivering, running out at the time and overnight,
      the parcel taken back, too late to offer, declining; jobs: three in spring on three
      beds, digging only in winter, no watering after noon, cells, looks, energy by hand,
      paid on the spot, the others still up, running out, mornings clear; in the Lane
      scene: Dot and the slate by E, the hoe, E and the sickle on weeds, the can and the
      axe not, leaving and coming back; the letter handed to the mayor in town; save round
      trip; saves v1–v21), and rendered Dot at her gate, both her choices, the slate's
      jobs, the beds being weeded, watered and dug, and the request log
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

**Session 2 (2026-11-17) — the workbench, where to sell, the bakery (DECISIONS 063, save version 23)**

- [x] **The workbench** by the farmhouse's east wall, one leg short: E with 3 stones props it
      level and teaches the old farmer's plans (fence, hay bale, scarecrow). A plan is a
      `RecipeDef` made at the workbench (`made_at`, `item`, `taught_by_unlock`), known and
      saved with the dishes; the stove's menu doubles as the "Plans you know" menu
- [x] Nine plans from stone, timber and fibre; six taught by people as rewards on requests
      that already exist (Brann: stone wall; Pip: bird box; Ivy: flower bed, mulch, log
      pile; Wren: bait). New decorations: stone wall, bird box, log pile. Nothing made for
      profit
- [x] **Where to sell:** every buyer pays less once it has had plenty of one thing that day,
      back to full by morning (`DemandDef`: the bin 40 then down to 60%; Marlow 20 then down
      to 50%; Rosa 15 then 60%; Mabel 6 then 50%). The shop menu shows "(plenty today)";
      the HUD says when the bin has had plenty. Buyers can be choosy (`ShopDef.buys_tags`)
- [x] **Mabel's bakery** (96 × 96, between Marlow's and the forge), shut until spring day 5,
      then 7 AM – 2 PM: bread roll, cheese scone, fruit loaf, pasty (+20 to +60 energy,
      22–55g); she buys fruit, honey and pumpkins at 110%
- [x] Save version 23: the workbench on the farm (beside it if its cell is in use), plans
      for requests already done; `tests/saves/v22_example.json`
- [x] Verified in the sandbox: headless import and run clean, 226 harness checks (the nine
      plans and the ten dishes; the bench placed once, not tillable; mending with too few
      and enough stones; the first plans; making fences, a scarecrow, a flower bed with any
      flower; unknown plans refused; the stove still waits for the kitchen; reward text and
      a request teaching a plan; the demand sums; Marlow, Rosa, the bin and Mabel flooding
      separately and resetting by morning; Mabel refusing parsnips; the bakery locked,
      stocked, its hours, buying and eating a roll; a made wall picked back up; save round
      trip; saves v1–v22, the v22 bench moved past a crop and a sprinkler; a night with the
      bin paid and a v23 save), walked into the bakery locked and unlocked, and rendered
      the bench broken and mended, its menu before and after making fences, the bin's
      "plenty" message, the town with the bakery, the bakery's counter before and after
      plenty, Marlow's "(plenty today)" and the morning summary
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

## Stage 21 — The Cove · 2 sessions · Opus, then Sonnet

ROADMAP 13.2 and 13.3 (#5, #6). Split in two on 2026-11-17: session 1 the place and its
tides (Opus: a new kind of time window), session 2 Tam, sea fishing and crab pots (Sonnet:
fishing and requests exist). Session 1 needed no save change, so session 2 takes save
version 24.

**Session 1 (2026-11-17) — the Cove, its tides, the beach and the rockpools (DECISIONS 064, no save change)**

- [x] **The Cove** (56 × 36, `cove.tres`, `scripts/cove/`): the coast road from the town's
      west edge to the harbour; the quay with the old lighthouse, Tam's fish shed and the
      tide board; the pier; a breakwater; the beach; cliffs with the cliff path through
      them up to the Lane (the Lane's path now runs on past the signpost to its bottom
      edge); Rosa's cottage above the road. The three buildings are homes seen from
      outside (placeholder, at the new size). It plays the town's tune
- [x] **Tides worked out from the clock** (`Tides`, `data/tide_rules.tres`): low water
      every 12 h 25 min from 10:20 AM on spring day 1, so twice a day and 50 minutes later
      each day; out for 90 minutes either side. No save, no dice
- [x] **The shore the tide uncovers:** wet sand, a rocky shelf full of pools and a sand bar
      out to an islet, sea (solid) while the tide's in. The Cove redraws it as the tide
      turns, says so, and puts anyone still out there back on the strand line
- [x] **Sea forage:** 5 spots a day on the strand line (seashells, sea glass, seaweed;
      samphire in summer; driftwood on stormy days, picked up as 2 timber), and 8 in the
      rockpools, only while the tide's out (shrimps, mussels, winkles, shore crabs in
      summer and autumn, oysters in autumn and winter). `ForageDef.at_low_tide`, `gives`;
      `LocationDef.low_tide_forage_per_day`. The Woods' and the Lane's forage unchanged
- [x] Today's low tides on the notice board, in the morning summary and on the harbour's
      tide board (which also says what the tide's doing now)
- [x] Verified in the sandbox: headless import and run clean, 12,188 harness checks (the
      tides for 112 days: one or two lows a day, a period apart, 50 minutes later each
      day, out exactly 90 minutes either side, about a quarter of the day, the texts; the
      Woods' and the Lane's forage identical to before for a year in three weathers; the
      Cove's forage every day of a year in three weathers: counts, cells, seasons,
      driftwood only in storms, every kind seen, the same twice; picking driftwood and a
      shrimp; the map: both arrivals, every strand spot at any tide, every rockpool at low
      tide only, the shore above each, the pier, the tide board, the buildings' doors and
      plots, the trees; the Lane's cliff path and the town's west gap; the notice board and
      the summary; in the scene: the shore drawn at high and low, the pools' forage out and
      back, picking from a pool, the player put ashore as the tide came in, picked spots
      staying picked after a trip to town, the tide board, the doors' words; walking the
      coast road both ways and the cliff path both ways, down onto the shelf at low tide,
      stopped by the sea at high tide and at the pier's edge; a night's sleep from the
      Cove and a save round trip), and rendered the road's end, the harbour, the beach and
      the shelf at high and low tide, the sand bar, the tide board's message, the cliff
      path, driftwood after a summer storm, the Cove in winter, the Lane's cliff path and
      the town's west end, and the whole Cove at both tides
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

**Session 2 (2026-11-17) — Tam, sea fishing and crab pots (DECISIONS 065, save version 24)**

- [x] **Tam** on the quay from spring day 7 (`tam_arrives`; placeholder sprite): a
      `CharacterDef` with a counter of his own (`CharacterDef.counter`, a `ShopDef`), so
      talking to him is a shop counter's conversation (`ShopCounter.serve(shop, giver,
      lines)`): his requests, then what he buys. He buys fish and anything from the sea
      (`buys_tags` fish, sea) at the bin's price, paid now (Marlow pays 80%); 15 of a kind
      at full price, then down to 50%. Dot's errands can now be to Tam
- [x] Tam's requests: bring 3 rockpool finds → **his handline**; from day 10, catch 3
      fish from the sea → 50g, a crab pot and its plans; then 3 brown crabs → 200g
- [x] **Sea fishing**: the handline is a `FishAction` limited to the sea (`waters`); the rod
      fishes it too. `CoveLayout.water_at(cell, tide_out)` gives &"sea" beside the pier,
      the quay and the breakwater. The sea never freezes; the tide sets the wait (×0.7 in,
      ×1.4 out: `FishingRules`); the fine rod's speed is the rod's only
- [x] **Eleven sea fish** (placeholder icons): mackerel, pollack, sea bass (high tide
      only: `FishDef.only_at_high_tide`), whiting, cod, plaice, dab, garfish, ballan
      wrasse, gurnard, conger eel (after dark); something bites in every season
- [x] **Crab pots**: a plan at the workbench (3 timber, 5 fibre), lowered with Space off
      either side or the end of the pier (`SetPotAction`, `CoveLayout.pot_cells`), baited
      from the bag (winkles, Wren's bait, mussels, shrimps); E the next day hauls it up
      (2 energy): shore crab, brown crab or now and then a lobster, rolled from the cell and
      the day (`CrabPotRules`, `data/crab_pot_rules.tres`), and baits it again. An empty
      pot with nothing to bait it comes back up into the bag. Floats show empty, baited
      and ready; the Cove says on arrival how many are ready
- [x] Save version 24: the pots (`crab_pots`); `tests/saves/v23_example.json`
- [x] Verified in the sandbox: headless import and run clean, 411 harness checks (the
      eleven fish: waters, seasons, icons, tags, the bass and the tide, none in fresh
      water and no fresh fish in the sea; the handline's waters; every Cove cell at both
      tides for water_at, the 22 pot cells; winter sea open, the tide's waits, the fine rod
      only with the rod; Tam absent until day 7, all three requests start to finish, the
      sea-fish count ignoring a pond fish; his counter: what he buys, his price over
      Marlow's, plenty after 15 and Marlow unaffected; 59 days of Dot's errands, 20 to
      Tam, none before day 7; pots: set, twice refused, baiting order, not ready the same
      day, ready the next, the haul's items and energy, baited again, pulled up when bare,
      the catch the same twice, 800 rolls of the catch, a save round trip; saves v1–v23
      loaded and a v24 written; in the scene: Tam, the floats, setting a pot with the
      tool, the handline's cursor cells), and played it by keyboard in a rendered Cove:
      cast the handline off the pier at high tide, struck and reeled in a fish, set a pot,
      hauled a ready one with E, talked to Tam and sold him three mackerel
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

### Side task — Dave's seasonal music (no save change)

Dave composed eight tunes, two a season, to replace the generated music (DECISIONS 066).

- [x] The tunes in `assets/audio/music/` (MP3, as Dave made them) and on each season's
      `SeasonTheme.music`; every place plays the season's tunes, taking turns at random
      but never the same twice running, cross-fading 3 s before each ends and when the
      season turns; `LocationDef.music` kept for a place with a tune of its own
- [x] Verified in the sandbox: headless import and run clean; a probe started a new game
      (spring tune in the farmhouse at −10 dB), skipped to near the end (cross-faded into
      the other spring tune), turned the season to winter (winter tune), checked every
      outdoor place gives the season's pair, and walked into the town without a restart
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-17)

## Stage 22 — The tavern and people on the move · 2 sessions · Opus

ROADMAP 13.3 (#10, #11) and 13.4. Split in two on 2026-11-17: session 1 the machinery of
people being somewhere (Opus: a new system), session 2 the tavern, the questlines and
homes that use it.

**Session 1 (2026-11-17) — weekdays, schedules, people who walk (DECISIONS 067, no save change)**

- [x] **Weekdays** from the date: spring day 1 is a Monday, every season starts on one,
      market day is always Wednesday; the HUD says "Spring · Wed 3 · Year 1"
- [x] **Schedules as data**: `CharacterDef.schedule` → `ScheduleDef` (data/schedules/):
      a home and `DayPlan`s for some weekdays, seasons, weathers, each a list of
      `ScheduleStop`s (time, place, cell, words). Worked out from the clock
      (`Schedules`), nothing saved, nobody simulated off-screen; a festival's host is at
      the festival all day
- [x] **People walk** on the map you're on (`PeopleHere`, scripts/people/): between
      stops along `AStarGrid2D` paths over the cells the colliders leave free, off along
      the road towards their next place or in at a door, and in along the road or out of
      a door when they arrive; they don't block the farmer while walking. The town, the
      Lane and the Cove now answer their people the same way (festival, counter,
      requests, errands, the day's line)
- [x] **Knocking**: at a home with someone in, they come to the door and talk (Pip in
      the rain, Dot after six, Tam in his shed)
- [x] **Mabel** keeps the bakery (`ShopDef.keeper_id`): her requests at the counter, and
      she's no longer in the square while she's behind it
- [x] Dot's errands only to someone findable all the hour before they're due
- [x] The request log says where the person to see is and where they'll be next
- [x] Seven schedules: the mayor, Mabel, Pip, Wren, Ivy, Dot, Tam (Wren fishes off the
      pier on Saturdays; Pip's on the beach at weekends; Mabel walks the beach on Sundays;
      Dot's at the market on Wednesdays)
- [x] Verified in the sandbox: headless import and run clean, 369,546 harness checks
      (weekdays, market days on Wednesdays; every person's stop every ten minutes of a
      year in three weathers on a real place and on the map; the expected stops on
      weekdays, Saturday, Sunday, Wednesday, rain and storm, before arrivals, a festival;
      the roads between maps; who's findable; 118 of Dot's errands over 59 days all
      findable; in the scenes: who's in town, every stop cell open and reachable from
      every road and door in town, on the Lane and at the Cove; Mabel out of the bakery
      door at 2 PM and walking to the garden; Pip leaving town at 3; talking to Mabel, Dot
      and Tam (his counter opening after); Pip walking home and in at the door; knocking
      with Pip in and out; the bakery counter asking as Mabel, Marlow's as his shop), and
      rendered Mabel coming out and walking, Pip leaving town, Pip by the ford and Dot at
      her gate, Pip walking home, knocking at Pip's door, Wren and Tam at the Cove on a
      Saturday and the request log
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-18)

**Session 2 (2026-11-18) — the tavern, the questlines, homes (DECISIONS 068, no save change)**

- [x] **Nell's tavern, the Wheatsheaf** (4 PM – 1 AM), on the town's new Back Street; it
      opens on day 8 (`tavern_opens`), when Nell arrives. A room of its own
      (scenes/tavern.tscn): the bar with Nell behind it, barrels, the fire, three tables,
      and whoever's in tonight walking in and out of the door (`PeopleHere` indoors)
- [x] **Rumours**: talk to Nell and she passes on one a night, always true and always
      about tomorrow: the forecast, the low tides, what's biting or in the hedgerows,
      tomorrow's chalkboard (worked out from the date, the `Tavern` autoload)
- [x] **The chalkboard**: three things Nell wants today (produce, forage, sea fish in
      season), five of each at half again their price, on the board and the town notice
      board; Nell buys nothing else (`ShopDef.chalkboard`, capped in `Economy`)
- [x] **Darts night**: Fridays from 7 PM, one go a night at the dartboard: three darts,
      each stopped across then up and down (`DartsGame`); beat the regulars' best and the
      pot is yours (120g). Numbers in data/tavern_rules.tres
- [x] **A hot meal**: a ploughman's from the start; the hotpot and the fish supper once
      Nell's requests teach her them
- [x] **Requests**: Nell (a larder of vegetables, fish for Friday, sloe gin in autumn, a
      winter supper), Dot (a mounting block, a parcel to the tavern, bramble jam), Tam (a
      conger eel, mending his nets); Dot's errands can send you to Nell
- [x] **Homes for everyone**: the mayor's house and the town hall (his office, weekday
      middays) on Back Street, Wren's cottage by the river, Ivy's cottage by the
      allotments on the Lane; knock and whoever's in comes out. The town grows to 48 × 32
      (new south and east, nothing old moved)
- [x] **Evenings at the tavern** in everyone's day, once it's open (`DayPlan.requires_unlock`):
      Tam most nights, Dot on Tuesdays and Thursdays, Ivy on Sunday afternoons, Mabel, Wren
      and the mayor on Fridays, Wren and the mayor on Saturdays; people walk from one door
      to another on the same map
- [x] Verified in the sandbox: headless import and run clean, 343,902 harness checks
      (every person's stop every ten minutes of a year in three weathers, before and after
      the tavern opens; Nell findable whenever she has an errand; the chalkboard and the
      rumours over 224 days; selling capped at the chalkboard; darts scoring, the night's
      best, one go a night and the pot; the new requests; every stop cell and door open and
      reachable in town, on the Lane, at the Cove and in the tavern; the regulars in the
      tavern on a Friday at 7; the mayor walking out of his house and in at the tavern
      door; Nell speaking), and rendered Back Street with the tavern, the mayor's house and
      the town hall, Wren's cottage, Ivy's cottage, the tavern on a Friday night, the
      chalkboard and a dart thrown. Placeholder art for the new buildings, furniture,
      Nell and the dishes (art/build_stage22_s2_placeholders.py) until Stage 23
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-18)

## Stage 23 — Art: the world · 3 art sessions, then soft edges (1 code + 1 art) · cloud env (Pixellab)

**Session 1 (2026-11-18) — every building at the new size (DECISIONS 069, save v25)**

- [x] Every building at the new size with varied sloping roofs (farmhouse, shops,
      greenhouse and its ruin, bakery, tavern, town hall, mayor's house, Pip's, Ivy's and
      Wren's cottages, Dot's yard, Tam's shed, Rosa's cottage, lighthouse): Pixellab
      pixflux from the placeholders, the light take Dave picked from a look test
- [x] Winter versions by script for all of them (art/build_winter_roofs.py), in winter.tres
- [x] The town's shop row rebuilt round the bigger shops (seed shop, general store and
      bakery doors move; the pond is two rows deep with a bank where Wren fishes and the
      fishing contest is held)
- [x] The farmhouse (128 × 112) and greenhouse (80 × 64) on the farm; the workbench moves to
      the new east wall; **save version 25** gives back what stood where they now stand
- [x] Verified in the sandbox: headless import and run clean; 715 layout checks (every
      town doorstep, scheduled stop, festival host and decoration open and reachable from
      the road, no building overlapping another or the town's objects, the pond and its
      bank, the contest host reachable with the decorations up, the farm's buildings,
      BUILDING ground, doorsteps and workbench); the v24 example save upgraded (10 checks:
      everything under the new buildings given back, the workbench moved, a crop outside
      kept), and v1, v7, v18, v21 and v23 saves still load; rendered the town in spring
      and winter, the farm, the Lane and the Cove. (A check of market stalls' cells fails
      the same way on the Stage 22 build: it's the check, not the town.)
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-18)

**Session 2 (2026-11-18) — the Cove's ground and the art backlog (DECISIONS 070, no save change)**

- [x] The Cove's ground: sand, wet sand, the rock shelf with its pools, the sea, the pier's
      planks and the rocks, from Pixellab's terrain tool, mapped onto the palette, in all
      four seasons' ground images (sources in art/ground_sources/cove/); the sea is
      mirrored at random to hide its repeat. The Lane already draws with the real grass,
      path, hedge (thicket), stream and cliff tiles, so it needed no tiles of its own
- [x] Stage 19–22 pieces: debris (bramble, nettles, stones, stump), stone, hedgerow forage
      (raspberry, rosehip, sloe), signpost, old well, rusty tool head, cart, flour sack,
      letter, parcel, the allotment slate, bird box, log pile, stone wall, workbench (and
      broken), tide board, crab pots and their floats, handline, brown crab, lobster, the ten
      sea forage icons, and the tavern's barrels, chalkboard, dartboard, fireplace, bar and
      tables; Nell, Dot and Tam
- [x] Stage 12–18 pieces: all 17 dishes, all 26 fish, the 13 Woods forage icons, the 14 new
      crops' produce and seed packets, tools and items (axe, bait, fibre, rod, spinner,
      winter lure, trowel, growth feed, mulch, pest spray, sapling, hive), the stove (hot and
      cold), the bee hive, weeds, bird bath, trophies, paper lantern, ice hole, festival
      flags and lantern, show tables, the town bridge, the fallen log, the energy icon, and
      Ivy. 162 pictures, every one the same size as the placeholder it replaces, on the
      palette; no code or data changes beyond the sea's mirroring
- [x] Verified in the sandbox: headless import and run clean; rendered the Cove, the Lane,
      the farm, the tavern and the town
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-19)

**Session 3 (2026-11-19) — the rest of the backlog, portraits and UI pictures (DECISIONS 071, no save change)**

- [x] The growth sheets of the 17 Stage 12 crops, the giant melon and pumpkin and the apple
      tree; the sprinklers, the field-upgrade deed, the float, the sickle, aphids, the
      contest sign and Ivy's ruined glasshouse
- [x] Kept as they are (no take beat them): the broken bridge, the Woods footbridge, the
      fed and mulched soil and the greenhouse floor
- [x] Stage 24's pictures made early, not used yet: 13 portraits (neutral, happy, worried)
      and the UI nine-patches (panel, portrait frame, buttons)
- [x] Dave confirms it plays correctly on Windows (committed 2026-11-19)

**Sessions 4 and 5 — soft ground edges (ROADMAP.md section 14, asked by Dave 2026-11-19; no save change expected)**

Where two kinds of ground meet (grass and path, land and water, sand and sea) they blend
in soft, rounded, irregular edges instead of square tile edges, as in Dave's Stardew Valley
pictures. Cells don't change; only the drawing does.

- [x] Session 4 (2026-11-19, code; DECISIONS 072, no save change): GroundEdges, a
      display-only "dual grid" drawn half a tile offset over every outdoor map's ground,
      each picture chosen from the four cells at its corner (16-tile corner sets); twelve
      grounds in height order (sea, pond, wet sand, rock shelf, sand, path, paving, tilled,
      wet tilled, grass, rocks, hedge/thicket), each drawn over anything lower, so one set
      each; the cliffs and the pier keep square edges; redrawn by itself whenever a cell is
      drawn (the hoe, a field going back, the tide, the allotment beds, the Woods' logs);
      tufts and pebbles scattered along the joins; the Cove's beach outline made irregular
      (grass bites, sand spills, dry sand stepping into the shore, the low tide's edge in
      and out) and the Lane's stream wanders (the farm and town ponds only round off: their
      cells can hold saved things); **grass over the dirt path made with Pixellab** (the
      terrain tool's corner set, with the lip and its shadow), the look test for Dave;
      every other set a placeholder made by art/build_ground_edges.py from each ground's
      own plain tile, in all four seasons
- [x] Session 4 verified in the sandbox: headless import and run clean; rendered the farm,
      the Lane, the town, the Cove and the Woods in all four seasons, the Cove at low and
      high tide and freshly tilled soil; the Cove's and Lane's layouts compared cell by cell
      with the old ones: the strand line, rockpools, crab-pot spots, the hedgerow forage
      and the sea's fishing spots are unchanged
- [x] Dave confirms session 4 plays correctly on Windows (committed 2026-11-19), and the
      grass ↔ path look is right for session 5 to make the rest the same way
- [x] Session 5 (2026-11-19, art; DECISIONS 073, no save change): every other ground's edge
      made with Pixellab's terrain tool (seed 7, like grass): pond water, wet sand, rock
      shelf, sand, path, paving, tilled, wet tilled, boulders and the hedge; each read
      against the one outline Pixellab shares between its sets, and coloured from our own
      plain tiles, so all four seasons match; grass over pond water gets a sandy, stony
      bank of its own; animated foam (four frames) on the sea's edge, following the tide
- [x] Kept as they are: the cliffs' square tops, session 4's edge scatter, grass's own set
- [x] Maps touched: farm, Lane, town, Cove, Woods (not interiors, buildings or the pier)
- [x] Verified in the sandbox: headless import and run clean; rendered every map in all
      four seasons, the Cove at low and high tide (and the foam's frames changing)
- [x] Dave confirms session 5 plays correctly on Windows and likes the look (committed
      2026-11-19)

## Stage 24 — Art: people and the UI · 1 code + 2 art sessions · Sonnet + cloud env

**Session 1 (2026-11-19, code) — the font, the theme, portraits, eight facings (DECISIONS 074, no save change)**

- [x] **A pixel font**: monogram (CC0) for all text at 16, Pixelify Sans (OFL) for headings
      at 13, with their licences in assets/fonts/; four characters monogram lacks (· – — ×)
      drawn into it in its own grid (art/fonts/extend_monogram.py)
- [x] **A UI `Theme`** (assets/ui/theme.tres, the project's theme): Stage 23's wooden
      nine-patch for every panel (dialogue, shop, cook and workbench menus, requests, the
      day's summary, the new-game menu), its buttons for menu rows (plain ink until picked,
      then on the orange button); dark ink on the cream panels, light outlined text on the
      world (HUD, hotbar)
- [x] **Portraits in the dialogue box**: a framed bust beside the box for all 13 people
      (`CharacterDef.portrait`, `ShopDef.keeper_portrait`), in three moods: happy when a
      request is handed in, an order taken or at a festival; worried when their request is
      due or late, or the shop's shut; a line in a .tres can pick its own face with a
      leading `[happy]` or `[worried]` (a few are tagged)
- [x] **Eight-way facing** (ROADMAP section 15) for the farmer and the walkers, from the
      direction they move: `walk_down_right` and so on when their sheet has it, otherwise
      the nearest of four exactly as before (so nothing changes until eight-way sheets
      arrive); tools and E still act on the cell straight ahead
- [x] **Walk cycles can drop in**: `CharacterDef.walk_frames` (a SpriteFrames named like the
      farmer's: idle_down, walk_down_right…) makes a person walk and stand animated; without
      it they're the still picture, bobbing, as now. Walkers cut corners across open ground
- [x] Verified in the sandbox: headless import and run clean; rendered the new-game menu,
      Mabel happy and the mayor worried and asking (with answers), the mayor's real first
      words, the requests panel, Marlow's shop, the HUD, the day's summary and the farmer
      on the farm; checked in the running game: four-way sheet on a diagonal plays walk_down
      and targets the cell below, an added walk_down_right is picked up, idle falls back,
      up-left plays walk_up, a walker with frames plays its diagonal then straight walk
- [x] Dave confirms it plays correctly on Windows and likes the look (committed 2026-11-19)

**Sessions 2 and 3 (art, cloud env with Pixellab) — done as one session, 2026-11-19 (DECISIONS 075, no save change)**

- [x] Walk cycles for every person (13), the same layout as the farmer's sheet, each made
      into a SpriteFrames beside the sheet (`<id>_walk.png` + `<id>_frames.tres` next to
      their still picture) and set as `CharacterDef.walk_frames` for the eight people who
      walk (Mabel, Nell, Tam, Dot, Ivy, the mayor, the angler, the child); the five
      counter-only keepers have sheets ready but nothing uses them yet
- [x] Eight-way sheets (the four diagonals, walk and idle) for the farmer
      (farmer.png gains rows 5-8 and four idles in row 0; player_frames.tres gains
      `walk_down_right`… ; his four straight rows are untouched) and for each person, in
      the same art pass; every diagonal drawn, none mirrored
- [x] Verified in the sandbox: headless import and run clean; every SpriteFrames loads
      with 16 animations (8 idle of 1 frame, 8 walk of 8 frames, all 56 × 56) and Facing
      finds all eight walks; walk preview GIFs made for Dave
- [x] Dave confirms the look and that people walk correctly on Windows (committed 2026-11-19)
- [ ] Optional: more lines tagged with `[happy]` / `[worried]` where a face would help

**Side test (2026-11-20) — calmer ground from the Cozy Village & Farm pack (DECISIONS 076, no save change)**

- [x] The pack's ground (grass, path, paving, soil, pond, sand, sea and their soft edges)
      built into our layout by `art/build_cozy_ground.py` into `assets/tilesets/cozy/`
      (kept out of git: pack licence, public repository)
- [x] On by default when that folder exists; **Ctrl+G** swaps between it and our own ground
      in the game; with it off the game looks exactly as before
- [x] Verified in the sandbox: headless import and run clean; before/after screenshots of the
      farm, Lane, town and Cove (spring, summer, autumn, winter, low tide)
- [x] Dave compares on Windows and decides: **keep** (2026-11-20, DECISIONS 077): palette
      rebuilt to 74 colours, CREDITS.md started, Ctrl+G kept as a debug switch, the pictures
      stay git-ignored while the repository is public
- [x] Later, separately: the pack's props (fences, stone wall, well, stalls, lamps, benches),
      and maybe its trees, bushes and rocks (props: DECISIONS 081; the rest is Dave's
      scenery, 082)

**Side test (2026-11-20) — calmer cliffs and paving (DECISIONS 078, no save change)**

- [x] Cliffs drawn as the cozy pack's raised ground (grassy or snowy top, outline, earth
      face; two tiles high where the cliff is deep), chosen per cell by its open sides
- [x] Paving (the Cove's quay outside Tam's shed, and the town square) as calm flagstones
- [x] Built by `art/build_calm_test.py` into `assets/tilesets/cozy/calm_*` (git-ignored);
      on by default, **Ctrl+K** swaps it off and on; off is exactly the kept cozy look
- [x] Verified in the sandbox: import and run clean; before/after shots of the Cove (quay,
      cliffs, winter), town, farm, Lane and Woods
- [x] Dave compares on Windows and decides: **keep** (2026-11-20, DECISIONS 080; Ctrl+K
      stays as a debug switch)
- [x] Dave picks what to take from the Coast, Seasons & Festivals and UI Kit packs: the
      harbour, its props, festival dressing, the Wood UI and the cozy props (DECISIONS 080, 081)

**Side test (2026-11-20) — a proper harbour in the Cove (DECISIONS 080, no save change)**

- [x] Quay wall standing in the sea south of the paving (ends, a ladder now and then), the
      pier's deck on posts, the breakwater's top and foot, a calmer rock shelf
- [x] Built by `art/build_harbour_test.py` into `assets/tilesets/cozy/harbour_*` (git-ignored);
      on by default, **Ctrl+H** swaps it off and on
- [x] Verified in the sandbox: import and run clean; before/after shots of the Cove
- [x] Dave compares on Windows and decides: **keep** (2026-11-21: "happy with all of the changes")

**Side test (2026-11-20) — the packs' props, festival dressing and wooden UI (DECISIONS 081, no save change)**

- [x] Cozy pack props on our bench, lamp post, well, hay bale, log pile, notice board,
      scarecrow, bee hive, cart; fences and the stone wall join up from their 4-bit sets
- [x] Harbour clutter in the Cove; dressing in town for the flower show, fishing contest,
      harvest fair, lantern night and market day (only on its day)
- [x] Wood UI: panels, buttons, hotbar slots, portrait frame; our fonts kept
- [x] Built by `art/build_pack_look.py` into `assets/packs/` (git-ignored); on by default,
      **Ctrl+P** swaps props and dressing, **Ctrl+U** the UI
- [x] Verified in the sandbox: import and run clean; before/after shots of the Cove, each
      festival day, market day, the Lane's fences and the dialogue box
- [x] Dave compares on Windows and decides: **keep** all of it (2026-11-21)

**Side fix (2026-11-20) — E forgives a near miss (DECISIONS 079, no save change)**

- [x] E tries the tile ahead first as before, then the nearest of the tiles around the
      farmer (not behind them), in all eight facings: forage, people (walking too), keepers
      across a counter or stall, boards, the bin, bed and stove, and ready crops by hand
- [x] Sprinklers and decorations still need aiming at exactly (E picks them up); weeds,
      brambles and every tool stay tile-exact
- [x] Verified in the sandbox: headless import and run clean; 15 checks on the real farmer
      (ahead first, corners, own tile, behind and two away ignored, down-right, sprinkler
      kept, counter end, a person mid-walk)
- [x] Dave confirms on Windows that picking up and talking feel right (2026-11-21)

**Side test (2026-11-21) — the rooms furnished from the Cozy Interiors pack (DECISIONS 083, no save change)**

- [x] The four shops each their own: Hollis's warm wood with sacks and barrels, Marlow's
      plaster and birch, Mabel's cream wallpaper and terracotta with the oven going, Brann's
      stone with the forge; pack counters over ours, shelves, wall hangings, lanterns
- [x] The farmhouse (bed, kitchen corner, grandfather clock, a sleeping cat) and the
      Wheatsheaf (bar with taps, kegs, the stone fireplace, tables set, a cat by the fire)
- [x] Windows show night after 7 PM; our counter, bed, bar, tables and fireplace keep
      their collision and E; a few new pieces along the walls are solid
- [x] Built by `art/build_interior_look.py` into `assets/packs/interiors/` (git-ignored); on
      by default, **Ctrl+R** in a room swaps it off and on
- [x] Verified in the sandbox: import and run clean; before/after shots of every room,
      night windows, Ctrl+R
- [x] Dave compares on Windows and decides: **keep** (2026-11-21: "happy with all of the
      additions"); palette grows to 88 with its colours; Ctrl+R stays as a debug switch

**Side task (2026-11-21) — the townsfolk's homes, furnished (DECISIONS 084, no save change)**

- [x] Seven homes you can go into: the mayor's, Wren's, Pip's family's, Ivy's, Dot's yard,
      Tam's shed and Rosa's; one room scene for all, its shape on each home's LocationDef
- [x] Each furnished to suit its owner from the Cozy Interiors pack
      (`art/build_interior_look.py`, git-ignored output); night windows; Ctrl+R swaps the
      look as in the other rooms
- [x] Doors open 8 AM to 8 PM; out of hours knocking works as before
- [x] Whoever's at home is inside (their schedule decides), walks out when their day takes
      them out, walks in when they come home, and talks as they do outside
- [x] Verified in the sandbox: headless import and run clean; shots of all seven; hours,
      walking in and out from town, knocking after 8 PM, Pip leaving and coming home,
      talking to Ivy; the rooms without the pack
- [x] Dave walks into a few homes on Windows and decides: **keep** (2026-11-21: "happy with them")

**Side task (2026-11-21) — Dave's scenery (DECISIONS 082, no save change)**

- [x] A scenery scene per map (`scenery/farm.tscn`, `town`, `lane`, `woods`, `cove`), loaded
      when the map opens: OnTheGround, Standing, Solid (the farmer bumps into it) and Overhead
- [x] In the editor: the map shown behind (Ctrl+B in the game takes the picture), each new
      picture's origin moved to its feet, the first frame of a strip
- [x] In the game: strips animate, string lights light after dark, seasonal pictures follow
      the season
- [x] A library of 571 pack pictures in `assets/scenery/` (git-ignored), built by
      `art/build_scenery_library.py`; backdrops of all five maps
- [x] How-to for Dave: `scenery/HOW_TO.md`
- [x] Verified in the sandbox: headless import and run clean; a test scene on the farm
      (seasonal tree in front of and behind the farmer, a solid fence he stops at, flowers
      under him, bunting over him, a pingpong buoy, string lights lit at 21:40 and not by
      day); Ctrl+B on all five maps; the editor opened on the scene with its backdrop, and
      a picture added there got its origin moved to its feet
- [x] Dave opens a scenery scene, places a few things, saves, and sees them in the game
      (2026-11-21: "happy with them")

**Side task (2026-11-21) — a calm hedge, drop-in music (DECISIONS 087, no save change)**

- [x] The berry hedge redrawn calm, by `art/build_calm_hedge.py` (our own art, in git):
      the Lane's hedgerows, the Woods' thickets and the farm's unbought fields, four
      seasons, in our tilesets and the cozy test copies; `--restore` puts the berries back
- [x] Music by file name in `assets/audio/music/`: `<season>_...`, `<event id>_...` (in
      the event's place on its day), `any_...`; how-to `assets/audio/music/HOW_TO.md`
- [x] Verified in the sandbox: headless import and run clean; shots of the Lane, the farm
      and the Woods in all four seasons; which tunes play by season, on the Flower Show day
      in town, in a shop off the square, on the farm and the day after
- [ ] Dave walks the Lane (and past the farm's unbought fields) and decides: keep the calm
      hedge or `--restore`
- [ ] Dave drops in a tune of his own and hears it

**Side task (2026-11-21) — little moving things (DECISIONS 088, no save change)**

- [x] Chimney smoke on every building with a chimney (11 of them) and lit windows after
      dark (14 buildings), from `data/ambience/buildings/`
- [x] Things that come and go by themselves, one file each in `data/ambience/effects/`:
      butterflies (spring, summer), songbirds (spring to autumn), gulls (Cove), falling
      leaves (autumn), fireflies (summer nights), sparkles on the water, ripples and a
      jumping fish on the pond, fish jumping in the Cove's sea, sparkles on the snow
- [x] Pack pictures reused (copied into `assets/scenery/ambient/` and
      `creatures/critters/` by `art/build_scenery_library.py`, git-ignored); our own
      fish jump, songbird and window halo by `art/build_ambient_art.py` (in git)
- [x] Off switch: Settings → Animations, or Ctrl+Y (kept in settings.cfg)
- [x] Dave's scenery: a picture named "night" shows only after dark, one named "now and
      then" plays now and then; how-to in `scenery/HOW_TO.md`
- [x] Verified in the sandbox: headless import and run clean; shots and short clips of the
      town by day and night, the pond, the Cove, the farm in autumn and at night, the
      Woods on a summer night, the Lane in winter; the switch on and off; without the
      packs' pictures (only our own pieces show, no errors)
- [ ] Dave walks round in a few seasons and times of day and decides: keep, tone down, or
      more of something

## Stage 25 — Almanac and year review · 1–2 sessions · Sonnet

The old Stage 19 without "life in town". Save version 26 (Stage 23 took 25).

**Session 1 (2026-11-21) — the almanac, the year review, year 2 (DECISIONS 085, save version 26)**

- [x] The collections book (crops, fish, sea fish, forage, sea forage, recipes): **L**
      opens it anywhere and pauses the game; Q / Tab turn the page, the arrows pick an
      entry, L or Esc close it. Filled in once grown, caught, found or cooked; until then
      a dark shape with a hint (when and where). Worked out from content: a new .tres is in
      it with no code. 89 entries today
- [x] A Years page: each year's review and this year so far
- [x] The mayor's year review at lantern night: when he gives his lantern he reads out
      the year (picked and sold, caught, found, cooked, requests, festivals, the almanac)
      and gives a title from "A promising start" to "Pride of the valley"; every number
      and title in `data/year_review_rules.tres`. Missed lantern night: the review is left
      as a note, said in the first morning's summary
- [x] Year 2 (`year_two`, spring 1 of year 2): Rosa's bigger city orders, the mayor's
      "The valley's almanac" (12 new entries), Pip's "Pip's shadows" (5 new entries); a
      new kind of request, AlmanacGoal
- [x] Save version 26 (crops grown, wild things found, the year's tally, the reviews); an
      older game's book starts from its bag, fish log and recipes;
      `tests/saves/v25_example.json` made from the version 25 build
- [x] Verified in the sandbox: headless import and run clean; every save from version 1
      to 25 upgrades and loads; a version 26 save round-trips; first-time entries land
      on the right pages (crops, river fish, sea fish, Woods and Cove forage, recipes);
      the tally counts picking, selling at the bin and at counters, fish, forage,
      cooking and requests; lantern night's lines with the review; the year turns, the
      tally starts again and year 2 opens; a missed lantern night leaves a note; rendered
      the review in the dialogue box, every almanac page, the Years page and the morning
      note
- [ ] Dave plays it on Windows: L on the farm and in town, a page or two, and (with a
      save near the end of winter, or a new game played on) lantern night with the mayor
- [ ] Later, with art: Hollis's rare catalogue and Fennel's exotic greenhouse seeds (ROADMAP
      section 3), and a keepsake of its own for each title if Dave wants one

## Stage 26 — Balance and release · 2 sessions · Opus for balance

The old Stage 20 (Stage 9's second half).

- [x] Title screen, an Esc menu and settings, done early on their own (2026-11-21,
      DECISIONS 086, no save change): the title over the loaded game (Continue, New game,
      Settings, Controls, Quit); Esc in the world (Resume, Settings, Controls, New game,
      Title screen, Quit, the last two asking first); settings in `user://settings.cfg`
      (music and sound volume, window or full screen, window size ×1 to ×4, whole-pixel
      scaling). Verified in the sandbox: headless import and run clean; rendered every page
      and drove each path by keys (Continue, New game and Esc back to the title, a new game
      started from it, the settings changed and written to the file, Esc to the menu and
      back, the "are you sure?" page)
- [ ] Dave tries it on Windows: F5 opens on the title; Continue; Esc in the world; Settings
      with the music and sound levels, and (with the game in its own window, not embedded
      in the editor) full screen and the window sizes
- [ ] Save slots, credits (from CREDITS.md: the fonts and the Cozy Village & Farm pack; a
      player-facing list, and CREDITS.md isn't exported by default); decide the repository:
      private, or build the release on Dave's PC where `assets/tilesets/cozy/` exists
      (DECISIONS 077)
- [ ] Full balance pass across a simulated year, including the clock now that travel is
      longer (`seconds_per_ten_minutes`, 5 now; 6 may suit the bigger map)
- [ ] Windows export, itch.io page
