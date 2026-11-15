# Pixel Harvest — stage plan

**Current stage: 9 — feel, balance and release.** Stage 8 (events and quests) is complete: sessions 1–4 and their real art confirmed by Dave on 2026-11-15.

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

## Stage 9 — Feel, balance and release · 2 sessions · Sonnet 5.5

Split: session 1 is the feel (sound, juice, the day's summary); session 2 is the release
(title screen, settings, save slots, the balance pass, export and itch.io).

- [x] Sound effects and music
- [x] Particles, screen shake, harvest pops — the juice
- [ ] Title screen, settings, save slots
- [x] Day-end summary screen
- [ ] Full balance pass across a simulated year
- [ ] Windows export, itch.io page

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
