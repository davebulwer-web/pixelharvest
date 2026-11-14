# Pixel Harvest — decision log

One entry per significant choice: what was decided, why, and what it costs. Append, don't
rewrite. If a decision is reversed, add a new entry superseding the old one rather than
editing history.

---

## 001 — Godot 4.7.2 (GDScript) rather than web technology

**Decision.** Build in Godot 4, standard build, GDScript.

**Why.** The game is a walk-around world: tile grid, collision, Y-sorting so the character
passes behind tall crops, 4-direction animation state machines, and a following camera.
All four are nodes in Godot and hand-rolled work in HTML. Godot also exports native
desktop binaries, so no Electron/Tauri wrapper question arises. Its Resource system gives
data-driven content with an inspector UI for free, which matters for a game that will end
up with dozens of crops, tools and upgrades.

**Cost.** A new engine and a new language to learn, and a slower feedback loop — Claude
can't run Godot on Dave's machine, so Dave runs and reports. Partly mitigated by Claude
running Godot headless in its sandbox to catch errors first (see `CLAUDE.md`).

---

## 002 — Discrete days; no real-time or offline progression

**Decision.** Time advances in whole days when the player sleeps. Nothing grows while the
game is closed.

**Why.** It removes an entire subsystem (offline catch-up and real-clock reconciliation),
it's far easier to balance, and it fits a game where you physically walk to each tile.

**Cost.** Pixel Harvest is therefore a *progression* game rather than an idle game. Players
expecting numbers to climb while away won't find that here. Accepted deliberately.

---

## 003 — Energy is the daily bottleneck

**Decision.** Every meaningful action costs energy. The day ends when energy is exhausted.
No in-day clock.

**Why.** It gives the clearest possible upgrade curve: each upgrade either reduces cost per
tile or raises the pool, and both are immediately legible to the player. Balancing one
resource is much easier than balancing energy and time together.

**Cost.** Loses the texture of a day with morning and evening. Shop opening hours and
time-of-day lighting aren't available without revisiting this.

---

## 004 — Farm plus town, with the seam built early and the town built late

**Decision.** The world has two locations. A `LocationManager` and persistent `GameState`
across scene transitions go in at Stage 2; the town itself is built at Stage 7.

**Why.** Scene transitions with preserved state are nearly impossible to retrofit cleanly,
but the town is mostly art and content. Splitting them means the farm loop is fully
playable and testable for five stages before any building art is generated.

**Cost.** A piece of unused plumbing sits in the project for several stages. Worth it.

---

## 005 — Full visual seasons, generated image-to-image from one base tileset

**Decision.** Seasons change the look of the farm, not just which crops grow. Seasonal
tilesets are produced by running Pixellab's image-to-image over the base tileset, not by
generating each season from a fresh prompt. A `SeasonTheme` resource points at the tileset
for each season; the swap mechanism is built in Stage 2, the art in Stage 6.

**Why.** It's the single biggest visual payoff available, and the one thing that will make
the game look like a real game rather than a prototype. Image-to-image from one base keeps
the four sets coherent, which fresh prompts months apart would not.

**Cost.** By far the largest art commitment in the project — roughly four times the ground
and foliage work. Contained by limiting seasonal variants to ground tiles, trees and a few
props: crops never need them (they're season-gated), and buildings need at most a snow
overlay.

---

## 006 — Crops are single-harvest or regrowing; no quality tiers, no processing

**Decision.** One extra field on the crop definition (`regrow_days`, 0 meaning
single-harvest). No silver/gold quality. No machines turning crops into higher-value goods.

**Why.** Regrowth genuinely changes how a farm is planned, for almost no complexity.
Quality tiers add inventory and UI complexity for a mostly numerical effect. Processing is
an entire second production system.

**Cost.** A shallower economy than Stardew's. The Resource architecture leaves room for
both later; neither should shape the schema now.

---

## 007 — No animals

**Decision.** Crops only.

**Why.** Honest scope. Animals mean coops, feeding loops, daily produce and a lot of
animation work, and the game is a full build without them.

**Cost.** None now. If animals are ever added, they're the best available test of whether
the architecture really is adaptable.

---

## 008 — No prestige or reset loop

**Decision.** A single long progression. No "start again with permanent bonuses".

**Why.** Designing for prestige distorts the economy from the start — everything has to be
balanced twice, for the first run and for later ones.

**Cost.** Less replay value. Addable later, but it would need an economy rebalance.

---

## 009 — Stretch mode `canvas_items` at 640×360, not `viewport`

**Decision.** Base viewport 640×360, stretch mode `canvas_items`, nearest-neighbour texture
filtering, 2D pixel snapping on. Camera zoom set so roughly 20×11 tiles are visible.

**Why.** `viewport` mode renders everything at low resolution and scales it up, which is
the most authentic pixel look but caps all UI text at the same tiny resolution — painful
for shop and inventory screens. `canvas_items` keeps sprites crisp via nearest filtering
while letting UI use readable font sizes. 640×360 scales to 1920×1080 at exactly ×3.

**Cost.** Slightly less purist. UI and sprites live at different effective resolutions, so
UI must be designed to look deliberate rather than accidentally high-res.

---

## 010 — Input actions defined in code, not in the editor's Input Map

**Decision.** `scripts/autoload/input_actions.gd` registers every action at startup from a
dictionary of physical keycodes.

**Why.** Two reasons. Practically, hand-writing Godot's serialised `InputEventKey` objects
into `project.godot` is error-prone, and a malformed `project.godot` can stop the project
opening at all — the worst possible failure for someone who can't yet debug it. By design,
it also means keybindings live in a reviewable source file that travels with the repo,
rather than in engine config nobody reads.

**Cost.** Non-idiomatic: the editor's Input Map panel will appear empty, so the actions
aren't discoverable by clicking around. Migrating to the editor's map later is a single
contained change. Physical keycodes are used so WASD stays put on non-QWERTY layouts.

---

## 011 — All content lives in Resources, loaded by `ContentDB`

**Decision.** Crops, tools, upgrades, season themes, quests and difficulty settings are
`.tres` files with typed scripts. Adding content must not require code changes.

**Why.** This is the main structural answer to "add features without major overhaul".
It also turns balancing into editing data files with an inspector UI, rather than hunting
numbers through scripts.

**Cost.** More up-front structure than hardcoding, and one refactor at Stage 4 to convert
the first hardcoded crop. Deliberately paid early.

---

## 012 — Cross-system communication goes through `EventBus`

**Decision.** A global autoload declares signals describing things that have happened.
Systems emit and subscribe; they don't hold references to each other merely to react.

**Why.** It's what makes Stage 8's market days and quests nearly free: a quest subscribes
to `crop_harvested` without a single line changing in the farming code.

**Cost.** Indirection — tracing a flow means searching for subscribers rather than
following a call. Mitigated by declaring every signal in one documented file.

---

## 013 — Claude verifies visually, not just headlessly

**Decision.** Every delivery is checked three ways in Claude's sandbox before it reaches
Dave's machine: a headless import pass, a headless run, and a rendered recording under
`xvfb` with a temporary harness driving input.

**Why.** A headless run proves the code doesn't crash; it proves nothing about whether the
game looks or behaves right. In Stage 1 the headless pass was completely clean while the
trees rendered as lollipops on sticks and the grass was unreadable static — neither
detectable without looking. Y-sorting and collision are the same: they either work on
screen or they don't, and no amount of parse-checking will say which.

**Cost.** A few minutes per delivery, and a temporary harness that must be deleted rather
than shipped. Trivial next to a wasted session on Dave's side.

---

## 014 — Stage 1 built on generated placeholder art

**Decision.** Player, tree and ground tiles for Stage 1 are generated by a Python script
(`tools/make_placeholders.py`, kept in Claude's workspace) in the Harvest 32 palette at
exactly the locked dimensions. Real Pixellab art replaces the PNGs with no code change.

**Why.** It decouples code progress from asset production, and it proves the import
pipeline, the sprite-sheet layout and the `SpriteFrames` resource all work before a single
generation is spent. If the real sprite sheet has a problem later, everything around it is
already known good.

**Cost.** The game looks crude until Stage 1b. Deliberate — placeholder art that is
obviously placeholder is a feature, because it never gets mistaken for finished work.

---

## 015 — The palette is derived from the art, not imposed on it

**Decision.** `art/palette.png` is the project's only palette definition. It is the union
of every colour present in the art, rebuilt by `make_palette.py` and read directly by the
asset checker. This supersedes the hand-written Harvest 32 from decision 005.

**Why.** Harvest 32 was written before any art existed and contained no skin tones, so the
first real character matched none of its 32 entries exactly. The choice was to snap good
art onto a guess or to rebuild the guess around the art. The second is obviously right:
the palette exists to prevent *drift*, not to be correct in advance. Rebuilt from the
actual assets it came out at 33 colours — barely larger — and every asset now sits exactly
on it.

**Cost.** The palette is no longer fixed, so it could creep if colours are accepted
carelessly. Contained by the checker: new colours are reported as off-palette, which forces
a deliberate choice between accepting them (and regenerating) or correcting the asset.
The failure mode to avoid is silence, not growth.

**Also learned.** Re-exporting a Pixellab character with added animations changed the cell
size (48 → 56) and the whole row layout, but returned the identical 19 colours. Adding
animations to an existing character is colour-stable; sheet geometry is not. Read geometry
from the JSON, never assume it.

---

## 016 — Sprite sheet resources are generated from Pixellab's JSON

**Decision.** `player_frames.tres` is produced by `make_spriteframes.py` reading
`farmer.json`, not hand-written and not built from assumptions about the sheet.

**Why.** Across two exports of the same character the cell size changed from 48 to 56, the
sheet grew from one row to five, and the row schema itself changed shape — rotation rows
carry a `directions` array, animation rows carry a single `direction` plus an animation
name. Anything hand-written would have broken silently. Pixellab also orders directions as
compass points (south, west, east, north), which is not the order anything else uses.

**Cost.** A build step between art and engine. Worth it: the next re-export costs one
command.

---

## 017 — The first crop is a `CropDef` resource from Stage 2, not hardcoded

**Decision.** `CropDef` (`scripts/resources/crop_def.gd`) and `data/crops/parsnip.tres`
exist from Stage 2. The stage plan originally said "one hardcoded crop", converted in
Stage 4.

**Why.** Hardcoding grow times would break rule 6 (no balance numbers in scripts) for
two whole stages. A small resource costs almost nothing now and shrinks Stage 4 to adding
`ContentDB` and more `.tres` files. Agreed with Dave, 2026-11-14.

**Cost.** Until `ContentDB` arrives the crop is loaded by path. The resource is kept
deliberately small; fields are added when a stage needs them.

---

## 018 — Tools are a `ToolDef` with an embedded `ToolAction`; farm state lives in `GameState`

**Decision.** A tool is one `.tres` file: a `ToolDef` (id, name, energy cost) holding a
`ToolAction` sub-resource whose script does the work through two methods, `can_use()` and
`apply()`. The player asks the selected tool those two questions and never knows which
tool it holds. `FarmData` is a plain `RefCounted` owned by the `GameState` autoload, not a
node in the farm scene and not an autoload of its own.

**Why.** Rule 5. The alternatives were a `match tool.id` in the player (exactly the growing
if/else the rule forbids) or a separate handler registry keyed by id (two places to edit
per tool). Embedding the action in the definition keeps a tool to one data file plus one
small script. Splitting `can_use` from `apply` means energy is only charged when something
actually happens. `FarmData` sits in `GameState` because it must survive scene changes
(DECISIONS 004) and be saved with everything else (Stage 3); a node in the farm scene would
be destroyed on the first trip to town.

**Cost.** Tool behaviour lives in a script referenced from data, so a designer can't invent
a wholly new kind of tool in the inspector alone — but they can create, tune and reorder
tools there freely. The starting toolbar comes from `data/game_rules.tres` until there's an
inventory (Stage 4).

---

## 019 — Pixellab generation moves to the API, from a cloud environment

**Decision.** From the next real art onward, Claude generates through Pixellab's API from
a cloud environment that has network access to it, then verifies and delivers the files.
This supersedes the "two routes" note in `art/STYLE.md`, which said Claude's sandbox could
not reach `api.pixellab.ai`.

**Why.** It removes the manual generate → download → copy loop, and every generation is
checked against the spec and palette, and turned into a `SpriteFrames` from its JSON, in
the same step. Dave still approves each look before it goes in — taste is his call, and
generations cost credits.

**Cost.** Generation depends on that environment being selected for the session. Placeholder
art (decision 014) is still made locally, so code work never waits on it.

---

## 020 — The overnight sequence lives in `TimeSystem`; seeds are tools until there's an inventory

**Decision.** `TimeSystem` (autoload) is the only thing that ends a day, whether from the
sleep key or from energy reaching zero, and it always runs the same order: announce
`day_ended`, `FarmData.advance_day()` (watered crops grow one step, all soil dries), move
the calendar and refill energy, announce `day_started`. Seeds are a `ToolDef` with a
`PlantAction` naming the crop, so they sit on the toolbar and are unlimited. Harvesting is
the interact key (E), free, and not a tool. A planted tile holds its `CropDef` directly.

**Why.** Ordering bugs in the overnight step are the kind that are miserable to find later
(sell before or after growth? dry before or after?), so one place owns the order. Running
out of energy ends the day *deferred*, so the action that spent the last point completes
first. Seeds as a tool reuse rule 5's interface with no new code path; the inventory in
Stage 4 will replace "unlimited" with a count without changing how planting works.
Harvesting by hand costs nothing because the effort was in growing the crop. Holding the
`CropDef` on the tile avoids building `ContentDB` early just to look up an id.

**Cost.** Stage 3 needs an id → `CropDef` lookup to load a save, so a minimal `ContentDB`
will probably be pulled forward from Stage 4 into Stage 3. Sleep is a key press anywhere
until there's a farmhouse and bed. Unwatered crops pause rather than die, for now.

---

## 021 — Locations and seasons are data; the game starts in a boot scene

**Decision.** `LocationManager` (autoload) moves between locations defined as `LocationDef`
resources (id plus a scene *path*), listed in `data/game_rules.tres`. The project's main
scene is now `scenes/boot.tscn`, which sends the player to `GameState.location`. Location
scenes place an arriving player at a named `Marker2D` under `SpawnPoints`. Each season's
look is a `SeasonTheme` resource (only a ground tileset so far), also listed in the rules;
the farm swaps its tileset and redraws on `season_changed`.

**Why.** The seam's real job is to prove nothing important lives in a scene: the farm was
reloaded mid-game in testing and came back with its tilled soil, crop, tool and energy
intact. A scene *path* rather than a `PackedScene` avoids loading every location at startup
and breaks a load loop (rules → location → farm scene → scripts reading the rules) that
stopped the game starting when first tried. The boot scene gives Stage 3's "load the save
or start new" and Stage 9's title screen an obvious home. Swapping one tileset works because
every seasonal tileset will share the base atlas layout, which image-to-image guarantees
(DECISIONS 005).

**Cost.** `main.tscn` is now the farm and not the entry point, a slightly misleading name
kept to avoid churn; F6 on it still runs the farm directly. Seasonal tilesets *must* keep
the base layout exactly, or tiles will draw as the wrong thing.

---

## 022 — Saves are JSON, written each morning, upgraded step by step; a minimal `ContentDB` arrives early

**Decision.** `SaveSystem` (autoload) writes `user://save.json` (on Windows,
`%APPDATA%\Godot\app_userdata\Pixel Harvest\save.json`) as plain JSON:
`{ "save_version": 2, "game": { … } }`. `GameState.to_save()` decides what goes in;
`SaveSystem` decides when, where, and how old versions are upgraded. The save is written
once a day, as the last step of the overnight sequence in `TimeSystem`, and loaded once,
by the boot scene. Every load runs through `_upgrade()`, a chain of one-version steps
(1 → 2 → …). Crops and tools are saved by id and found again through a minimal
`ContentDB` autoload that indexes `data/crops/` and `data/tools/` by their `id` field —
pulled forward from Stage 4, as DECISIONS 020 predicted. F9 starts a new game until there
is a title screen.

**Why.**
- *JSON rather than Godot's own formats.* `ResourceSaver` and `store_var` can embed
  objects and scripts, so loading a save could run code from it, and their files can't
  be read or hand-edited. JSON is inert, opens in Notepad, and is just dictionaries and
  lists — exactly what an upgrade step wants to work on.
- *Once a day, at dawn.* A save is then always a clean morning, never half an action, and
  there's one obvious moment it happens. Quitting mid-day loses that day, as in most games
  of this kind. No player position is saved: every day starts at the spawn point.
- *The whole farm is saved,* terrain and trees included, not just the player's changes. If
  the starting layout is redesigned, existing farms keep the map they were played on rather
  than having crops land in a new pond. Default fields are omitted per tile to keep it short.
- *Names, not numbers.* Version 1 saved the selected tool as a toolbar position and terrain
  as an enum number; both silently change meaning if a list is reordered. Version 2 saves
  the tool id and the terrain name. This was the deliberate break the stage plan asked for:
  the 1 → 2 step converts both, and `tests/saves/v1_example.json` is a version 1 save
  that loads correctly through it. The step keeps its own frozen copy of version 1's
  terrain numbering, because an upgrade must never depend on today's code.
- *Fail safe, never silently.* A save that is damaged, from a newer version, or missing a
  field is moved to `save.unreadable.json` and the game starts new, with the reason in the
  Output panel. A crop or tool the game no longer has is dropped with a warning and the rest
  of the save loads.
- *Saving is armed by the boot scene,* so running `main.tscn` alone with F6 plays a
  throwaway game and can't overwrite the real save.

**Cost.** One save slot (slots are Stage 9). The file is around 30 KB, mostly one line
per tile position. Every future change to saved data costs a version bump and an upgrade
step — that's the point, but it must not be skipped. `ContentDB` only knows crops and tools
until Stage 4 extends it.

