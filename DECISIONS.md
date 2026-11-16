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


---

## 037 — Calendar events are worked out from the date; market day is stalls of ordinary shops

**Decision.** Stage 8 session 1 adds calendar events and the first of them, market day.

- *`CalendarEvent`* (`data/events/`, loaded by `ContentDB`): id, name, a line for the notice
  board, `first_day`, `every_days`, optional `seasons`, the `location` it happens in, and
  its `stalls`. Days are counted straight through the game (`GameState.day_number()`: spring
  day 1 of year 1 is day 1), so "every 7 days" doesn't restart each season. Market day is
  day 3 and every 7th day after: days 3, 10, 17 and 24 of every season (28 is a multiple
  of 7), so the first one comes on the third morning of a new game.
- *Nothing is saved.* Whether today is market day follows from the date
  (`GameState.events_today()`), like the townsfolk's spots (029). No save version change
  (still 7), and changing the numbers in `market_day.tres` changes every game at once.
- *Announced, and asked.* Each morning, after `day_started`, TimeSystem announces
  `EventBus.calendar_event_began(id)` for each of today's events; quests (session 2) can
  listen. On loading a save nothing is announced, so anything that cares asks
  `GameState.events_today()`. The HUD's date line says "· Market day", and so does the
  morning message; the notice board has a page for it (today, with its hours, or when the
  next one is: "Next market day: in 2 days, spring day 3").
- *A stall is a `StallDef`: an ordinary `ShopDef` plus a cell and a picture.* So a stall
  keeper has greetings, opening hours and stock exactly like a shop indoors, and the shop
  menu needed almost nothing. The talking (closed? greeting, then menu) moved out of the
  interior into `ShopCounter`, which the interior and the town both use. The town builds a
  `Stall` (a picture and a solid counter, 3 cells wide) and its keeper (an `Npc` standing
  one row behind, answering E on any counter cell) for every stall of today's events in
  town. Stalls are up from 6 AM (before 8 the keeper says "Not open yet") and packed away
  at closing time (2 PM), so the square is empty by the evening.
- *The two stalls*, in the bottom row of the square either side of the fountain:
  - *Rosa's Produce Stall* buys produce at 125%, paid now: better than the shipping bin
    (100%, overnight) and the general store (80%, now). `ShopDef.produce_pay_rate` now
    goes up to 2.0. A stall that only buys shows only its selling list.
  - *Fennel's Seed Cart* sells three rare seeds you can't get from Hollis: strawberry
    (spring, ready in 8 days, then every 3; 100g seeds, sells 40g), melon (summer, 12
    days; 120g, sells 250g) and pumpkin (autumn, 12 days; 140g, sells 280g). Off-season
    ones are still sold, marked, so you can buy ahead.
- *"Only sold here" is on the item:* `ItemDef.sold_only_by` (shop ids). Empty keeps the old
  rule (the shop's switches decide). Chosen over a "rare" flag because it says *where*, so
  a later event or shop can have its own exclusive stock with no code. ContentDB checks the
  shop ids exist, and the notice board lists such crops as "Rare seeds from Fennel's Seed
  Cart: Strawberry" rather than under Hollis.
- The mayor's two spots in the bottom of the square moved (one to the middle of the bottom
  row, one by the notice board) so he never stands inside a stall, and the tree below the
  seed cart moved four cells east so it doesn't hide it.

Options considered for the market's place: a new location (a market field off the road) —
more to walk and a new map for one day a week; or stalls in the square — chosen: it's where
people already go, and it's busy on market day and plain otherwise.

**Why.** Rule 3 again: a second event, another stall, or another exclusive item is files,
not code. Working events out from the date keeps them out of the save, which is what made
the townsfolk cheap too.

**Cost.** Prices are first guesses (the melon and pumpkin are deliberately much better
per day than cabbage: rare is meant to be worth the trip). Stalls only stand in town. The
market doesn't move prices anywhere else (the bin and shops pay as usual). All new art is
placeholder: two stalls, two keepers (recoloured from existing keepers), three crop
sheets, six icons.

## 038 — Requests are data with a goal script; progress comes only from EventBus

**Decision.** Stage 8 session 2 adds the townsfolk's requests (quests), and three people
who make them.

- *`QuestDef`* (`data/quests/`, loaded by `ContentDB`): id, title, `giver` (a
  CharacterDef id), a `goal`, what they say (`offer_lines`, `reminder_line`,
  `thanks_lines`), a reward (`reward_gold`, `reward_items`), and when it's offered:
  `first_day` (a day number, as in 037), `seasons`, `on_event` (a CalendarEvent id, so a
  request can be asked only on market day) and `requires` (another request finished
  first, which is how one person's requests come in a chain). Each person asks one thing
  at a time; they ask the first one in `first_day`, then id, order that's available.
- *A goal is a small script*, `QuestGoal` with one subclass per kind, like `ToolAction`
  and `UpgradeEffect`: `DeliverGoal` (bring N of an item; it looks in the bag, and the
  hand-in takes them), `HarvestGoal` (pick N of a crop after accepting; you keep them) and
  `SellGoal` (sell N gold of produce, by the bin, a shop or a market stall). A new request
  of an existing kind is a `.tres`; a new kind is one small script.
- *Progress comes only from EventBus.* The new `Quests` autoload listens to signals that
  already existed (`crop_harvested`, `items_shipped`, `items_sold_to_shop`, `item_bought`)
  and offers each to every active request's goal (`counts(event, args)`), which says what
  it's worth. The goal never connects to anything and touches no autoload. This was the
  stage's exam: **no farming, bin or shop code changed** for quests. The Quests listeners
  are deferred, so the HUD's "Harvested 1 Strawberry" comes first and the request's
  "Pip's strawberries: 2 / 3" shows over it.
- *Talking is a question, not a signal.* When someone in town is spoken to, the town asks
  `Quests.talk(id)`: it returns what to say about a request (asking one, a reminder with
  progress "(3 / 5)", or taking it in and paying) or nothing, and then they say their usual
  line for the day. It's asked directly, like ContentDB, because the town has to know the
  answer before deciding what to say. Accepting is just listening: nothing to confirm.
- *What the player sees.* A "!" over someone's head when they have something to ask, a
  "?" when you have what they asked for (bobbing labels, made by the town, asked of
  `Quests.marker_for`). J opens the request log at the top right (`quest_panel.gd`, part
  of the HUD scene, so it's everywhere); the game keeps running while it's open. The
  notice board says who wants a hand today. When a request has everything it needs, the
  message line says "done! Go and see Mabel". New EventBus signals: `quest_started`,
  `quest_progressed`, `quest_completed`.
- *Saved: only where the player has got to.* `GameState.quests` is a `QuestLog` (like the
  Inventory, plain data): request id → active or done, and a running count. Save version
  8; the 7 → 8 step adds an empty log. A request since removed from the game is dropped
  with a warning on load. `tests/saves/v7_example.json` was made by the version 7 game.
- *The first requests* (first guesses at the numbers):
  - The mayor, from day 1: sell 200g of produce. 50g and 5 potato seeds.
  - Mabel the baker (new, by the garden): 5 parsnips in spring (250g); then 5 potatoes in
    spring or summer (400g); then one pumpkin in autumn (150g and a sprinkler), which
    needs Fennel's market seeds.
  - Pip (new, a child near the square): on a spring market day, asks you to grow and pick
    3 strawberries (200g of pocket money; you keep the strawberries).

Options considered for where progress lives: each goal connecting itself to EventBus when
its request starts (neat, but then data resources hold live connections and touch an
autoload, and they're shared between games — a new game would inherit the old one's
hooks); or a counter per signal name in the QuestDef (no scripts at all, but every new
kind of request would have to be squeezed into "count this signal", and "bring 5" isn't a
signal). Chosen: one service listens, goals answer questions.

**Why.** Rules 2 and 3. Requests sit on top of the game rather than inside it, and the
next request is a file.

**Cost.** Requests are only given in town (the town is where the CharacterDefs stand).
The listener list in `quests.gd` must grow when a new kind of goal needs a signal nobody
listens to yet (one line). A delivery counts what's in the bag, so selling the parsnips
before handing them in undoes it. Rewards are gold and items; cosmetics come next session.
Art for Mabel and Pip is placeholder (recoloured from Marlow and Wren; Pip squashed
shorter).

## 039 — Decorations are placeable items that do nothing; a shop switch decides who sells them

**Decision.** Stage 8 session 3 adds cosmetic purchases: decorations for the farm.

- *A decoration is placed exactly like a sprinkler.* It's a `ToolDef` whose action puts an
  object on the tile in front of you (Space, open grass only, never the path, a crop or
  another object), and its `ObjectDef` names the item back, so E picks it up again. The
  object's scene uses `placed_object.gd` like the sprinklers. Nothing new on the farm: it
  already knew how to hold, draw, save and pick up objects by id. Placing costs no energy
  (`energy_cost` 0): it isn't work.
- *`PlaceDecorationAction` is how a decoration is recognised.* It extends
  `PlaceObjectAction` and changes nothing about placing; it exists so that
  `Economy.is_decoration()` can tell a scarecrow from a sprinkler the way
  `Economy.is_seed()` tells seeds by `PlantAction`. A decoration's `ObjectDef` has no
  `water_offsets`, so it does nothing overnight.
- *Who sells them is a shop switch*, `ShopDef.sells_decorations`, beside `sells_seeds` and
  `sells_supplies`. Marlow's general store has it on. Decorations no longer count as
  "supplies", so the blacksmith keeps selling only sprinklers. ContentDB warns if a
  decoration has a price but no shop sells decorations, or if its object doesn't give it
  back when picked up.
- *Their own folder:* `data/decorations/` (the items; ContentDB reads it with tools and
  produce), `data/objects/` (what stands on the tile), `scenes/decorations/` and
  `assets/sprites/decorations/`. A new decoration is those three files and a picture.
- *The first six* (first guesses at prices): fence 15g, hay bale 40g, flower bed 60g,
  scarecrow 150g, lamp post 250g, and a sundial that isn't sold anywhere. The fence, flower
  bed and lamp post reuse the town's art under their own ids (`garden_fence` and so on),
  because the town's pieces must not be pick-up-able. The farm's flower bed snows over in
  winter by one line in `winter.tres`; the farm's lamp post has the town lamp's glow in the
  `night_lights` group, so the farm's Daylight lights it at dusk with no code.
- *A cosmetic as a reward.* The mayor's second request (`mayor_town_pride`: sell 1000g of
  produce, after his first) pays 100g and the sundial. Request rewards were already items,
  so this is one `.tres`, which is what DESIGN.md meant by quests giving "cosmetics".
- *No save change* (still version 8): a placed decoration is a farm object id, and one in
  the bag is an item id, both of which the save already held.

Options considered: decorations as a separate system (a "decor" layer on the farm with its
own save list): more freedom later, such as things you can walk over, but a second way of
standing on a tile beside objects, for no gain today. Or a "decoration" flag on `ItemDef`:
simpler, but a flag can be set on something that isn't placeable at all, while the action
class can't. Or reusing `sold_only_by` to send them to Marlow: no code, but it means "rare"
and every new decoration would have to name the shop.

**Why.** Rule 3: a decoration, its price, its winter look or a decoration as a reward is
data. The endgame (DESIGN.md) is playing for the look of the farm, and this gives gold
somewhere to go once the upgrades are bought.

**Cost.** Every decoration is one tile. The town's bench (two tiles wide) isn't offered,
because a one-tile object with a two-tile picture would let another object sit on its
other half. Everything is solid, so a ring of fences can shut a field (E still picks them
up again). The hotbar grows with
each kind carried. Marlow's list is now seven rows; much more stock would need the shop
menu to scroll. A lamp put down after dark lights at the next tick of the clock (a few
seconds), not at once. New art is placeholder: scarecrow, hay bale, sundial, and icons for
the two tall ones.

## 040 — Difficulty is a set of multipliers chosen once, at new game, and saved by id

**Decision.** Stage 8 session 4 adds the difficulty choice DESIGN.md asked for.

- *A difficulty is a `DifficultyDef`* (`data/difficulties/`): an id, a name, a sentence for
  the menu, and five multipliers: starting gold, sell prices, shop prices, energy per
  swing and grow times. 1.0 changes nothing. `game_rules.tres` lists them in menu order
  (`difficulties`, like `seasons`) and names the default (`default_difficulty`).
- *Three to start* (first guesses, to be tuned in Stage 9's balance pass):
  Relaxed (200g, sells at 125%, shops at 80%, 75% energy, 75% grow time), Standard
  (all 1.0: exactly the game as it was) and Hard (50g, 80%, 125%, 125%, 125%).
- *Each multiplier is applied in one place,* the place that already owned that number:
  `Economy.buy_price()`, `sell_price()` and `upgrade_price()` (so the bin, the counters,
  the market stall and the shop menu all follow; the stall's 125% goes on top),
  `GameState.new_game()` for the gold, the player's tool swing for energy, and
  `CropDef.days_to_grow_from()` for growing (`FarmData.advance_day()` is passed the
  multiplier by TimeSystem, so the farm's data doesn't look up the game's settings).
  Nothing anywhere asks "is this Hard?". Shop prices cover everything bought (seeds,
  supplies, decorations and upgrades); request rewards are left as written.
- *Prices round to whole gold and never become free:* anything with a price costs at least
  1g; 0 still means "not for sale".
- *Grow times are rounded along the way, not stage by stage.* Days are whole, so at 1.25 a
  4-day parsnip takes 5 days (stages of 1, 2, 1, 1). Rounding each stage would have made
  it 8 (or left it at 4), because 1.25 days rounds the same way every time. No stage is
  ever shorter than a day, which is why Relaxed doesn't speed up parsnips or radishes.
  The shop's "Ready in N watered days" shows the scaled number.
- *The choice:* a small menu (`DifficultyMenu`, made in code) asks "how would you like to
  play?" at first launch with no save, and on Ctrl+N. It starts on Standard and says in
  words what each one changes. At first launch there's no way out of it; from Ctrl+N, Esc
  goes back to the game in hand untouched, which is safer than Ctrl+N's old instant
  restart. `SaveSystem.load_or_new_game()` now says whether it loaded, so the boot scene
  knows when to ask.
- *Saved by id* (save version 9: `"difficulty": "hard"`), and its numbers read from the
  `.tres` on load, so retuning Hard reaches games already being played. Saves from
  before (v1–v8) were all played at what is now Standard, so the 8 → 9 step writes
  `"standard"` (frozen in the step). An id the game doesn't know loads as the default,
  with a warning. `tests/saves/v8_example.json` is a real v8 save, with requests in it.
- *Chosen once.* There's no changing difficulty mid-game: the starting gold has already
  been given, and a switch would be a way round it. It can be added later as one setter.

Options considered: separate code paths per difficulty (what DESIGN.md rules out), or
difficulty fields on every item and crop (`hard_price`...), which multiplies the data by
three. Or applying the multipliers once, at new game, by copying altered resources: then
the save would have to hold every price, and retuning wouldn't reach existing games. Or a
single "difficulty level" number with the scaling worked out in code: fewer fields, but
then the balance lives in a script (rule 6).

**Why.** DESIGN.md: "Not separate code paths — difficulty is data." Rule 3 and rule 6: a
fourth difficulty, or a gentler Hard, is a `.tres` edit. And it's the architecture's exam
the stage plan set: prices already went through Economy and growing through one CropDef
function, so the farming code took one extra argument and nothing else.

**Cost.** Energy costs are fractions now (a Hard hoe swing is 2.5), which the HUD rounds
for display. The game doesn't show which difficulty you're playing, except in the console
on load; Stage 9's title screen and settings are the place for that. Ctrl+N still has no
"are you sure?", but the menu is a chance to change your mind. Grow-time rounding means
the shortest crops (radish, parsnip) can't get faster than a day a stage.

## 041 — Stage 8's placeholders replaced with Pixellab art, drop-in at the same paths

**Decision.** Every Stage 8 placeholder picture is now real Pixellab art saved over the
same file, so no data, scene or script changed: the produce stall and seed cart, Rosa,
Fennel, Mabel and Pip, the strawberry, melon and pumpkin growth strips, their three
produce icons and three seed packets, and the scarecrow, hay bale, sundial, scarecrow
icon and lamp post icon. Dave chose the look from a test of the produce stall and Rosa
(2026-11-15). The fence, flower bed and lamp post already used the real town art.

**How.** pixflux, palette-forced (`color_image` = `art/palette.png`), `init_image` = the
placeholder, as for the town (DECISIONS 028, 030). Every picture lands on the 41
colours; the palette did not grow. People were moved down a few pixels so their feet sit
on the same row as the placeholder's. Prompts and strengths are in `art/STYLE.md`.

**One size change.** The scarecrow is 32×32 instead of 16×32 so its arms can reach out
past its cell. Its scene centres the sprite with `offset = (0, -16)`, which still puts
its foot on the cell's bottom edge, and its collision is unchanged, so nothing else
needed to change.

**Cost.** About 45 generations including look tests and retakes, under 40 cents of
credit. The hay bale is the weakest piece: the palette has no bright straw yellow, so it
comes out a pale tan block; three retakes didn't do better.

## 042 — Sound, music, juice and the day's summary all listen on EventBus; sounds are made by a script

**Decision.** Stage 9 session 1 adds the game's feel: sound effects and music, small
visual effects, and a summary screen at the end of each day. None of it is called by the
game's systems. Each piece subscribes to signals EventBus already had, so the farming,
shop and quest code didn't change (`GameState.new_game()` gained one announcement).

- *Sound is an `Audio` autoload* that listens on EventBus and plays a named sound for each
  event (`till`, `water`, `plant`, `harvest`, `coins`, `ship`, `door`, `talk`,
  `quest_done`, `sleep`, `morning`…; the whole list is in `_listen()`). What each name
  sounds like is data: `data/audio/sound_bank.tres` (`SoundBank`), so a better sound is a
  file swap. Each play varies the pitch by ±5% so repeated sounds don't sound mechanical,
  and one sound asked for twice in one frame plays once (a 3×3 watering can is one
  splash). Farm sounds are skipped overnight (sprinklers). It keeps running while paused,
  so the shop menu and the summary still make sounds.
- *Music is a field on `LocationDef`* (`music`). A building without one plays its
  outside's tune, so the shops play the town's and the farmhouse the farm's, and walking
  indoors carries the tune on instead of restarting it. Changing tune crossfades over
  0.8 s with two players.
- *Two buses,* `Music` (-4 dB) and `SFX`, in `default_bus_layout.tres`, ready for session
  2's volume sliders. Until then **M** mutes and unmutes everything (not saved).
- *The sounds and both tunes are made by `art/build_sounds.py`*: synthesised from sine,
  triangle and soft square waves and filtered noise, no samples. The tunes are written
  out note by note (farm: F major, 84 bpm, about 90 s; town: G major, 108 bpm with a
  little swing, about 70 s) and rendered "round the loop" so they repeat without a gap.
  Effects are 16-bit `.wav`; music is `.ogg` with `loop=true` in its `.import` file.
- *Juice on the farm is `FarmEffects`* (the `Effects` node in `main.tscn`, above the
  y-sorted entities): one-shot pixel particles in palette colours for tilling, watering,
  planting, harvesting and putting things down or picking them up; the produce pops up
  out of the ground on harvest ("+2" if more than one); and a small camera jolt
  (`ScreenShake`, on the camera's offset in whole pixels) on harvest and a bigger one
  when energy runs out. Crops squash and stretch when planted or picked, and the bin
  when something goes in: the picture only, never the collision.
- *Gold going in or out* shows as "+40g" / "-15g" under the purse in the HUD for a second.
- *The day's summary:* a `DayReport` autoload keeps a tally of the day from EventBus
  (harvested by crop, planted, watered by hand, sold in town, the bin overnight,
  rewards, spent, requests done). At night the tally closes; the next morning the HUD
  shows `DaySummary` on black (game paused), then fades the morning in when Space, E or
  Enter is pressed. Empty rows are left out; a day with nothing is "A quiet day." Keys
  in the first 0.4 s are ignored, so the E that put you to bed doesn't skip it. Loading a
  save or starting a new game (the new `EventBus.new_game_started`) clears the tally,
  so a summary only ever follows a night actually played. Nothing is saved: the game
  saves at the start of a day, when the tally is empty.
- *Closing the window* stops all sound and waits 0.15 s before quitting (Audio turns
  off `auto_accept_quit`). Quitting with a sound still playing makes Godot print
  "leaked instance" warnings, which look like a bug but aren't.

Options considered: calling `Audio.play()` from each system (hoe, shop, bin…), which
spreads sound through code that should only know about farming. Sounds as fields on each
content resource (`ToolDef.use_sound`): more flexible, but most events aren't content
(a door, a sale, the night), so it would still need the event list, in two places.
Downloading a free sound pack: better-sounding, but licences to track, and the style
wouldn't match without editing. A summary drawn by the HUD itself: but the HUD is
rebuilt with every scene, and the tally has to survive the walk home.

**Why.** Rule 2: this is what EventBus was for. Sound, effects and the summary are three
new features and none of them needed a farming file opened. Rule 3: what things sound
like and which tune plays where are data.

**Cost.** Synthesised sound is simple-sounding (chiptune-ish); any file can be replaced by
a better one at the same name later. The `Audio` autoload is an exception to "systems
don't call each other" in one direction: UI that isn't a game event (closing the
summary) calls `Audio.play()` directly. `build_sounds.py` needs numpy and ffmpeg to run
again; the game itself needs neither.

## 043 — Unlocks are named files that content points at; requests and the calendar open them

**Decision.** Stage 10 session 1 adds the one system the roadmap's pacing hangs on
(ROADMAP section 4): things open up over time instead of all being there on day 1.

- *An unlock is an `UnlockDef`* in `data/unlocks/`: an id, a short name for request
  rewards and the notice board ("Hollis's full spring stock"), an `announcement` for the
  morning summary, and an optional `on_day` (a `day_number`, like `QuestDef.first_day`)
  on which the calendar opens it by itself. 0 means only a request can give it.
- *The game remembers only the names* earned, in `GameState.unlocks` (saved, version 10).
  `GameState.has_unlock()` answers yes for null, so content that waits for nothing passes
  its empty field straight in.
- *Content points at the unlock it waits for* with one field, `requires_unlock`, on
  `ItemDef` (kept off every shop's shelves), `UpgradeDef` (not offered), `QuestDef` (not
  asked) and `LocationDef` (the door is shut, with the location's own `locked_message`;
  the building still stands on the map). Characters and calendar events get the same
  field in session 2, when something first needs it.
- *Requests give unlocks* with `QuestDef.reward_unlocks`; the reward text names them
  ("Reward: 50g and Hollis's full spring stock"), so a request always says what it opens.
- *The calendar's unlocks open overnight* (TimeSystem step 4b, after the date moves on and
  before `day_started`), and at new game for anything due on day 1. Loading a save also
  catches up quietly on any whose date has passed, so a new unlock added later with a past
  date reaches existing games.
- *Never silently* (the roadmap's rule): EventBus gains `unlocked`. `DayReport` records it,
  and the morning summary lists each one's announcement, then who has something new to ask
  today ("Mabel has something to ask you."), worked out from the requests' dates by
  `Quests.givers_new_today()`. The notice board pins up calendar unlocks due within a week
  ("Coming soon: Brann's forge reopens, in 5 days (spring day 8)"), and no longer lists a
  crop as in season while its seeds aren't in any shop yet.
- *The first week, rewritten:* the mayor opens with "The first pull" (bring five parsnips;
  50g and Hollis's full spring stock), and his welcome request (sell 200g) now follows it.
  Hollis sells only parsnip and radish seeds until then. Potato seeds wait for the mayor,
  green beans for summer day 1, cabbage for autumn day 1. Brann's forge is shut until
  spring day 8 ("Gone to the city for steel"). Mabel's first request waits until day 5;
  Pip still asks on market days (the first is day 3).
- *Old saves* (version 9 and before) had everything open, so the upgrade step gives them
  every unlock that existed in this version, frozen as a list in the step, and ticks off the
  mayor's new opener if they've already started his welcome request, so he doesn't go back
  a step. `tests/saves/v9_example.json` was made by the version 9 game.
- *ContentDB checks* that every `requires_unlock` and `reward_unlocks` names a file in
  `data/unlocks/`, and warns about an unlock nothing can open (no date, no request gives it)
  or one with no announcement.

Options considered: unlocks as plain names typed into each field (`&"forge_open"`), as
the roadmap first sketched: simpler, but a typo would silently hide something for ever,
and the reward text couldn't name what opens without asking ContentDB from inside a data
file. Resource references are checked by the editor and give the name for free; the save
still keeps only the id. A separate "stock list per shop per week" table: one place to
read the pacing, but it would undo rule 3 (shops are filters, so a new crop needs no shop
edit). Gating whole shops by hours of the clock alone: can't express "after the mayor's
request".

**Why.** Rule 3: what opens when is data. A new thing to drip-feed is an UnlockDef and one
field set on whatever it opens; no code. Every later stage (the woods, Ivy, fishing, the
greenhouse) plugs into it.

**Cost.** `on_day` counts days from the start of the game, so it assumes 28-day seasons
like `first_day` does; changing `days_per_season` means revisiting those numbers. A player
who never does the mayor's first request never sees Hollis's potatoes; that's intended
(it's the tutorial), and the mayor's "!" and the notice board keep pointing at it.

## 044 — People arrive by unlock, shopkeepers can ask, and Brann's test opens the big upgrades

**Decision.** Stage 10 session 2 finishes ROADMAP section 4's "anything can require one"
and adds the first shopkeeper request.

- *Characters and calendar events get `requires_unlock`*, the field DECISIONS 043 left
  for "when something first needs it". A townsperson waiting for one isn't built in town
  and has nothing to ask (`Quests.is_about()`). An event waiting for one doesn't happen:
  `GameState.events_on(day)` is the dates (ContentDB, unchanged) filtered by unlocks, and
  `events_today()`, `days_until()` and requests' `on_event` all go through it, so the
  notice board, the town's stalls and Pip's market-day request agree. For a day ahead or
  behind, today's unlocks are used, since nobody knows what will be earned by then.
  `CalendarEvent.happens_on()` stays plain data (the date only), as before.
- *Mabel arrives on spring day 5* (`mabel_arrives`, a calendar unlock), so the roadmap's
  "[new] Mabel" is true on screen, not just in her request's date: the board pins her up
  as coming soon, the morning summary announces her, and she's in the square from then.
  Nothing yet uses an event's unlock (the festivals in Stage 18 will); it's covered by a
  test that adds a made-up event.
- *A request's `giver` can be a shopkeeper*, named by their shop's id (`&"blacksmith"` is
  Brann). `Quests.giver_name()` gives "Brann" or "Mabel" wherever a name is shown (the
  request log, the summary, the board, "Go and see …"). ShopCounter asks Quests first: a
  keeper with a request to make, remind or take in says that instead of their greeting,
  then the menu opens as usual. The same "!" or "?" floats over keepers indoors and at
  stalls; it moved into `Npc.add_quest_marker()` so the town and the shop share one. A
  keeper only asks once their shop's door is open to you (the location's
  `requires_unlock`), so Brann's request waits for the forge with no date of its own to
  keep in step (it has `first_day = 8` only so the summary says "Brann has something to
  ask you" that morning).
- *Brann's test* (`blacksmith_prove_it`): sell 300g of produce from day 8 →
  `great_tools` (the great hoe and great can wait for it, as well as for the wide ones)
  and `north_field_deed` (Marlow's north field; the pond and east fields follow it
  through `requires`, so all the extra land waits for Brann). No gold: the reward is what
  it opens.
- *Season-end warning in the morning summary* too, the board's own words
  (`Notices.season_end_warning()`), so the warning reaches the player even if they never
  read the board. Hollis's spring line and the mayor's bridge request need Stage 13's goal
  kinds (ship variety, donate gold), so they moved there; the mayor mentions the bridge in
  his daily lines meanwhile.
- *No new save version.* Nothing saved changed shape. The version 9 → 10 step's frozen
  list gains the three new unlocks, because a version 9 game had Mabel, the great tools
  and every field from day 1, and that step also ticks Brann's test off as done for those
  games (as it does the mayor's opener). A version 10 game made before today earns them in
  the usual way: Mabel on load (her date has passed), the rest from Brann.

Options considered: shopkeepers as CharacterDefs too (one kind of giver, but two files
for one person, and the keeper's name, picture and words would live in two places);
a separate `giver_shop` field on QuestDef (clearer to read, but every place that shows or
matches a giver would ask two fields). One id that's either kind, resolved by
`giver_name()` and `is_about()`, keeps the rest unchanged. For events, filtering inside
`ContentDB.events_on()` would have been one line, but ContentDB is an index of files and
shouldn't ask the game's state.

**Why.** Rule 3 again: who arrives when, and what a shopkeeper asks, is data. Ivy (Stage
13), Wren's and Brann's later lines, and the festivals plug into these fields with no code.

**Cost.** Editing a released save step is normally wrong; here no version 9 game exists
outside Dave's machine and the step's meaning ("version 9 had everything open") is kept,
not changed. After the game is shared, a new unlock that old games should have needs a
new save version instead.

## 045 — Hazards are small overnight rules in one data file, started by calendar unlocks

**Decision.** Stage 11 session 1 adds the first three hazards from ROADMAP section 7:
thirst, weeds and crows, with the scarecrow made to work.

- *Thirst lives with growing.* `FarmTile.dry_nights` counts nights in a row a crop went
  unwatered; `FarmData.advance_day()` either grows a watered crop or makes an unwatered
  one a night thirstier. Two dry nights and it looks wilted (a tint on the crop's sprite,
  `FarmTile.is_wilted()`), three and it dies, and the tile is left as tilled soil.
  Watering a wilted crop perks it up at once and it grows that night as usual. A ripe crop
  never goes thirsty: it has finished growing and only waits to be picked. On difficulties
  where thirst doesn't kill (Relaxed), crops wilt and wait however long it takes.
- *Weeds and crows are `FarmHazards`*, plain functions on a FarmData that TimeSystem runs
  in the night, after the growing and before the sprinklers (so the morning still has wet
  soil round each sprinkler). They're passed everything (the rules, the difficulty's
  multiplier, which hazards have started, the dice) and look nothing up in GameState, so
  a test sets the dice and gets the same night every time.
- *Weeds* (`FarmTile.weeds`): each night a few come up on tilled soil and on grass beside
  crops, never more than 8 in a night, in spring, summer and autumn. A weedy crop doesn't
  grow (watering still counts against thirst); weedy ground can't be tilled, planted or
  built on. E pulls a patch for 1 energy, or the hoe digs it out (one swing, one job:
  hoeing weedy grass takes a second swing to till it). Each patch gives one **fibre**
  (`data/produce/fibre.tres`, 1g; Brann will want it in Stage 13). Bare tilled soil also
  goes back to grass now and then (5% a night).
- *Crows*: if more than 16 crops are out of every scarecrow's reach, crows may come (75%
  a night) and take one or two. The scarecrow's `ObjectDef.protects_radius` is 8: a circle
  of 8 tiles round it. In the morning a crow stands on each emptied tile
  (`FarmData.crows_landed`, not saved) until the player walks up and it flies off.
- *Both start by calendar unlocks*, `weeds_arrive` (spring day 6) and `crows_arrive`
  (day 15), named in the rules' `weeds_start` and `crows_start`. That reuses everything
  unlocks already do: the notice board pins them up a week ahead ("Coming soon"), the
  morning summary announces them, and the first weeds or crows come *that night*. So every
  hazard is announced before it bites, as the roadmap asks.
- *All the numbers are in `data/hazard_rules.tres`* (`HazardRules`), pointed at by
  `game_rules.tres`. Session 2's weather adds its odds there too.
- *Difficulty*: `DifficultyDef.hazard_multiplier` (Relaxed 0.5, Standard 1, Hard 1.5)
  multiplies the weeds' chance and nightly cap, divides the crows' safe number (Hard: 11)
  and multiplies their chance; 0 switches weeds and crows off. `thirst_kills` (false on
  Relaxed) is separate, because "never dies of thirst on Relaxed" isn't a matter of how
  often. The new-game menu lists both.
- *The morning says what happened.* `crop_died` gained a `cause` (&"season", &"thirst",
  &"crows"). The summary shows "Weeded" and "Crops lost: 1 to thirst, 2 to crows", names
  what the crows took, and warns "3 crops will die of thirst tonight unless watered" when
  any are wilting.
- *Save version 11*: tiles may carry `weeds` and `dry_nights`, written only when they're
  something, so an older farm needs no change. An older game already past day 6 or 15
  gets the weeds and crows on load, quietly, like any date it has passed.

Options considered: weeds as an ObjectDef standing on the tile (no new tile field, but an
object can't share a tile with a crop, and a weed on a crop is the point); a separate
hazard autoload listening for day_ended (but the night's order matters: growing, then
hazards, then sprinklers, and that order belongs in TimeSystem's one list); a chance
per crop for crows (Stardew-like, but the roadmap's "more than ~16 unprotected" rule
leaves a small garden alone, which suits the first weeks).

**Why.** ROADMAP section 2: introduce, then pressure, then relieve. Weeds are a chore from
day 6, crows a threat from day 15, and the scarecrow (sold since Stage 8 with nothing to
do) is the relief. Each rule is a few lines over existing data, tuned in one file.

**Cost.** Thirst makes a forgotten day cost a crop, not just a day: that's the intent, but
Stage 20's balance pass should check it against the clock's pace. Crows only take crops
out of reach, so a scarecrow placed well makes them disappear entirely; if that turns out
too easy, the safe number is the knob. Weeds, the crow and fibre are placeholder art
until the Pixellab pass (weeds can take a seasonal look by `object_sprites[&"weeds"]` on
a SeasonTheme, with no code).

## 046 — Weather is a WeatherDef per kind, chosen a night ahead from each season's odds

**Decision.** Stage 11 session 2 adds the weather from ROADMAP section 7, and autumn's
frost.

- *Each kind is a file*, `data/weather/*.tres` (`WeatherDef`): sunny, rain, storm,
  heatwave, snow, frost. What it does is a few switches and numbers on the file —
  `waters_farm` (rain, storm), `thirst_per_dry_night` (heatwave 2), `keeps_crows_away`
  (storm), `kills_tender_crops` (frost) — and how it looks and sounds is there too: an
  `overlay` scene, a `light_tint`, an `ambience` loop. A new kind (fog) is a new file.
- *Each season has odds*, `SeasonTheme.weather_odds` (weights by WeatherDef), and can fix
  the weather on a date, `fixed_weather` (spring day 1 is always sunny, so a new game never
  opens wet; autumn day 28 is always frost). `SeasonTheme.weather_on(day, dice)` picks.
- *Chosen a day ahead, never wrong.* `GameState.weather` is today's and
  `GameState.forecast` tomorrow's; each night the forecast becomes today's and a new one
  is drawn. The forecast is in the morning summary and on the notice board ("Rain all
  day: … Tomorrow: sunny."), today's weather on the HUD's top line. A forecast that could
  be wrong was considered (more like real weather) and left out: the player plans with it,
  and a wrong one only feels unfair.
- *Where it acts in the night* (TimeSystem): the day that's ending has its say during the
  growing and the hazards (after a heatwave, unwatered crops gain two nights' thirst, so
  they wilt by morning; after a storm, the crows stay away); the new day's weather arrives
  last, as step 4c, after the calendar and unlocks. Rain then waters every tilled tile
  (`FarmData.rain()`, as if by the can), so the morning is wet and those crops grow
  tonight; frost kills every crop that can't grow next season (`FarmData.frost()`, cause
  `&"frost"`). So a rainy day is a free day, as the roadmap asks, and it shows in the soil.
- *Frost is weather fixed by date*, not a separate rule: `warn_days_ahead` 3 puts "Frost in
  3 days (autumn day 28)" in the summary and on the board from day 25. It kills a night
  before the season's turn would. "Tender" means "can't grow next season" for now, so
  parsnips and cabbages (which list winter) survive it; Stage 12's hardy crops will too.
- *Look and sound.* The farm and the town's `Weather` node holds the season's overlay and
  now today's weather's too (`SeasonLook.apply_overlay`, redone on `weather_changed`): rain
  and storm are falling drops (`scenes/weather/`), the storm with lightning flashes and
  thunder (`scripts/weather_flash.gd`). Daylight multiplies in the weather's tint (grey for
  rain, darker for a storm, warm for a heatwave). Audio plays the weather's loop
  (`assets/audio/ambience/rain.ogg`) all day, 14 dB quieter indoors. Both are made by
  `art/build_sounds.py`, with their own dice so the older sounds didn't change.
- *Winter's snowfall moved* from the winter SeasonTheme's overlay to the snow weather, so
  snow falls on snowy days (about half of winter) and the rest are clear. The snowy ground,
  trees and roof stay all winter.
- *The thunder goes through EventBus* (`thunder_rolled`, Audio plays it). The storm scene is
  loaded along with game_rules.tres (seasons → weather → overlay), before any autoload
  exists, so it mustn't name one: calling `Audio` from it stopped the game starting.
- *Save version 12*: "weather" and "forecast" by id. An older save's today is "sunny"
  (written into the upgrade step) and its forecast blank, so it's drawn on load. An unknown
  id (a kind since removed) is drawn afresh too.

Options considered: weather as a separate autoload (but its state belongs in the save,
which is GameState, and its effects belong in TimeSystem's one ordered night); rain as a
"sprinkler everywhere" at step 2 (but then the morning after a rainy *night* is wet, and
the rainy day itself isn't); a per-crop frost flag now (but Stage 12's hardy rule is the
place for it, and "grows next season" already says the same for today's crops).

Left for Stage 12: pests (their counter, flowers nearby, is a Stage 12 crop rule) and the
storm flattening tall unfenced crops (no tall crops exist yet; it'll be one more switch on
WeatherDef).

**Why.** Rain is relief (a day off watering), heatwave and frost are pressure announced
ahead, the storm is both: ROADMAP section 2's introduce, pressure, relieve, in data that
tunes without code.

**Cost.** Rain makes watering less of a chore a third of spring, which Stage 20's balance
pass may want to weigh against thirst. The forecast only looks one day ahead (plus the
frost warning); a week's forecast would need nothing new but a wider draw ahead, if wanted.
Placeholder look: the drops are plain lines and there's no wet-ground tint beyond the
watered soil; a Pixellab pass could add puddles.

## 047 — Crop rules are switches on CropDef; storms flatten tall crops nobody fenced

**Decision.** Stage 12 session 1 adds ROADMAP section 6's crop rules, the storm's other
half from Stage 11, and the first wave of eight crops that use them.

- *Each rule is a field on `CropDef`, off by default*, so the eight crops that existed
  didn't change: `harvest_max` (bunches: 1 to 3 spring onions a time), `solid` (a trellis:
  peas and corn block the player once they've come up, with a body on the crop's sprite),
  `perennial` (rhubarb sleeps out of season and comes back next spring), `plant_seasons`
  and `rests_in` (garlic is planted in autumn only, sleeps through winter and finishes in
  spring), `needs_water` off (hardy: the sunflower grows unwatered and never thirsts),
  `near_water` (watercress only goes in on one of the eight tiles round the pond),
  `loves_weather` (corn grows twice on a heatwave day), `seed_chance` (a sunflower gives
  its seeds back about a third of the time), `tall` (what a storm can flatten).
- *Flowers are a tag on the produce*, `ItemDef.tags` (`&"flower"` on the sunflower), not a
  crop rule: bees (Stage 17), the flower show (Stage 18) and the pests (session 2: they
  spread slower near flowers) care about the flower, and a tag is the general shape for
  "a kind of item" that later stages will want again.
- *Asleep is worked out, not saved.* `CropDef.rests_during(season)` is true when the crop
  doesn't grow in the season but is perennial or lists it in `rests_in`; `survives()` is
  "grows or rests". The season's turn and frost now kill what can't *survive* the next
  season (so garlic lives through autumn's frost), and `advance_day` (which now gets the
  day's season and weather) neither grows nor dries a resting crop. A regrowing perennial
  that goes to sleep ripe loses that crop and wakes waiting to regrow. Nothing new is
  saved, so **the save version stays 12**.
- *Seeds ask the crop's rules.* `PlantAction` asks `FarmData.can_plant_crop()` (the spot)
  and `CropDef.can_plant_in()` (the season, `plant_seasons` first). The shop's detail line
  adds `CropDef.rules_text()` ("Grows on a trellis: you can't walk through it…"), and the
  notice board's "in season" lists what can be *planted* now (garlic in autumn, not spring).
- *Storms* (from Stage 11, DECISIONS 046): `WeatherDef.flattens_tall_crops` (storm 0.25) is
  the chance each tall crop past the seed is flattened in the night after a stormy day,
  scaled by the difficulty's `hazard_multiplier`, unless something with
  `ObjectDef.shelters_radius` stands within reach (the garden fence, 1: the eight tiles
  round it). `FarmHazards.flatten_tall_crops`, run first in the night's hazards; the crop
  dies with cause `&"storm"`, which the morning line and summary report.
- *The catalogue*: spring onion (Hollis, from the start), pea (Hollis, with potatoes once the
  mayor's first request is done), rhubarb (Fennel's cart for now; ROADMAP has it as Hollis's
  questline reward, Stage 13), garlic (Hollis's autumn seeds), sunflower, watercress and corn
  (Hollis's summer seeds), kale (Hollis's winter seeds: a new calendar unlock,
  `hollis_winter`, winter day 1). Numbers are ROADMAP 6.2's first guesses, rounded to fit
  whole stages (pea 8 days not 7, rhubarb 12 not 14, garlic 20); Stage 20 balances.
- Placeholder art for all eight (growth strips, icons, seed packets) is drawn by a script
  in the Harvest palette; Pixellab replaces it at the same paths. The palette has no
  yellow, so sunflower and corn are orange for now.

Options considered: one `rule` enum per crop (but sunflower has three rules and corn three;
fields combine freely); a saved "dormant" flag on FarmTile (but it would only ever repeat
what the season and the crop already say); the storm flattening in FarmData like frost
(but it needs dice and the objects' shelter, which is FarmHazards' shape, like crows).

Left for session 2: pests (aphids from autumn day 1, slowed by flowers, Marlow's spray),
giant crops (melon, pumpkin), the apple tree (a 2 × 2 perennial), the remaining crops of
ROADMAP 6.2 (data now the rules exist), and a way to dig up a crop on purpose (pests'
"pull the plant", and clearing a perennial).

**Why.** ROADMAP section 6: crops that ask for planning (trellis paths, autumn garlic,
the pond), weather that is sometimes good news (corn in a heatwave), and fences that
finally do something.

**Cost.** A trellis can wall the player in if planted carelessly; the night (energy or
2 AM) still carries them home, so it costs a day, not the game. Hardy crops and seed-return
make sunflowers very cheap to keep going; the balance pass should watch them.

## 048 — Aphids, the trowel, giants and trees: crops that stand on more than one tile

**Decision.** Stage 12 session 2 finishes ROADMAP section 6 and the last hazard of section 7:
aphids and Marlow's pest spray, a trowel to dig up a crop on purpose, giant melons and
pumpkins, the apple tree, and the nine crops still to come.

- *Aphids are a hazard like the others* (`FarmHazards.spread_pests`, run in the night after
  the crows). They start with a calendar unlock, `pests_arrive` (autumn day 1, day 57), so
  the notice board pins them up a week ahead and the morning announces them. Each night
  there's a 30% chance aphids land on one growing crop somewhere, and each crop that has
  them passes them to one growing neighbour (the four tiles round it) with a 50% chance.
  A crop with aphids (`FarmTile.pests`) doesn't grow, but they don't kill it: it's stuck
  until it's sprayed, dug up, or the season turns. They only go for crops still growing
  (not ripe ones, giants or sleeping perennials), live only in autumn
  (`HazardRules.pest_seasons`), and the cold clears them overnight. All the numbers are in
  `hazard_rules.tres`, scaled by the difficulty's `hazard_multiplier` like weeds and crows.
- *Flowers slow them.* A flower that has come up (a crop whose produce has the `&"flower"`
  tag: sunflower, tulip, snowdrop) within 2 tiles of a crop cuts the aphids' chance of
  reaching it to a quarter (`flower_radius`, `flower_slows_pests`). That's the first job for
  DECISIONS 047's flower tag; bees and the flower show come later.
- *Pest spray* is an item sold by the dose at Marlow's (`sold_only_by`, waiting for
  `pests_arrive`), 20g, used with Space on the crop (`SprayAction`).
- *The trowel* (`DigAction`) digs up the crop in front of you, ripe or not, and leaves
  empty soil. A seed dug up before it came up goes back in the bag (`crop_dug_up` says so;
  GameState gives the seed back), so a misplanted seed costs nothing. It's a tool of its
  own rather than the hoe on a crop, because the hoe's upgrades swing at three or nine
  tiles: hoeing beside a row must never dig the row up. It's in the starting kit, and
  save version 13 gives older games one (after the watering can on the hotbar).
- *Big crops hold their state on one corner tile.* A giant or a tree stands on several
  tiles; the front-left one (the one planted, or a giant block's bottom-left) holds the
  crop, and the others are `FarmTile.covered` by it: no crop of their own, and nothing can
  be tilled, planted, built or weeded on them. Harvesting or digging a covered tile acts on
  its corner (`FarmData.crop_cell`). Every way a crop leaves the farm (picked, dug, crows,
  storm, thirst, frost, the season) goes through one `FarmData._remove_crop`, which frees
  the covered tiles, so none can be left behind. *Covered isn't saved*: it follows from the
  corners, so loading works it out again (FarmData.from_save).
- *Giants*: `CropDef.giant_sprite`, `giant_chance` and `giant_harvest`. Each night a 3 × 3
  block of one giant-capable crop, all ripe and clear of weeds and aphids, merges into a
  giant with a 15% chance (`FarmData.form_giants`, after the hazards). Picking it gives 15
  (nine ordinary ones give 9), it blocks the way, and crows can't carry it off. The
  morning summary announces it. Melon and pumpkin have it. The cost is the waiting: ripe
  crops left in the ground can still be lost to the season's turn or the frost.
- *The apple tree* is a crop with `size = 2`: a sapling (600g at Fennel's cart) planted on a
  2 × 2 patch of tilled soil whose front-left corner is the tile in front of the player.
  It's hardy (never watered), perennial (sleeps through winter, losing any fruit on it),
  grows for 28 days, then gives 3 apples (60g each) every 3 days, in spring, summer and
  autumn. Its trunk blocks the player from the first morning on, but its leaves don't, so
  you can walk behind it. A tree is planted from a seed like any crop, so it reuses all of
  the growing, sleeping and saving there is.
- *The other nine crops* are data on the existing rules: tulip (spring flower), tomato
  (summer, regrows), chilli (heatwave-loving, regrows), blueberry (2–4 a time), beetroot,
  cranberry (beside water, 1–3 a time), leek and Brussels sprouts (autumn into winter),
  snowdrop (winter flower). Hollis sells the plain ones by season (his seasonal unlocks);
  Fennel the rare ones (chilli, blueberry, cranberry, and the sapling). Chilli is
  Hollis's questline reward in ROADMAP; that waits for Stage 13, like rhubarb. The green
  bean became a tall trellis crop at 25g, as ROADMAP 6.2 suggested.
- Placeholder art for all of it (strips, icons, seed packets, the tree, two giants, the
  aphids, the trowel and the spray) is drawn by a script in the Harvest palette; Pixellab
  replaces it at the same paths.
- *Save version 13*: tiles may carry `pests` and `giant` (only when true), and the trowel.

Options considered: digging with the hoe (no new tool, but the wide and great hoe would dig
up crops beside the ones meant); aphids that kill (but the roadmap's "stop growth" is
already a cost, and a crop stuck green is a clearer warning than one gone); a tree as an
ObjectDef (but objects don't grow, sleep or fruit, and crops already do all three); giants
and trees as nine or four crops kept in step (but weeds or aphids on one tile would put
them out of step; one corner holding the crop can't drift).

**Why.** ROADMAP sections 6 and 7: the autumn gets its pressure (aphids) and its relief
(spray, the trowel, flowers), long-term planting gets a reward (the tree, giants), and the
crop list reaches the roadmap's 26.

**Cost.** The tree pays back its 600g in under a season once grown, which is generous;
the balance pass (Stage 20) should look at it and at the giants' 15. Aphids can't be
seen until morning and spread fast in a big monoculture; that's intended (mix in
flowers), but watch it on Hard. A tree's sapling is planted by its corner, which is easy
to misjudge; the trowel gives the sapling back if it's dug up in its first week (while
it's still at the sapling stage), so moving it costs nothing then.

## 049 — Questlines: four new kinds of request, the lines as data, and Ivy

**Decision.** Stage 13 session 1 writes the townsfolk's lines from ROADMAP section 5 as
data, with the request kinds they need, and brings in Ivy.

- *Four new goal scripts* (`scripts/quests/`), each a small `QuestGoal` like the first
  three (DECISIONS 038):
  - `DonateGoal`: "give 500g towards the new bridge". Ready when the player carries the
    gold; handing in takes it. The goal says how much (`gold_to_hand_in()`) and the Quests
    service takes it, because a goal touches no autoload. Goals' `progress()` now gets the
    purse as well as the bag, and Quests, the town and the shop counters re-check on
    `gold_changed`, so the "?" appears the moment there's enough.
  - `DeliverAnyGoal`: "bring 6 strawberries or blueberries", any mix (handing in takes
    from the first listed first).
  - `DeliverEachGoal`: "bring one each of …". How many are needed is the list's length
    (new `QuestGoal.needed()`, which everything that used `goal.amount` now asks), and
    `still_needed()` names what's missing in reminders and the request log.
  - `GiantGoal`: "grow and pick a giant pumpkin", counted from a new EventBus signal,
    `giant_harvested`, which FarmData announces when a giant is picked (the only farm
    change: one line).
- *ROADMAP's "ship variety" became "bring one of each".* Counting what was shipped would
  have meant saving which items each request had seen (a new save version), and shipping
  before taking the request wouldn't count. Bringing them looks in the bag like every
  other delivery, counts what was grown before, and Hollis seeing your crops reads better
  than him counting the bin. No save change: still version 13.
- *The lines written now* (the rest wait for what they're about):
  - Mayor: **the old bridge**, from spring day 20 after his welcome: 500g → unlock
    `woods_bridge` ("ready by summer"). Stage 14 makes the bridge and the Woods wait for
    it. The pride of the valley now follows the bridge rather than the welcome.
  - Hollis (a shopkeeper giver, DECISIONS 044): **spring set** from spring day 18 (one each
    of parsnip, radish, potato, spring onion, pea, tulip) → 150g, 2 rhubarb crowns, his
    summer seeds early and rhubarb crowns on his shelves; **summer set** (tomato, green
    bean, sunflower, watercress, corn) → 250g, 3 chilli seeds, autumn seeds early, chilli
    on his shelves; **autumn set** (beetroot, cabbage, leek, Brussels sprouts) → 400g,
    5 garlic, winter seeds early. Each set is offered only in its season. Rhubarb and
    chilli left Fennel's cart for Hollis's, behind the new unlocks `rhubarb_crowns` and
    `hollis_chilli`, as ROADMAP and DECISIONS 047–048 planned. Rhubarb seeds are called
    rhubarb crowns now (same id).
  - Mabel: **summer tarts** (6 strawberries or blueberries, 450g) and **winter leek pies**
    (5 leeks, 500g), both after her pasties; her pumpkin pie stays in autumn. Her kitchen
    lessons wait for cooking (Stage 16).
  - Pip: **the giant pumpkin**, autumn from day 70 → 150g and 5 melon seeds. The mushroom
    hunt and the biggest fish wait for Stages 14 and 15, the snowman for Stage 18 or 19.
  - Ivy (new): **her autumn basket** (one each of beetroot, cabbage, pumpkin, cranberry)
    → 200g and an apple sapling; **snowdrops** in winter (5) → 300g and 10 tulip bulbs.
- *Ivy* is a CharacterDef with `requires_unlock = ivy_arrives` (a calendar unlock on
  autumn day 3, day 59), so the board pins her up as coming soon, the morning summary
  announces her and names her as having something to ask. She stands by the ruined
  glasshouse behind the general store (a new town ObjectDef, `ruined_glasshouse`). Her
  sprite is Mabel's recoloured (grey hair, green apron) until Pixellab.
- *Not in this session:* the glasshouse restoration itself (timber, 1,500g, a fish → the
  greenhouse) waits until timber (Stage 14), fish (Stage 15) and the greenhouse (Stage
  17) exist, so that every request can be done the day it's asked; Ivy's thanks already
  points at it. Brann's sprinkler and sickle lines and Wren's line wait the same way.
  Deadlines, Rosa's market orders and the notice board's daily jobs are session 2: they
  are the repeatable requests, and deadlines only matter for those.

Options considered for gold: a box in the square you could put any amount into (closer to
"into the town box", but a new kind of object and a saved running total for one request);
or a goal that counts gold the moment it's accepted (then gold earned before wouldn't
count, and nothing would stop the player spending it again). Carrying it and handing it
over is how deliveries already work, so it needs nothing new to learn.

**Why.** ROADMAP section 5 and rule 3: every line is `.tres` files on four small scripts,
and finishing things opens things (the bridge, early catalogues, Hollis's rhubarb and
chilli). The first year now has a request somewhere in every season.

**Cost.** Rhubarb and chilli are unavailable until Hollis's line gives them (in a game
already past spring, rhubarb waits for next spring's set). An unfinished set waits a
whole year for its season to come round again. The bridge's unlock does nothing visible
until Stage 14 builds the Woods. Placeholder art for Ivy and the glasshouse.

## 050 — Repeatable requests: deadlines, order patterns, Rosa's orders and the board's jobs

**Decision.** Stage 13 session 2 adds the requests that come round again: Rosa's market
orders and a small job a day on the notice board, with deadlines.

- *Deadlines* are one field, `QuestDef.deadline_days`: how many days the player has,
  counting the day it's taken (1 = by tonight). Taking it records the day it's due in the
  log (`QuestLog` entry `"due"`). At step 1 of the night (`day_ended`) anything due today
  and still in hand runs out (`EXPIRED`, EventBus `quest_expired`): no penalty, only the
  reward missed, and a written request that ran out isn't asked again. The request log,
  the giver's reminder and the "New request" line say when it's due; the morning summary
  says what ran out ("Out of time: …").
- *Order patterns* (`OrderTemplate`, `data/orders/`, indexed by ContentDB): who posts
  them (`posted_at`: a shop id, or `&"notice_board"`), the words with {count} {item}
  {gold} {client} filled in, a list of items, a count range capped by bin value
  (`max_value`, so nobody asks for six pumpkins), what they pay (`pay_rate` × the bin
  price at the game's difficulty, + `bonus_gold`), the deadline, how many to choose
  between (`choices`), a `weight`, and when (`first_day`, `on_event`, `requires_unlock`).
  Of the items, only those in season are asked for: produce of a crop growing this season
  whose seeds the player can buy (unlocked, priced), and anything nobody grows (fibre).
- *Each day each place picks one of its patterns* (by weight) and puts up `choices`
  orders for different items. The Quests service builds each as an ordinary `QuestDef`
  (a `DeliverGoal`) with an id like `rosa_orders@17#2`, so the log, the markers, handing
  in, rewards and the summary need nothing new. What's on offer is drawn with dice seeded
  by the place and the date: the same however often you ask, and loading the morning's
  save changes nothing. Taking one takes the others off the table for the day.
- *Saving an order*: there's no file to look it up by, so its log entry also keeps what
  it was made of (`"order"`: pattern, item, count, gold, day) and the Quests service
  builds it again on load (`Quests.find`). Finished and expired orders are cleared away
  each morning, so the save doesn't grow by a line a day; `orders_done` counts them.
  **Save version 14**; older saves need nothing but `orders_done = 0`.
- *Rosa*: her first crate (8 vegetables, any mix: `DeliverAnyGoal` gains `what`, a word
  for a list too long to read out), market day from spring day 10 → 60g and the unlock
  `rosa_orders`. Then each market day she offers three orders: 4–10 of something (at most
  700g at the bin), at 150% of the bin, due by the end of next market day (8 days). Her
  stall pays 125% for anything, today; an order pays more for planning a week ahead.
- *The notice board*, from spring day 8 (`board_jobs`): one job a day, due that night,
  from Marlow (vegetables), Mabel (fruit and baking vegetables), Brann (8–16 fibre, at
  3× the bin + 25g, since fibre is near worthless) or the mayor (flowers). It's taken and
  handed in at the board itself ("leave them in the crate under the board"), so the
  board wears the same "!" and "?" as a person (`Npc.quest_marker_on`).
- *Choosing* needed a question: `DialogueBox.ask(speaker, question, answers)` and its
  `chosen` signal. W/S or the arrows move, E/Space/Enter picks, Esc picks the last answer
  (always "Not this time" / "Leave it"). Turning orders down hides them for the rest of
  the day (not saved), so Rosa doesn't ask every time you want to sell her something.

Options considered: handing a board job to the person it's for (Marlow in his shop):
one giver would then have two requests open at once (his own and the job), which breaks
"one at a time" and needs a choice of which to hand in; shops also close in the evening,
and a job is due that night. The board as the giver keeps both simple. For orders:
writing every order as a `.tres` (dozens of files, and nothing in season-picking);
or saving today's offers (a bigger save, and a reload could be rerolled anyway unless
saved) instead of seeding by date. Seeding by date means every game sees the same
orders on the same day; that's acceptable for now and easy to change (add a saved seed).

**Why.** ROADMAP 5.7 and 5.9: once the story lines wait on growth, every market day and
every morning still has something worth a trip to town. Rule 3 holds: a new kind of job
(Wren wants worms, once there are worms) is one `.tres` in `data/orders/`.

**Cost.** Orders are deliveries only (no "catch" or "forage" yet; Stages 14–15 can add
patterns with other goals). The board's job can't be planned for: it asks for what you
might have in hand, which is the point. Brann's fibre job depends on weeds, so a very
tidy farm can't do it.

## 051 — A faster clock: 10 minutes per 5 real seconds (revisits 035)

**Decision.** `seconds_per_ten_minutes` in `data/game_rules.tres` goes from 7 to 5, so
6 AM to 2 AM now takes about 10 minutes of play instead of 14. Dave chose it on
2026-11-16 after playing: the day felt slow. Nothing else changes (no save change, still
v14); the clock still stops in menus and every hour, shop time and deadline is in game
minutes, so all of them simply arrive sooner.

Options considered: making the maps bigger so walking uses up the day. Rejected as the
fix: the player walks about 4.4 tiles a second, so the farmhouse-to-Hollis trip (about
42 tiles) costs only about 14 game minutes at the old pace, and even maps twice the size
would add well under an hour of walking to a 20-hour day. The slow feel comes from the
clock's pace and from having little to do once watered, which Stages 14–16 (woods,
fishing, cooking) address. A pace of 4 (about 8 minutes a day) was the other candidate.

**Why.** It's one number, it's easy to try, and Stage 20's balance pass checks it again
once the Woods, fishing and cooking fill the day.

**Cost.** Less time per day for the same work; opening hours and deadlines are tighter in
real time. If it's too fast, 6 is the halfway point.

## 052 — The Woods: a bridge that waits for summer, and forage worked out from the date

**Decision.** Stage 14 session 1 opens the Woods (ROADMAP sections 8 and 9), with
foraging. The axe and timber are session 2.

- *Where.* A river now runs along the top of the town and feeds the pond. The path up past
  Brann's carries on beside the pond to a bridge over it, at the top of the town's east
  side, as ROADMAP suggested. Through the gap beyond, the Woods: 48 × 32 tiles (the town is
  40 × 24), so it takes a little exploring. Five glades joined by two-tile paths, a stream
  down the east side with a footbridge, undergrowth at the glades' edges (the thicket
  tile; session 2's axe will clear it) and trees one to every 2 × 2 block everywhere else,
  close enough that their tops make one canopy and the trunks can't be squeezed between:
  the glades and paths are the way through. Like the town it has no state, so
  `WoodsLayout` is a function from a cell to its ground and its trees.
- *When.* The mayor's request (DECISIONS 049) gives `woods_bridge` and promised the bridge
  "by summer". A new unlock, `woods_open`, opens by the calendar on summer day 1 but only
  once `woods_bridge` is earned: `UnlockDef.needs`, a second unlock it waits for. Paid in
  spring, it opens on summer day 1 and the board pins it up a week before; paid later, it
  opens the next morning; never paid, never. The Woods' LocationDef `requires_unlock`
  is `woods_open`, so the existing door rule (LocationManager.closed_message) does the
  rest. The town shows the bridge whole (path under its picture, the edge open beyond) or
  broken (river, with stumps), and walking up to the broken one says why there's no way
  across.
- *Forage* is a kind of item: `ForageDef` extends `ItemDef` (as `ToolDef` does) with the
  seasons and places it grows in, a weight, and optionally the weather it needs (worms
  come up in the rain). One file per kind in `data/forage/`; ContentDB indexes them with
  the other items, so the bag, the bin, Rosa's stall and requests treat them like
  produce. Fourteen kinds: wild garlic, morel, primrose (spring); bilberries,
  elderflower, chanterelle (summer, chanterelle into autumn); blackberries, hazelnut,
  penny bun, puffball (autumn); holly, pine cone, velvet shank (winter); worms on rainy
  days from spring to autumn. Prices 3–60g, the rarer the dearer. Tags `mushroom` and
  `flower`, for Pip, the almanac and the flower show.
- *Where it lies.* Each morning `forage_per_day` spots (a LocationDef field: 10 in the
  Woods) among the glades' grass and the grass along the paths get something, picked by
  weight among what's in season there in today's weather. The dice are seeded by the
  place and the date, like Rosa's orders (DECISIONS 050), so the same spots hold the same
  things however often the player walks in and out. E picks one up (a `ForageSpot` in the
  "interactable" group, not solid), free of energy: foraging costs time, which the clock
  now makes count. What has been picked today is kept in GameState, so it stays picked
  after a trip to town, and is forgotten overnight. EventBus `foraged` announces each
  find (it makes the harvest sound; Stage 15's worms and the almanac can count it).
- *No save change* (still version 14). The game saves only overnight, and by morning
  everything has grown back somewhere new, so there is nothing to keep: the date decides
  it all. An old save that paid for the bridge and is past summer day 1 opens the Woods
  as it loads (open_due_unlocks already runs on load).
- *Pip's mushroom hunt* (ROADMAP 5.3): in autumn, once the Woods are open, bring a
  chanterelle, a penny bun and a puffball → 200g. It's a "bring one of each" request
  (DECISIONS 049), not a new "forage" goal: counting finds would have to be saved, and
  bringing them counts the ones found before he asked. ROADMAP's reward, a field guide
  showing the day's forage, is left for later; gold for now.
- *Small moves:* Wren's third spot (37, 4) is on the new path, so it moved to (30, 6). The
  mayor's offer now says the river is at the top of town (it said "past the farm"). The
  Woods have their own slow tune in A minor (`art/build_sounds.py`, added after
  everything else so no other sound changed) and Daylight, like the farm and town.
- *Placeholder art:* the bridge (whole and broken), the footbridge and the 14 forage icons
  are drawn by a script in the game's palette until Pixellab; the Woods use the farm's
  seasonal ground and trees until their own tileset.

Options considered for the opening: the quest giving `woods_open` directly (the Woods
the same afternoon, but the mayor's "ready by summer" would be wrong, and in spring the
Woods would open before anything in ROADMAP's summer arc); or a plain calendar unlock on
summer day 1 (open whether or not anyone paid). `needs` is one field and one line in
open_due_unlocks. For forage: fixed spots that refill each season (ROADMAP's first
wording) would mean saving what's been picked all season (a new save version) and a
woods emptied by the second week; daily spots are what section 9 recommends, and cost no
save change. For the map: a hand-drawn tile grid (exact, but a 48 × 32 table nobody could
read in a code file); the rectangles and rules here are short, and the trees, worked out
by position, are the same every time.

**Why.** ROADMAP section 9: a reason to leave the farm, income without energy (costing
time, now the clock is faster), and items for requests. Rule 3 holds: a new wild thing is
a `.tres` and an icon, and another place with forage is a `forage_per_day` and a list of
cells.

**Cost.** The Woods look like the farm's ground and trees until their tileset is made. The
bridge appears only on summer day 1 even if paid on spring day 20 (as promised). Forage
is the same in every game on the same date. Players can walk over forage, and must face
it to pick it up, like everything else. Fishing in the stream waits for Stage 15.

## 053 — The axe and timber: chopping on the farm and in the Woods, and Brann's sprinkler line

**Decision.** Stage 14 session 2 adds the axe and timber (ROADMAP sections 5.4, 5.8 and 8),
and the requests that need timber.

- *The axe* is a ToolDef (`data/tools/axe.tres`) with a new action, `ChopAction`. Marlow
  sells it from spring day 8 (a calendar unlock, `axe_on_sale`, so the board pins it up
  and the morning summary announces it), 150g; a swing costs 4 energy. How much timber
  each thing gives, and what timber is, are fields on the action in the axe's `.tres`
  (1 from thicket, 3 from a log): rule 6. No tiers yet.
- *On the farm* it chops thicket, a tile at a time: `FarmData.chop` turns the tile to
  grass (saved with the farm, as terrain always was) and gives 1 timber. A field stays on
  sale while any of its thicket is left; buying it clears the rest. The north field is
  126 tiles: about 500 energy, five days of work, against 500g. That is ROADMAP's "cheap,
  slow alternative", and the farm is the timber source before the Woods open.
- *Off the farm.* The Woods have no FarmData, so ToolAction gains a second pair,
  `can_use_away(place, cell)` and `apply_away(place, cell)`, asked of the map's scene
  (`Player.tool_place`, which the Woods set to themselves). Every other tool says no, so
  the town and shops are unchanged. The Woods answer `choppable_at(cell)` (&"thicket",
  &"log" or nothing) and `chop()`. The Woods show the tile cursor only when the held
  tool can do something there, so it doesn't follow the player about.
- *The Woods' undergrowth* (DECISIONS 052's THICKETS, 20 tiles) gives 1 timber a tile and
  stays down until the season turns (TimeSystem calls `GameState.regrow_undergrowth`).
  What has been chopped is the one new thing saved: `GameState.cleared`, location id ->
  cells. **Save version 15.**
- *Fallen logs*: each morning `LocationDef.fallen_logs_per_day` (3 in the Woods) lie
  across two tiles of a glade, placed like forage, by dice seeded by place and date
  (`FallenLogs`), so nothing about them is saved. They keep off every spot today's forage
  is on, picked or not, and off each other; and they only lie where every tile round them
  is open glade, so a log can never block a path or the way to anything (checked over a
  year of days). A log is solid; E on it says what it's for. Chopping one gives 3 timber,
  and it stays chopped for the day (remembered with the day's picked forage).
- *Timber* is a plain ItemDef in `data/produce/` (beside fibre), 2g at the bin: it's for
  requests, not money. Chopping announces EventBus `wood_chopped`; GameState puts the
  timber in the bag, the farm redraws the tile, FarmEffects throws wood chips (the Woods
  now have a FarmEffects too), and Audio plays a new `chop` sound (made last in
  `art/build_sounds.py`, with dice of its own, so no other sound changed).
- *Brann's sprinkler line* (ROADMAP 5.4). Sprinklers and big sprinklers are no longer on
  his shelf from the day the forge opens: each waits for an unlock his requests give.
  **The sprinkler design** (from summer day 5, after his test): 20 timber and 200g → a
  sprinkler and `sprinkler_design`. **Better pipes** (from summer day 19): 40 timber and
  600g → a big sprinkler and `better_pipes`. ROADMAP's "and something from the woods"
  is left out: the timber is from the woods. Mabel's pumpkin still gives a sprinkler,
  so one can come early that way.
- *A delivery with a fee* is a new goal kind, `CommissionGoal` (extends DeliverGoal with
  `fee`): the items as a delivery, the gold as a gift (DECISIONS 049). `Quests.is_ready`
  now also checks the purse holds the goal's `gold_to_hand_in()`, so the "?" waits for
  both; the request log reads "12 / 20 timber, and 200g".
- *Ivy's glasshouse frame* (ROADMAP 5.8, part 1): autumn or winter, after her basket,
  50 timber → 300g and the unlock `glasshouse_frame`. Parts 2 and 3 (1,500g; autumn
  crops and a fish → the greenhouse) wait for fishing and the greenhouse (Stages 15, 17)
  and can `requires_unlock` the frame.
- *Old games* (save version 14 and earlier) could always buy sprinklers, so the upgrade
  gives them both unlocks and ticks both of Brann's sprinkler requests off, as version
  10 did for his first request: nobody loses something they could buy.
- *Small fix:* names that don't take an s ("20 timber", "12 fibre", holly, kale, garlic,
  corn, rhubarb) stay the same in the plural (`QuestGoal.SAME_IN_PLURAL`). The board's
  fibre jobs used to say "12 fibres".

Options considered: for the Woods' undergrowth, growing back every night like forage (no
save change, but chopping the same 20 tiles every morning would be the best timber in the
game and the glades would never open up) or staying down for ever (a one-off 20 timber).
Back each season makes it a small seasonal supply and opens the glades for a while. For
working off the farm: Woods cells as nodes in an "interactable"-style group (one node
per undergrowth tile, for something the map already knows), or making the Woods a
FarmData (a whole saved tile grid for a place whose only state is 20 cells). Asking the
scene keeps rule 5: the player still never knows which tool it holds. For Brann's fee:
a request with two goals (a bigger change to QuestDef, the log and every goal check),
or two requests in a row (timber, then gold: an extra trip for nothing).

**Why.** ROADMAP section 8: the axe is the timber source and a cheap way to land; section
5: Brann's and Ivy's lines needed timber to exist before they could be written. Rule 3
holds: another place with logs is a `fallen_logs_per_day` and a `log_cells()`, and
another commission is a `.tres`.

**Cost.** Sprinklers come later in a new game than they used to (summer, and 200g plus
timber, instead of the forge's second week). Fallen logs are the same in every game on
the same date. A field partly chopped still costs its full price. Placeholder art: axe,
timber and fallen log, drawn by a script in the palette until Pixellab.

