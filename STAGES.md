# Pixel Harvest — stage plan

**Current stage: 16 — kitchen and cooking.** Session 1 (recipes as data, the farmhouse stove, eating from the hotbar, Mabel's kitchen lessons and recipe book, Wren's grilled fish; save version 17) is built, waiting for Dave to try it. Then Stage 16's Pixellab art (stove, ten dishes), and Stage 17 (greenhouse, bees and late tools). Stage 15 (fishing with Wren) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-16). Stage 14 (the Woods and foraging) is complete apart from its Pixellab art, which waits for an art session: both sessions tested and committed by Dave (2026-11-16). Stage 13 (questlines) is complete: both sessions tested and committed by Dave (2026-11-15); still to come from it are Ivy's Pixellab art and Dave playing a full year. Stage 12 (crops with rules) is complete apart from its Pixellab art: both sessions tested and committed by Dave (2026-11-15). Stage 11 (hazards and weather) is complete: both sessions tested and committed by Dave (2026-11-15); pests and storm-flattening moved to Stage 12. Stage 10 (pacing and unlocks) is complete: Dave played the spring and the pacing looks good (2026-11-15). Stage 9 session 1 (feel) is built; its release half moved to Stage 20. Stages 10–20 come from `ROADMAP.md`, agreed by Dave on 2026-11-15: read it before starting any of them. The clock runs at 5 seconds per 10 game minutes since 2026-11-16 (DECISIONS 051).

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
- [ ] Dave confirms it plays correctly on Windows

**Art**

- [ ] Pixellab: stove (lit and cold), ten dish icons

## Stage 17 — Greenhouse, bees and late tools · 2 sessions + art · Sonnet

- [ ] Greenhouse building with an indoor plot that ignores seasons (Ivy's line)
- [ ] Bee hives and honey; fertilisers; the sickle's tiers; the brass sprinkler
- [ ] Pixellab: greenhouse (outside, winter, inside), hive, honey, sickle, fertiliser, sprinkler

## Stage 18 — Festivals · 1–2 sessions · Sonnet

- [ ] Spring flower show, summer fishing contest, autumn harvest fair, winter lantern night
- [ ] Pixellab: festival decorations, trophy

## Stage 19 — Almanac, year review, life in town · 1–2 sessions · Sonnet

- [ ] The collections book (crops, fish, forage, recipes)
- [ ] The mayor's year review and title at lantern night; year-2 content
- [ ] Optional: townsfolk walk between spots on a schedule (Pixellab walk cycles)

## Stage 20 — Balance and release · 2 sessions · Opus for balance

Stage 9's second half, moved here.

- [ ] Title screen, settings (with volume), save slots
- [ ] Full balance pass across a simulated year. Includes the clock: Dave finds it seems
      slow (2026-11-15). Check its pace (`seconds_per_ten_minutes`, 7 now) against a real
      day's work, and that it ticks steadily through the day
- [ ] Windows export, itch.io page
