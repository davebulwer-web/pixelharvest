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

*Revisited in 035 (2026-11-15):* the day now has a ticking clock, 6 AM to 2 AM. Energy
is still meant to be what ends a busy day; the clock ends an idle one.

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


---

## 023 — Items: one `ItemDef` for everything carried; the hotbar is a view of the bag; a crop is three files

**Decision.** Stage 4's inventory and economy rest on these choices:

- *One item type.* `ItemDef` (id, name, icon, `sell_price`, `buy_price`) is anything that
  can be carried. `ToolDef` now *extends* `ItemDef`, so tools and seeds are items too.
  Produce is a plain `ItemDef` in `data/produce/`. A price of 0 means "the bin won't take
  it" or "the shop doesn't sell it" — that's the only rule the bin and the shop apply.
- *The hotbar isn't a separate list.* `GameState.inventory` (an `Inventory`: ordered stacks
  of item + count) holds everything. The hotbar is simply the `ToolDef`s in it, in bag
  order; produce is shown beside it but isn't selectable. Seeds have `consumed_on_use`, so
  planting takes one from the bag, and the last packet leaves the hotbar on its own.
  `GameRules.starting_tools` became `starting_inventory`, a dictionary of item → count.
- *A crop is three small files:* `data/crops/X.tres` (how it grows and looks),
  `data/produce/X.tres` (what it gives and its sell price), `data/tools/X_seeds.tres`
  (what plants it, and its shop price), plus a sprite sheet and two icons. `CropDef.sell_price`
  moved to the produce item. `ContentDB` loads them all and *checks they agree* at startup
  — crop without produce, seeds that plant nothing, duplicate ids — naming the file to fix.
- *Prices are only read through `Economy`.* `Economy.buy_price()` / `sell_price()` return
  the item's number today; market days and difficulty (Stage 8) change them in that one
  place.
- *The shipping bin:* a farm object (like a tree) at the end of the path. E while facing
  it moves every sellable item from the bag into `GameState.shipping_bin`. `Economy` sells
  it on `day_ended`, step 1 of the overnight sequence. Because the save is written at dawn,
  after the sale, the bin is always empty when saved and isn't in the save file.
- *Interacting is generic.* E harvests if there's a ready crop; otherwise the player looks
  for a node in the `interactable` group that `occupies()` the facing tile and calls its
  `interact()`. The bin is the first; Stage 7's doors and shopkeepers join the same way.
- *Save version 3.* `tools` became `inventory` (`[{id, count}]`). The 2 → 3 step gives each
  old tool a count of 1 and the old unlimited parsnip seeds a count of 10, and places the
  bin at (13, 12) — all frozen in the step. `tests/saves/v2_example.json` is a real version 2
  save made by the Stage 3 build; both it and the v1 example load through the chain.
- *The shop is a stopgap menu (B),* listing whatever has a `buy_price`. It pauses the game
  while open.

**Why.** One item type means the bag, bin and shop never ask "what kind of thing is
this?", which is what keeps them from growing special cases as content arrives. Making the
hotbar a *view* of the bag avoids two lists that must be kept in step (Stardew's model,
without its fixed slots). Three files per crop is more than one, but each is small, has a
clear job and is editable in the inspector; the alternative — the crop file generating its
seeds and produce invisibly — would have been less typing and harder to understand. The
startup check is the price of spreading a crop over three files, and it's cheap.

**Cost.** Seeds still live in `data/tools/` (they are tools, DECISIONS 020) rather than a
folder of their own — moving `parsnip_seeds.tres` would have meant deleting files on Dave's
machine, which the bridge can't do. The bag has no size limit; whether it should is a
design question for Stage 5. Nothing comes back out of the bin once shipped. Prices are a
first guess (radish 10 → 20 over 3 days … cabbage 60 → 120 over 9; green beans 50, then
15 every 3 days); Stage 5 is the real balance pass. All new art is placeholder.

---

## 024 — Upgrades are data with a small effect script; tool tiers live on the tool; fields start as thicket

**Decision.** Stage 5's progression rests on these choices:

- *Tool tiers are on the tool.* `ToolDef.tiers` is a list of `ToolTier` (name, energy per
  swing, `length` × `width` of the area). Tier 0 is the tool as it comes, one tile. The area
  starts at the tile in front and runs away from the player: 3 × 1 is three in a line, 3 × 3
  a square of nine. The `ToolAction` interface is unchanged — it is still asked about one
  tile at a time, and the player asks it about each tile in the area. A swing costs the
  tier's energy, but never more than doing the same tiles one by one with the basic tool,
  so an upgrade is never worse than what it replaced.
- *An upgrade is an `UpgradeDef`* (id, name, description, icon, price, `requires`) holding
  an `UpgradeEffect` sub-resource — the same shape as a tool and its action. Three effect
  scripts so far: `ToolTierEffect`, `MaxEnergyEffect`, `PlotEffect`. Lasting bonuses are
  *asked for* (GameState adds up what every owned upgrade says), so only "this upgrade is
  owned" is stored; one-off changes to the world (clearing a field) happen once in
  `on_bought()` and are kept because the farm is saved. `requires` makes a line of upgrades
  (wide hoe → great hoe) and the shop shows one step of each line at a time.
- *Fields are thicket.* A new terrain, `THICKET`, impassable and untillable. Each field's
  area is written once, in its upgrade's `.tres`; `FarmLayout` overgrows those areas when it
  builds a new farm, and buying the field turns its thicket to grass. A new game starts
  with the clearing around the path (18 × 13 tiles) and three fields to buy.
- *Sprinklers are items you place.* A `ToolDef` with a `PlaceObjectAction` puts an object
  on the tile; E picks it back up. What objects *are* moved out of `main.gd`'s hardcoded
  list into `ObjectDef` resources in `data/objects/` (scene, what you get back for picking
  it up, which tiles it waters). `FarmData.advance_day()` runs sprinklers *after* the soil
  dries, so you wake to wet soil around each one and those crops grow the next night.
- *Save version 4.* `upgrades` (a list of ids) is added and `max_energy` is dropped — it's
  worked out from the upgrades, so a rebalanced energy upgrade reaches existing games.
  `tests/saves/v3_example.json` is a real version 3 save made by the Stage 4 build.
- *The shop has two columns*: seeds and supplies on the left (anything with a `buy_price`),
  upgrades on the right (whatever Economy says is on offer), and a line underneath
  describing whatever is focused. Items gained an optional `description` for that line.

**Why.** The alternatives for upgrades were a `match upgrade.id` somewhere (exactly the
growing if/else rule 5 forbids) or one upgrade script per upgrade (code for every price
change). An effect script per *kind* of upgrade means a fourth energy upgrade or a better
watering can is one `.tres`. Thicket inside the existing map, rather than new land beyond
the cliffs, keeps fields visible from the start — you can see what you're saving for — and
needs no special drawing, collision or saving: it is just terrain. Asking for bonuses
rather than storing them avoids two numbers (max energy and the upgrades that set it)
that could disagree.

**Cost.**
- Farms saved before Stage 5 have no thicket, so all their land is already open and the
  fields are never offered there (`PlotEffect.is_useful()`). Press Ctrl+N for a new game to
  see the fields. Converting old farms was rejected: it would mean turning land the player
  may have planted into thicket.
- A new *kind* of upgrade (a bigger bag, say) still needs a method on `UpgradeEffect` and a
  small script. Accepted: that is a new mechanic, not new content.
- The thicket tile was added as column 8 of `ground_placeholder.png` (and `8:0`, with
  collision, in `ground_tileset.tres`). Stage 6's seasonal tilesets must keep that column.
- All new art is placeholder: thicket, both sprinklers, the energy and field icons. Tool
  upgrades reuse the hoe and watering can icons.

**Balance, first pass.** Energy per tile, basic → wide → great: hoe 2 → 1 → 0.67, watering
can 1 → 0.67 → 0.44. Starting with 100 energy and parsnips (7 energy a tile over four days),
roughly 50 tiles can be kept going by hand, but early on gold, not energy, is the limit. The
first upgrades (wide can 200g, wide hoe 250g, packed lunch 400g, north field 500g) should
land within the first week or so of careful play; the great tools (800g, 1000g) and the
sprinklers (200g for 4 tiles, 750g for 8) in the second; the last field (2000g) and
Farmer's stamina (3000g) are the long goals. These are guesses until Dave has played it —
every number is in a `.tres` file and can be changed in the inspector.

**Also changed.** "New game" moved from F9 to Ctrl+N. Dave found that F9 pauses the running
project in the Godot editor, so the game never saw it and looked hung. Function keys are
best left to the editor.

---

## 025 — Seasons: 28-day seasons, crops list their seasons, the night of the turn kills, the look is a SeasonTheme

**Decision.** Stage 6's seasons rest on these choices:

- *The calendar.* `GameRules.days_per_season` (28) and the four `SeasonTheme`s in
  `GameRules.seasons` make the year. `GameState.day` is now the day *of the season* (1–28);
  after day 28 comes day 1 of the next season, and after winter, spring of a new year. The
  HUD reads "Spring · Day 5 · Year 1".
- *Crops say when they grow.* `CropDef.seasons` is a list of season ids (`&"summer"`); empty
  means all year. Seasons don't list crops, so a new crop is still only its own three files.
  First assignment, chosen so every season has at least two crops and the starting parsnips
  work in spring: parsnip spring/autumn/winter, radish spring/summer/autumn, potato
  spring/summer, green bean summer, cabbage autumn/winter. `ContentDB` reports a crop naming a
  season that doesn't exist, and warns about a season nothing grows in.
- *Planting out of season simply doesn't happen.* `ToolAction` gained `usable_in_season()`
  (true by default; seeds answer from their crop). The player asks it before anything else,
  so no energy and no seed is spent, and the hotbar greys the packet out and says
  "not in spring" when it's selected. The shop still sells out-of-season seeds — buying ahead
  is planning — marked "off-season", with the seasons in the description.
  *Why not inside `PlantAction.can_use()`:* asking `GameState` from there makes a load loop
  (GameState → rules → seeds → PlantAction → GameState) that stops the game starting — the
  same trap as DECISIONS 021.
- *The turn happens overnight, after growth.* TimeSystem's order is now: day ended, farm
  grows, calendar moves, **if the season turned: out-of-season crops die, `season_changed`**,
  day started, save. A crop on its last night therefore grows and then dies — anything ready
  must be picked before sleeping on day 28. A dead crop vanishes and leaves its soil tilled;
  each one is announced as `crop_died`, and the morning message says how many died.
- *How a season looks is all in its `SeasonTheme`:* the ground tileset (same atlas layout as
  spring's, thicket column included), `object_sprites` (object id → a different picture, so
  far only trees in autumn and winter), and an optional `overlay` scene (winter's falling
  snow, `scenes/snowfall.tscn`, drawn over the world and under the HUD). The farm swaps all
  three on `season_changed`; nothing about what's on the farm changes.
- *Save version 5.* Nothing new is stored, but `day` changed meaning, so the version moved.
  The 4 → 5 step keeps a game's date if it's within the first 28 days, and otherwise restarts
  it at day 1 of spring, so an old farm gets a whole spring before its first season change.
  Loading also keeps the date inside whatever the rules now say, so shortening seasons in
  the inspector can't leave a game on day 40 of 28. `tests/saves/v4_example.json` is a real
  version 4 save made by the Stage 5 build.

**Why.** 28 days lets the Stage 5 upgrade curve (first upgrades in week one, great tools and
sprinklers in week two) play out inside the first spring, and fits the slowest crop (cabbage,
9 days) three times. Making the crop own its seasons keeps rule 3: content is added in one
place. Withering at the turn rather than mid-season is the planning pressure DESIGN.md asks
for, and is easy to read: one morning, one message. Withered crops vanishing (rather than
leaving a dead plant to clear) keeps the farm state unchanged and the save the same shape.

**Cost.**
- Old farms keep crops that are now out of season until the first turn (a version 4 farm's
  cabbages grow through spring and die at summer). Accepted; nothing is lost early.
- All seasonal art is placeholder, recoloured from the spring placeholders by a script and
  exactly on `art/palette.png`: summer, autumn and winter ground tiles, autumn and winter trees.
  The real versions are Pixellab image-to-image from a real base tileset (DECISIONS 005),
  from the cloud environment (DECISIONS 019). Buildings, the bin and sprinklers have no
  seasonal versions.
- 28 days is a lot of sleeping to see a season change while testing: set `days_per_season`
  low in `data/game_rules.tres`, and put it back.

---

## 026 — Real ground and trees: Pixellab terrain tiles, seasons by per-tile image-to-image, palette grows to 41

**Decision.** Stage 6 session 2 replaced every ground and tree placeholder with Pixellab art.

- *Base (spring) ground* comes from Pixellab's terrain-tileset tool (`/create-tileset`,
  standard, 16 px, 1 generation per pair of terrains). Only the plain, all-one-terrain tile
  of each pair is used. The blends between terrains are thrown away, because the farm draws
  one tile per cell. Those plain tiles repeat with no visible seam.
- That tool can't be held to a palette, so each tile is mapped onto 2 or 3 hand-picked
  palette shades by brightness rank (darkest pixels to the darkest shade, and so on).
  Plain nearest-colour snapping flattened the grass to one green, which is why it isn't used.
- *Seasons* are image-to-image from the base, one tile at a time: Pixen edit (1 generation)
  on that tile repeated 3×3, keeping the centre copy. Editing a repeated tile keeps the
  result seamless, and a whole strip edited at once got snow borders around each tile.
  Only tiles that change in a season were edited: winter all nine, autumn grass, flowery
  grass, path and thicket, summer grass, flowery grass and thicket.
- Pixen pays no attention to the palette, so results are snapped to the nearest palette
  colour. Two touch-ups were done by script, not by generation. Summer grass is moved one step
  darker on the green ramp because Pixen barely changed it. Winter's dry tilled tile is
  the wet one with its soil lightened, so the pair matches.
- *Trees* are now 32×48 (pixflux, palette-forced), not 16×32, so they stand taller than
  the farmer. Autumn and winter trees are Pixen edits of it. `scenes/tree.tscn` lifts the
  sprite by 22 px so the trunk's base sits on the cell, and the collision box is unchanged.
- *Palette grows from 33 to 41.* Four snow and ice colours (the palette had no cool
  whites, which is why the placeholder snow was peach), two autumn oranges and two
  olive greens for autumn grass. Accepted deliberately, as DECISIONS 015 allows.
- The atlas layout is unchanged (grass, flowery grass, path, tilled, wet tilled, water,
  stone, cliff, thicket in columns 0–8), so no code changed. Files were renamed from
  `*_placeholder.png` to `ground_<season>.png`, `tree.png`, `tree_<season>.png`.

**Why.** Drawing all nine tiles in one pixflux strip gave nearly flat single-colour tiles.
Tiles Pro (10 generations) drew a visible grid on the grass. The terrain tool gave the best
texture for the least spend. Editing one tile at a time is what keeps the seasons true to
the base, which is the point of DECISIONS 005.

**Cost.** About 42 generations including tests and the failed routes. Known weak spots that could
be redone cheaply (1 generation each): the winter path and winter thicket repeat visibly
over large areas, and the cliff's crack pattern repeats. The bin and sprinklers still have
no seasonal versions.

---

## 027 — The town: shops are rooms with data, doors are walk-in zones, the shopkeeper opens the menu

**Decision.** Stage 7 session 1 adds the town and three shops. The pieces:

- *Locations again, not a new system.* The town, and each shop interior, is a `LocationDef`
  (DECISIONS 021). `LocationManager` changed only by two lookups (`current()`, `all()`).
  A shop's `LocationDef` also says where its door is on the town map (`outside`,
  `door_cell`) and carries its front picture (`exterior`), and points at a `ShopDef`.
  `town.gd` builds a `Building` for every location whose door is on the town, so **a new
  shop is data**: a `ShopDef`, a `LocationDef`, two pictures, and a line in
  `game_rules.tres`. No code names a shop.
- *One interior scene for every shop* (`interior.tscn`, `interior.gd`). The room is the
  same; the `ShopDef` supplies the shopkeeper, their greetings and what the menu offers.
  Chosen over a scene per shop because there is nothing yet that differs but the keeper
  and the stock, and three copies of a room would drift apart.
- *What a shop sells is a filter over everything, not a list.* `ShopDef` has switches
  (`sells_seeds`, `sells_supplies`, `upgrade_categories`, `buys_produce`), and
  `Economy.shop_stock()` / `upgrades_on_offer(shop)` apply them to `ContentDB`. So a new
  crop's seeds appear at the seed shop with nothing edited (rule 3). Each `UpgradeEffect`
  names its own `category()` (tools / energy / land). `ContentDB` warns about any
  upgrade no shop sells.
  - Seed shop: seeds. Blacksmith: sprinklers and tool upgrades. General store: energy and
    field upgrades, and it buys produce.
- *The general store pays 80% now; the shipping bin pays 100% tomorrow.* The rate is
  `ShopDef.produce_pay_rate`, and prices still pass through `Economy` (`store_price`,
  `sell_to_shop`), so market days can adjust them in one place. The gap is what keeps the
  bin worth using. It's a first guess; Dave's play decides.
- *Doors are walk-in `ExitZone`s* (an `Area2D`), not an E-key action: walk into the doorway,
  arrive inside. The farm gate, shop doors, and the doormats are all the same class. Shop
  doorways are 32px wide and the gates two tiles tall, because a one-tile gap with a 12px
  player demands pixel-perfect aim; the first test run showed exactly that.
- *Talking is `E` at the counter, via `EventBus.npc_talked_to`.* `Npc` (an `interactable`
  like the shipping bin) only announces the id. The interior listens for its own keeper
  and runs the dialogue box, then the shop menu. Stage 8's quest characters can listen to
  the same signal. The keeper can't be reached, so facing any counter cell counts.
- *The B shop key is gone.* The menu now opens only at a shop counter (`ShopMenu.open(shop)`),
  as DECISIONS 023 said it would. The `open_shop` action was removed.
- *Away from the farm, farming is off.* `Player.can_farm` is switched off by the town and
  the interiors. Otherwise Space would hoe the farm's tiles at the same coordinates, E
  would harvest invisible crops, and Enter would end the day with the player standing in
  town. Enter in town says to walk home. A save is therefore only ever written on the farm.
- *The farm gets a gate: save version 6.* The cliff at the west end of the path becomes
  two path tiles (`FarmLayout.TOWN_GATE`). The map is saved, so old farms need the same
  change: the 5 → 6 step opens those two cells (frozen in the step, like earlier ones).
  `tests/saves/v5_example.json` is a real version 5 save from the Stage 6 build.
- *Shared pieces pulled out so the town didn't copy the farm:* `scenes/hud.tscn` (the
  HUD, now instanced by farm, town and interior), `SeasonLook` (season ground, object
  skins and overlay), `GroundTiles` (atlas coordinates). The town uses the farm's
  seasonal tilesets and the same winter snow.
- *The town has no state.* No `FarmData`: its map is a function (`TownLayout`), so there
  is nothing in it to save.

**Why.** The Stage 2 seam was built for this and held: the town needed no change to saving,
the calendar or the farm's logic beyond the gate. Keeping the shops as data is rule 3 applied
to places, and is what will let Stage 8's market and quest characters appear without code.

**Cost.** Interiors are identical apart from keeper and stock. There is no day or night in
town, no opening hours, and no way to see the bin's value there. Walking to the shops
costs nothing (no clock to spend), so the town is a convenience tax of a minute, not a
decision, until Stage 8 gives it reasons to be visited on particular days. All town art
is placeholder (list in STAGES.md).


---

## 028 — Real town art: pixflux redraws of the placeholders, interior tiles from the terrain tool

**Decision.** The Stage 7 placeholders are replaced by Pixellab art, file for file, so no
code or data changed.

- *Shop fronts, shopkeepers, counter and shelf* are pixflux (1 generation each,
  `color_image` = `art/palette.png`, so they land exactly on the palette) with the
  **placeholder as `init_image`**. Strength 60–130 keeps what the code depends on (the
  80×64 outline, the 32px doorway centred on the bottom row, the keeper's size and feet
  position) while Pixellab redraws the detail. At 300 it barely changed the placeholder;
  with no init it drew an isometric house and a keeper too big for the frame.
- Keepers were nudged by a pixel so their feet sit on the same row as the placeholder's
  (what `Npc.SPRITE_OFFSET` expects). The blacksmith's sign came with made-up lettering,
  replaced by script with a small anvil in the sign's own colours.
- *Interior tiles*: one `/create-tileset` pair (wooden plank floor / red woven rug) gave
  the plain floor and rug tiles, mapped onto palette shades by brightness as in 026.
  A second pair (beam / plaster wall) came out flat and wasn't used. The floor variant
  (knots), the wall top (the planks on the two darkest browns) and the wall face (plaster
  over a wainscot made from the planks turned upright) are built from those tiles by
  script, so the room shares one wood. A pixflux wall strip was tried and was muddy.

**Why.** Using the placeholder as the starting image is what makes these drop-in: the
layout the code relies on is already in the picture. Deriving the room's other tiles from
one generated plank tile keeps floor, walls and trim matching.

**Cost.** 20 generations including the look test and dead ends. The counter is two copies
of one 48px picture side by side, so its rounded ends meet in the middle; a single 96px
counter would need a code change in `interior.gd`.


---

## 029 — Townsfolk are data, decoration is ObjectDefs, the notice board is worked out, not written

**Decision.** Stage 7 session 2 gives the town a designed map, people and a notice board.

- *Townsfolk are `CharacterDef`s* (`data/characters/`): id, name, picture, which location,
  the cells they stand on (`spots`) and what they say (`lines`). `town.gd` builds an `Npc`
  for everyone whose `location` is the town, so **a new townsperson is a .tres and a
  picture**, no code. Chosen over reusing `ShopDef` (a shopkeeper comes with a counter and a
  menu; a townsperson has neither) and over one scene per character (the only differences
  are data). Stage 8's quest characters are meant to be the same resource with more fields.
  - One line a day and one spot a day, both cycling through the lists by the day of the
    season (the shopkeepers' rule). The mayor moves round the square and the angler round
    the pond, so the town looks a little different each morning with no wandering code.
  - Talking uses the `npc_talked_to` signal the shopkeepers already use. Shop ids and
    character ids share that one namespace, so `ContentDB` refuses a character with a
    shop's id, and also checks the location exists, there is at least one spot, and there
    is a picture and something to say.
- *Decoration is `ObjectDef`s* (fountain, bench, lamp post, flower bed, fence, notice board),
  the same resource as the farm's tree and bin. `TownLayout.OBJECTS` lists cell → object
  id; the town's trees moved into that list too. Reusing `ObjectDef` means every piece can
  wear a seasonal picture through `SeasonTheme.object_sprites` with no code: winter now has
  a frozen fountain and snowed-over flower beds.
- *The map stays a function* (`TownLayout`), not a resource or a hand-painted TileMap.
  Considered painting it in the editor: easier to look at, but the town would then be the
  only map not built from code, and a shop's door cell (from its `LocationDef`) would have
  to be kept in step with paint by hand. The layout is drawn as a comment map at the top of
  the file. The square and the pond path are rectangles of path tiles.
- *The notice board is worked out each time it's read* (`Notices.today()`): the date and
  how long the season has left (with a warning from three days before the turn), what
  grows now and where to buy the seeds, and what grows next season. All from the calendar
  and `ContentDB`, so a new crop is on the board the day its files exist. Reading it is
  announced as `EventBus.notice_board_read`, which Stage 8's market days and requests can
  also answer. It's a two-tile board, so facing either half counts.
- *Nothing is saved.* People and decoration come from data and the day, so there's no
  save version change. Old saves load as before.

**Why.** It's rule 3 applied to people and props: the town should fill up in Stage 8 by
adding files. The notice board is the cheapest useful way to make the town worth a visit
before Stage 8 gives it events: it answers "what can I plant, and how long have I got",
which until now meant remembering the crop files.

**Cost.** Townsfolk stand still (no walking between spots during the day), and only face
south. Lines don't react to anything yet: no "you sold me 40 parsnips". All the new art is
placeholder (STAGES.md lists it). The garden's fence is horizontal pieces only, so it is
open at both ends rather than closed with corner posts.

---

## 030 — Real town decoration and townsfolk: pixflux redraws, winter versions by recolour

**Decision.** The Stage 7 session 2 placeholders are replaced by Pixellab art, file for file
(same sizes, same bases and feet rows), so no code or data changed. Same route as 028.

- *Fountain, notice board, Mayor Bramble, Wren*: pixflux, `color_image` = `art/palette.png`,
  `init_image` = the placeholder. The people needed strength 150: at 80 the mayor came out
  half as wide again as the shopkeepers. The fountain needed 140 to keep its full 48px width.
- *Bench, lamp post, flower bed, fence*: too small for pixflux (area under 1024), so each
  placeholder was centred on a transparent 32×32 canvas, generated, and the middle cut back
  out to the original size. The fence's posts sit on its edges, so pieces still join.
- *Winter versions are recolours, not fresh pictures.* Asked for a frozen fountain, pixflux
  kept the water teal; asked for a snowed bed, it kept the flowers. So the frozen fountain is
  the generated winter fountain with its water shades mapped to the palette's ice shades, and
  the snowy bed is the real bed with its leaves and flowers mapped to snow shades. Both share
  every other pixel's shape with their summer picture, so the season change doesn't jump.
- *The notice board's roof* came with garbled lettering; it was repainted flat by script in
  its own reds. The notices are blank paper; the game draws the real text when it's read.

**Why.** As 028: starting from the placeholder is what makes them drop-in. Recolouring for
winter is the same rule as 005 (seasons derived from one base) applied to single objects.

**Cost.** 12 generations including the look test and its two rejects (about 27 left).


---

## 031 — Grass variety: each grass tile turned at random, plus a row of small details

**Decision.** Dave found the grass plain and visibly repeating (a diagonal lattice, because one
16 px tile was laid the same way everywhere). Two changes, both cosmetic, nothing saved:

- *Every grass tile is laid down turned or mirrored*, one of the eight ways a square can lie,
  chosen from its cell position. Godot does this from the one tile in the image: the
  transform flags (`TileSetAtlasSource.TRANSFORM_FLIP_H` and friends) go in `set_cell()`'s
  alternative-tile argument, so no extra pictures and no tileset changes. The grass is noisy
  enough that turned tiles still meet without a visible seam. This alone removes the lattice.
- *Row 1 of each season's ground image holds eight "detail" tiles*: plain grass with
  something small drawn in the middle. Spring has tufts, clover, daisies, pink flowers and a
  pebble; summer poppies, cornflowers and a wild rose; autumn fallen leaves, mushrooms, a
  toadstool, a twig and acorns; winter grass through snow, a snow-capped stone, holly, a pine
  cone and an ice puddle. About 9% of grass cells show one (15% the old flowery tile), and a
  detail is only mirrored left-right so things still grow upwards.
- *The edges of a detail tile are plain grass*, which is what keeps it seamless. The script
  `art/build_ground.py` draws `art/ground_sources/grass_details/<season>.png` (a 128×16
  strip) over that season's grass and writes row 1.
- `GroundTiles` owns all of it: `grass_for()` picks the tile, `transform_for()` the turn, and
  `draw()` is what the farm and the town both call. Which cell gets what comes from `hash()`
  of the cell, so it is the same every run and never stored.

**Why.** Turning tiles is free and fixes the repeat everywhere at once; details give the
"organic" scatter Dave asked for at a fixed, small cost. Keeping details inside one tile (not
a separate decoration layer or objects) means no new nodes, no save change, and the season
swap carries them for free because every season shares the same atlas layout (026).

**Cost.** 24 generations including the look test, mostly redos: pixflux kept drawing a little island of soil under
every detail. What worked was giving it an `init_image` of earlier soil-free details
(strength 200–250). Asking it for "no soil" made it worse. A pebble and the autumn dry tuft
are recolours of other details; a dark blob under the toadstool was removed by script.
To change a detail, edit its strip and re-run the script. The path and thicket followed
in 032.

---

## 032 — A calmer dirt path with details, a cobbled town square, a snowy winter thicket

**Decision.** After 031 Dave found the path jarring: the old path tile had dark marks
along two of its edges, so a road of them drew a grid. Same session, same approach:

- *New dirt path* from the terrain tool (`/create-tileset`, chained to the grass base): a
  smooth packed-earth tile, mapped onto two palette browns by brightness. Spring, summer
  and autumn share it. Winter's path is the same grain recoloured to trodden snow (ice
  blues), which also replaces the old winter path whose brown cracks drew a grid.
- *Path details* in row 2 (four per season: pebbles, a twig, a weed, fallen leaves in
  autumn, snow pieces in winter), on about 12% of path cells, like the grass details.
- *Path and thicket are now turned at random* like grass. The thicket's collision box is the
  whole square, so turning it changes nothing.
- *Winter thicket* is now spring's bushes recoloured into snow and its shadow. The old one
  was a field of black twigs that read as a pattern.
- *The town square is cobbled.* A new tile, `GroundTiles.PAVING`, at row 3, column 0, made by
  the terrain tool (small irregular cobblestones, mapped onto warm palette shades; winter is
  snow-dusted by recolour). `TownLayout` uses it for `SQUARE` only; the road and the pond
  path stay dirt. Paving is not turned, because its stones only line up one way round.
- Everything in rows 1–3 and the path in row 0 is rebuilt by `art/build_ground.py` from
  `art/ground_sources/` (the raw Pixellab tiles and the detail strips).

**Why.** The path's problem was the tile itself, so turning it alone wasn't enough (tried
first). A plaza paving that differs from the road makes the square a place, which is what
Dave asked for.

**Cost.** 2 generations and about 2 cents of the USD credit (dirt, three cobble attempts, one failed snowy-thicket tileset).
No save change: which tile a cell shows is still only drawing.

---

## 033 — The farmhouse: a Building on the farm, the bed ends the day, every morning starts at home

**Decision.** Stage 7's farmhouse and bed, on placeholder art.

- *The farmhouse is a location like a shop* (`data/locations/farmhouse.tres`): its door is
  on the farm (`outside = farm`, `door_cell = (8, 11)`, north of the path), and it has an
  exterior picture. The farm builds a `Building` for every location whose door is on it,
  exactly as the town does for its shops; `LocationManager.buildings_on(id)` answers both.
  Inside is its own small scene (`farmhouse.tscn`, `scripts/farm/farmhouse.gd`) using the
  shops' interior tiles: a bed, a table, a rug and the door. Not the shared shop interior,
  because that room is built round a counter and a keeper.
- *The ground under the house is saved as BUILDING terrain.* `FarmData` is the truth about
  the farm (rule 1), so the hoe, seeds and sprinklers must learn from it that the house is
  there, not from the picture. `BUILDING` is a new `Terrain` on the end of the enum: drawn
  as grass (so gaps at the edge of a future picture show grass), never tilled or built on.
  `FarmLayout` works the cells out from the building's picture size and door
  (`Building.footprint`), so moving the house is a data change for new games.
- *The bed is an interactable* (`Bed`, like the shipping bin): face it, press E,
  `TimeSystem.end_day()`. Enter no longer sleeps anywhere; it now says where the bed is.
  Considered keeping Enter as a shortcut, but the point of a bed is that ending the day is
  a place you walk to.
- *Every morning starts at home.* `game_rules.tres` names `home_location`. If the day ends
  while the player is elsewhere (energy ran out in the field), `TimeSystem` first takes
  them home and waits for the farmhouse to open, then runs the night. The night happens in
  the scene the morning is seen in, so the HUD that collects the bin's sale and the season's
  losses is the one that shows them. The HUD starts dark when it opens mid-night.
- *A new game starts in the farmhouse* (`starting_location`), beside the bed.
- *Save version 7.* Old farms need the house: the 6 → 7 step turns the frozen cells
  (6,8)–(10,11) into BUILDING, clears anything on them (crops there are lost, sprinklers go
  back into the bag, the farm never had a tree there), and moves the player home.
  `tests/saves/v6_example.json` is a real version 6 save from the Stage 7 build, with crops,
  a tilled cell and both sprinklers on the house's ground.

**Why.** It's the seam doing its job again: a building on the farm is the shop pattern
pointed at a different map, with no new kind of thing. Making the bed the only way to end
the day by choice gives the farmhouse a reason to exist, and waking at home is the
convention the genre has taught players.

**Cost.** One more file each for the house and its room. Ending the day from the field
now takes a walk home (a few seconds). Collapsing from exhaustion has no penalty beyond
the day ending, as before. The house has no winter roof yet, and all three pictures
(farmhouse, bed, table) are placeholders for a Pixellab session.

## 034 — Real farmhouse art, a winter roof by season, and an animated fountain

**Decision.** The farmhouse, bed and table placeholders from 033 are replaced with Pixellab
art, and the town fountain plays Dave's own Pixellab animation.

- *How the art was made.* `create-image-pixflux` with the placeholder as init image and
  `art/palette.png` as colour image, as for the town (030). Dave picked the house from
  three look tests (init strength 90, the cottage with grey trim and window boxes). The
  bed and table were drawn centred on a 32×32 canvas (pixflux needs at least 1024 px of
  area) and cropped back to 16×32 and 16×16. Every picture sits on the palette.
- *The winter roof is a season picture, not a second building.* Pixflux won't paint snow
  (030), so `farmhouse_winter.png` is the same house with the roof, chimney top and window
  boxes recoloured to the palette's snow whites by a short script. `Building.create` now
  asks `SeasonLook.skin_object` for the building's location id, so a season can give any
  building its own picture with one line in its `object_sprites` (winter.tres:
  `&"farmhouse"`). The seasonal picture must be the same size, because the walls and the
  farm's BUILDING footprint come from the picture's size.
- *The fountain animates through a sprite sheet.* Dave's animation is nine 48×40 frames in a
  3×3 grid, saved over `fountain.png`, so the fountain's ObjectDef and the town map are
  unchanged. `SheetAnimation` (a Sprite2D script) works out the grid from the picture's size
  each frame and loops it at 8 fps. Considered an AnimatedSprite2D, but SeasonLook swaps
  the `texture` of a Sprite2D called "Sprite", and winter's frozen fountain is one still
  frame: with a sheet-reading Sprite2D the swap just works, and frozen water stands still.
  Six of the sheet's colours were a shade off the palette (19 pixels) and were snapped to
  the nearest palette colour.

**Why.** It keeps seasons as pure looks (005, 025) and reuses the one mechanism already
used for trees and the fountain, instead of teaching the farm about roofs.

**Cost.** One small script and one extra picture. Any future animated object needs its
sheet laid out in frames of the size set on its `SheetAnimation`.


---

## 035 — A ticking clock, 6 AM to 2 AM; shops keep hours; energy stays the main brake

**Decision.** The day now has a clock (this revisits 003, which had none). Dave chose it
from three options on 2026-11-15:

1. *A ticking clock* — chosen. Time passes while the game runs, 10 minutes per 7 real
   seconds, so 6 AM to 2 AM takes about 14 minutes of play.
2. *A clock that moves only when you act* (each action or door costs minutes). Rejected:
   two things to budget per action, and standing still would freeze the world.
3. *The clock as a picture of energy spent* (full = 6 AM, empty = midnight). Rejected:
   nothing new to balance, but walking and waiting would never cost time, so opening hours
   would mean "shop before you farm", not a time of day.

How it works:

- *Where time lives.* `GameState.minutes`, minutes after midnight (6 AM = 360). Past
  midnight it keeps counting (1 AM = 1500) because it's still the same day until you sleep.
  `TimeSystem._process` moves it on in 10-minute steps and announces `time_changed`.
  Because TimeSystem pauses with the game, the clock stops in the shop menu and in
  conversations, which already pause the tree.
- *The numbers are data* (rule 6): `day_start_minutes`, `day_end_minutes`,
  `seconds_per_ten_minutes` and `late_warning_minutes` in `game_rules.tres`. Setting
  `seconds_per_ten_minutes` to 0 stops the clock, for trying things out.
- *2 AM is the third way a day ends*, alongside the bed and running out of energy. It runs
  the same night (`TimeSystem.end_day`): taken home, the night happens, and the morning says
  "You stayed out too late and woke up at home". There's no penalty beyond that, the same as
  running out of energy. At midnight the HUD warns once.
- *Not saved.* The game only saves at dawn, so a save is always 6 AM; loading sets the clock
  to the start of the day. No save version change (still 7).
- *Opening hours are on the ShopDef* (`opens_at`, `closes_at`, in minutes like the rules;
  both 0 means never closes). Seeds 9 AM – 5 PM, general store 8 AM – 8 PM, blacksmith
  10 AM – 4 PM. A shop's door asks `LocationManager.closed_message()` before taking you in;
  shut, it says "Hollis's Seeds is closed. Open 9 AM – 5 PM" and you stay outside. If the
  shop shuts while you're in it, you can stay and walk out, but the keeper turns you away
  instead of opening the menu. The notice board's last page lists every shop's hours.
  The closed shop's doorway also turns solid (`Building`'s `ClosedDoor`, top 10px of the
  door cell), so the player stops in front of the building instead of walking up into
  the doorway and vanishing behind its front (Dave's snag, 2026-11-15). The bottom 6px
  stay open so the player still touches the door and is told the hours.
- *`Clock`* (`scripts/clock.gd`) is the one place minutes become "9:30 AM", so the HUD,
  shops and notice board agree. It touches no autoload, so ShopDef can use it (021).

**Why.** It's what players expect from a farming game's day, it gives the town a reason to
be visited at particular times (the cost noted in 027), and with a 20-hour day energy
still normally runs out first, so the upgrade curve of 003 mostly holds.

**Cost.** Two resources to balance now, if lightly: a player with lots of energy late in the
game may find the clock is what ends their day. Dawdling now costs something, which is the
point but changes the feel. There is no evening light yet, so midnight looks like noon; a
time-of-day tint is the obvious next step and can listen for `time_changed`.

---

## 036 — Evening and night light: one tint from the clock, lamps that glow

**Decision.** Outdoor locations (the farm and the town) darken through the evening, from
the clock. A `Daylight` node (`scenes/daylight.tscn`, `scripts/daylight.gd`) is a
`CanvasModulate`: it multiplies the colour of everything in the world, but not the HUD,
which is on its own CanvasLayer. It listens for `time_changed` and fades to the new colour
over 2 seconds, so the 10-minute steps of the clock (035) don't show as jumps.

- *The colours are data* on the scene's `sky` property: minutes after midnight (as the
  clock counts) → colour, blended between neighbours. White until 5 PM, golden by 6:30,
  rose at 8, blue twilight at 9:30, night from 11 PM until 2 AM; a slightly warm dawn at
  6 AM that clears by 8. Change them in the inspector on `daylight.tscn`, no code.
- *Interiors stay lit* simply by not having a Daylight: the farmhouse and the shops look
  the same at any hour.
- *One tint per scene.* Godot only honours one CanvasModulate per canvas, and winter's
  chill was already one (in `snowfall.tscn`). So the chill moved to
  `SeasonTheme.light_tint` (winter: pale blue; others: white) and Daylight shows
  time colour × season colour. The snow overlay is now just the falling snow.
- *Lamps glow.* Anything in the `night_lights` group is faded in as it gets dark (by its
  alpha), fully on at the darkest colour in `sky`. The town's lamp posts have a `Glow`: a
  soft warm circle drawn with additive blending above the lamp head. Because it's worked
  out from the colours, moving dusk in the inspector moves the lamps with it.

Options considered:

1. *CanvasModulate + glow sprites* — chosen. Cheap, the same on every renderer, and one
   node per location.
2. *Godot's 2D lights (PointLight2D) on the lamps.* Tried first: in testing they drew with
   hard straight edges. A sprite is simpler and predictable.
3. *A full-screen colour rectangle over the world.* Would darken but can't be lit by
   lamps without shaders, and would also cover things that should sit above it.

Gotcha found on the way: an additive sprite at the same z as the lamp was partly drawn
*under* the ground (cut off in straight lines along tile blocks), so the glow sits at
`z_index` 1. It draws over the player when you stand right by a lamp, which reads as being
lit by it.

**Not done:** shop and house windows don't glow (each building picture has its windows in
different places, so it would need a glow position per `LocationDef`, or a "lit windows"
version of each picture). Easy to add later with the same `night_lights` group. No save
change (still 7): the time isn't saved and the light follows it.

