# Pixel Harvest — stage plan

**Current stage: 6 — seasons made real.** Session 1 built 2026-11-14; awaiting Dave's check on Windows. Session 2 is the real seasonal art.

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

- [ ] Town scene and transitions via `LocationManager`
- [ ] Building exteriors and one or two interiors
- [ ] Seed shop, general store, blacksmith
- [ ] Shopkeeper sprites and simple dialogue

## Stage 8 — Events and quests · 2–3 sessions · Sonnet, Haiku for bulk

- [ ] `CalendarEvent` resource; market day every N days
- [ ] Market stalls with better prices and rarer seeds
- [ ] `QuestDef` resources subscribing to `EventBus` signals
- [ ] Two or three quest characters
- [ ] Cosmetic purchases and farm decoration
- [ ] `DifficultyDef` resources and a new-game difficulty choice

**The architecture's exam.** If quests need changes to the farming code, something went
wrong earlier.

## Stage 9 — Feel, balance and release · 2 sessions · Sonnet 5.5

- [ ] Sound effects and music
- [ ] Particles, screen shake, harvest pops — the juice
- [ ] Title screen, settings, save slots
- [ ] Day-end summary screen
- [ ] Full balance pass across a simulated year
- [ ] Windows export, itch.io page
