# Pixel Harvest — stage plan

**Current stage: 1 — walking skeleton.**

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
- [ ] Dave confirms it plays correctly on Windows

**1b — real art**

- [x] Agree the character's look; generate in Pixellab from the `art/STYLE.md` template
- [x] Save the approved sprite as `art/reference.png` — the style anchor for everything after
- [x] Build `SpriteFrames` from Pixellab's JSON rather than assumed geometry
- [x] Verify against spec (size, frame grid, transparency, palette) and swap it in
- [x] Rebuild the palette from the art; every asset now sits exactly on it
- [x] Log the generation in `art/STYLE.md`
- [x] Verified in a rendered recording: 8-frame walk cycle plays in all four directions
- [ ] Dave confirms it plays correctly on Windows

**Left over for later:** `player_placeholder.png` is now unused and can be deleted
whenever convenient; the tree and ground tiles are still placeholder and get replaced
in Stage 6 alongside the seasonal tilesets.

**Why this stage first:** it proves the whole Pixellab → Godot pipeline end to end before
any game systems exist. If the art pipeline has a problem, this is the cheapest place to
find it.

## Stage 2 — Core loop and seams · 3–4 sessions · Opus

- [ ] `FarmData` — authoritative tile state, entirely separate from the tilemap
- [ ] Till, plant, water, harvest on a small plot
- [ ] One hardcoded crop with growth stages
- [ ] `TimeSystem` — sleep advances the day, crops advance one stage
- [ ] `GameState` autoload — gold, day, season, energy; survives scene changes
- [ ] Energy costs per action; day ends at zero
- [ ] `LocationManager` seam (farm only for now) — see DECISIONS 004
- [ ] `SeasonTheme` swap hook, wired but with one theme — see DECISIONS 005

**The whole game in miniature.** Everything after this is content or convenience.

## Stage 3 — Save and load · 1 session · Opus

- [ ] Versioned save file with `save_version` and a migration function
- [ ] Serialise `FarmData`, `GameState`, inventory, upgrades
- [ ] Save on sleep, load on launch, new-game path
- [ ] Deliberately break and migrate a save once, to prove the mechanism works

**Early, not late.** Retrofitting versioning after there's a save worth keeping is misery.

## Stage 4 — Content pipeline and economy · 2–3 sessions · Opus, then Sonnet

- [ ] `CropDef` resource script, including `regrow_days`
- [ ] `ContentDB` autoload loading all definitions from `data/`
- [ ] Convert the Stage 2 hardcoded crop to a resource — the proof that content is data
- [ ] Inventory system
- [ ] Shipping bin: drop produce, sold overnight, gold at dawn
- [ ] Menu-based seed shop (replaced by the town in Stage 7)
- [ ] Basic HUD: gold, day, season, energy, selected tool
- [ ] Five crops, including at least one regrowing

## Stage 5 — The incremental spine · 2–3 sessions · Opus to design, Sonnet to build

- [ ] `ToolDef` resource with tiers and area of effect
- [ ] Hoe and watering can at 1 → 3 → 9 tiles
- [ ] Energy upgrades
- [ ] Sprinklers — the first thing that removes a daily chore entirely
- [ ] Plot unlocking to expand the farm
- [ ] `UpgradeDef` resources and a purchase flow
- [ ] First real balance pass: is the curve satisfying?

## Stage 6 — Seasons made real · 2 sessions · Sonnet 5.5

- [ ] Calendar: season length, year rollover
- [ ] Crops gated by season; out-of-season crops die at the turn
- [ ] Seasonal tilesets via image-to-image from the base set
- [ ] `SeasonTheme` resources; swap on `season_changed`
- [ ] Winter snow overlay

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
