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

## 054 — Fishing: a rod that only casts, a service that runs the bite, and fish as data

**Decision.** Stage 15 session 1 adds fishing (ROADMAP sections 5.5, 8 and 9): the rod, a
cast-and-timing minigame, fish as data, a fish log, and the first two of Wren's requests.
Ice fishing, the rest of Wren's line and the better rod are session 2.

- *The rod* is a ToolDef (`data/tools/fishing_rod.tres`) with a new action, `FishAction`.
  It only casts: facing water, Space pays 2 energy and announces EventBus `line_cast`
  (the cell, the kind of water, and how long this rod makes the wait). It works on the
  farm's pond (FarmData's WATER) and, through `can_use_away` (DECISIONS 053), wherever the
  map answers `water_at(cell)`: the town (its pond, and the river along the top) and the
  Woods (the stream). The town now sets `Player.tool_place` too, and both show the tile
  cursor only where the rod would cast. Not sold: Wren gives it.
- *Fishing* is a new autoload (`scripts/autoload/fishing.gd`) that takes over from
  `line_cast`: WAITING (the float sits 2.5–7 seconds), BITING (the float goes under with
  a "!": Space within 1.2 seconds strikes), REELING (a bar over the farmer's head, a marker
  swinging end to end, a green zone: Space over the green is a good pull, anywhere else
  slack). Enough good pulls land the fish; a third slack pull, or 8 seconds without a
  pull, loses it. Space too soon reels in empty, and E gives up at any point. Going
  anywhere (a door, bed, passing out) reels in. While a line is out the player stands
  still and leaves the keys to Fishing (`Fishing.is_busy()`); the clock runs on, so
  fishing costs time, not much energy. It's timing, not speed: the marker swings at a
  steady pace and the zone is wide for small fish.
- *The look* is `FishingLine`, a node put in the current scene while the line is out:
  the line sagging from the rod tip, the float bobbing (a picture,
  `assets/sprites/fishing/bobber.png`, so Pixellab can replace it), rings on the water,
  the "!" and the bar with a pip per pull. Cast upwards, the float lands a little further
  out and the bar goes under the feet, so the farmer's hat doesn't hide either.
- *Fish* are a kind of item: `FishDef` extends `ItemDef` (as `ForageDef` does) with the
  waters it lives in (`pond`, `river`, `stream`), optionally only certain places, the
  seasons, the stretch of the day it bites (`bites_from`/`bites_until`, in the clock's
  minutes), optionally the weather, a weight, a size range in cm and a fight from 1 to 5.
  Fifteen, one file each in `data/fish/`: roach, rudd, perch, tench (early mornings),
  crucian carp, carp, pike (autumn and winter), eel (nights), chub, dace, barbel (dusk),
  grayling, brown trout, minnow, sea trout (the stream, in rain). 5–75g. At least one bites
  in every water, at every hour, in every season but winter (checked). Which fish bites
  is decided when it bites, by weight among those biting there and then; its size when
  it's hooked (two dice averaged, so records are rare).
- *How hard* is data too: `FishingRules` (`data/fishing_rules.tres`, from game_rules.tres)
  has the waits, the strike time, and for each step of fight the marker's speed, the
  zone's width and the pulls needed (a minnow: one pull in a wide zone; a pike: three in
  a narrow one, fast), the slack allowed, the patience, the bait and the frozen seasons.
  What differs between rods (`bite_wait_multiplier`) is on the rod.
- *Winter:* every water is drawn as ice in winter, so it is ice: the rod can't be used
  (`usable_in_season`, so the hotbar greys it) until session 2 cuts a hole. The winter
  fish (perch, pike, roach, grayling, chub, dace, minnow) are written already.
- *Bait*: a plain ItemDef in `data/produce/`. With any in the bag, each cast uses one and
  the wait is halved. Worms are not used as bait: they're for Wren and the board.
- *The fish log*: `GameState.fish_log`, fish id -> how many caught and the biggest (cm),
  for the almanac, the summer contest and Pip's biggest fish to come. The catch message
  says "your first" or "your biggest yet". **Save version 16**; older games have caught
  nothing. EventBus `fish_caught` (fish, size, place, water) is what Quests, DayReport
  (a "Caught" row in the morning summary) and Audio hear; `fish_bit`, `fish_hooked` and
  `fish_escaped` are for the sounds. Three new sounds (cast, bite, splash), made last in
  `art/build_sounds.py` with dice of their own, so no other sound changed.
- *Wren's line* (ROADMAP 5.5), parts 1 and 2. **Wren's worms** (from summer day 2, once
  the Woods are open, not in winter when there are none): 5 worms → the rod, and Wren
  explains it. **Something for supper**: catch any 3 fish → 10 bait, and Marlow sells
  bait from then on (5g, unlock `bait_on_sale`). A new goal kind, `CatchGoal`: counts
  `fish_caught`, optionally one kind, one water or a smallest size, so Wren's river fish,
  Pip's biggest fish and the contest are a `.tres` each. Wren's daily lines now hint at
  the hours and waters.
- *Small:* "3 perch", "2 pike", "10 bait": most fish names stay the same in the plural.

Options considered: the minigame as its own scene that pauses the game (like the shop
menu: simpler input, but fishing would stop the clock, and "fills afternoons" means it
should cost time), or as code inside the Player (no new autoload, but the player would
grow a state machine for one tool, against rule 5). A service woken by an EventBus
signal keeps the rod a ten-line ToolAction and the player unaware of fishing. For the
bar: hold-to-reel against a moving fish (more twitchy, and harder to tune); a press in a
zone is ROADMAP's "a timing bar, not twitchy". For winter: leaving open water to fish in
(the tiles show ice everywhere, so it would look wrong) or no fish at all in winter
(ROADMAP wants ice fishing): frozen until session 2's hole.

**Why.** ROADMAP section 9: fishing fills afternoons and winter, adds a light skill, and
gives fish for requests, cooking and the contest. Rule 3 holds: a new fish is a `.tres`
and an icon; a new fishing request is a `.tres`; another fishing place is a
`water_at(cell)` on its map.

**Cost.** One more autoload. The farm's pond is inside the pond field, behind thicket,
until the field is bought or chopped; the town's pond and river are open from the start.
Fish are the same price whatever their size. Placeholder art: 15 fish icons, the rod,
bait and the float, drawn by a script in the palette until Pixellab.

## 055 — Ice fishing, lures, the fine rod, and the rest of Wren's line

**Decision.** Stage 15 session 2 finishes fishing (ROADMAP 5.3, 5.5, 5.8, 5.9 and the
summer calendar): ice fishing in winter, Wren's last two requests of the first year, the
summer contest, Pip's biggest fish, a fish in Ivy's restoration and fish jobs on the
notice board. **No save change** (still version 16).

- *Ice fishing.* The rod now works all year (`FishAction` lost its winter ban). In a
  frozen season (`FishingRules.frozen_seasons`), Space with the rod on bare ice cuts a
  hole there instead of casting, for the cast's 2 energy (EventBus `ice_hole_cut`, the
  chop sound); Space at a hole casts through it. The wait through ice is 1.5 times as
  long (`ice_wait_multiplier`: Wren's "ice and patience"). Only the fish that bite in
  winter come up (written in session 1: perch, pike, roach, chub, dace, grayling,
  minnow). Facing up, the tile ahead is behind the farmer's hat, so the hole goes one
  tile further if that's ice too (as the float lands further out on open water). The
  holes are kept by Fishing, by location, and drawn as `IceHole` pictures
  (`assets/sprites/fishing/ice_hole.png`) on the ground's level of whichever map is
  showing. **The night freezes them over**, so they are never saved, and walking away
  and back finds them still open that day. `fish_caught` gained a fifth value,
  `through_ice`.
- *Lures.* A new kind of item, `LureDef` (extends ItemDef: seasons, wait multiplier),
  listed in `FishingRules.lures`. A lure is kept in the bag and never used up; on a
  day in its seasons it shortens the wait, and the bait stays in its tin. Two: Wren's
  **winter lure** (winter, ×0.5) and **Pip's spinner** (spring to autumn, ×0.75).
- *The fine rod* is a tier of the rod, given the way the wide hoe is: a `ToolTier`
  ("Fine rod") on `fishing_rod.tres` and an `UpgradeDef` (`fine_rod`) with a
  ToolTierEffect. Its speed is `FishingRules.rod_tier_wait_multipliers` (×0.6 at tier
  1). Two small new fields make it a gift: `QuestDef.reward_upgrades` (Quests adds them
  on hand-in, the reward text names them) and `UpgradeDef.gift_only` (no shop sells it,
  whatever its price). So the hotbar's rod simply becomes "Fine rod".
- *How long the float waits* is worked out by `Fishing.wait_factor()`: the rod's tier,
  then the ice, then a lure that works today or else bait.
- *Wren's line*, parts 3 and 4 (part 5, the legendary fish, is year 2): **The river
  fish** (after supper, from summer day 15: any fish from the Woods' stream → the fine
  rod) and **Ice and patience** (winter, after the river fish: any fish through the
  ice → the winter lure). Wren's daily lines mention the ice and the contest.
- *The summer contest hook.* A `CalendarEvent` `fishing_contest` on summer day 14 each
  year (day 42, every 112 days; never a market day), shown on the notice board, and
  Wren's one-day request **The summer contest** (`on_event`, due tonight, after the
  worms): any fish of 25 cm or more from the town's pond → 300g. Judging against other
  anglers, prizes by size and the crowd are Stage 18's festivals. `CatchGoal` gained
  `location`, `through_ice` and `where` (the words for the place).
- *Pip's biggest fish* (summer day 15 on, once bait is on sale): any fish of 40 cm or
  more → Pip's spinner.
- *Ivy's restoration*, parts 2 and 3: **The glass** (after the frame: 1,500g →
  `glasshouse_glazed`) and **Ivy's first planting** (autumn, after the glass: a pumpkin,
  a cranberry, a beetroot and any fish → 500g and `glasshouse_restored`). The greenhouse
  plot itself is Stage 17, which should wait for `glasshouse_restored`. The "any fish"
  is a new option on `DeliverEachGoal`: `and_one_of` (a list, the cheapest first, as
  hand-in takes the first the bag has) and `and_one_of_what` ("a fish").
- *The notice board* has a fifth job pattern, `board_wren` (once bait is on sale): 1–3
  of a fish for Wren, by tonight. `Quests._in_season` now treats a fish as in season if
  it bites this season, and never offers one that waits for weather.

Options considered: for winter, open-water patches (simpler, but every water is drawn
as ice), or a separate ice auger tool (one more item to carry for one job; the rod's
own Space reads naturally). For holes: saving them (a save change for something that
would refreeze anyway). For the better rod: a second rod item (two rods on the hotbar,
and the old one useless), or a field on ToolTier (a rod-only number on every tool's
tier); the tier plus a number in the fishing rules keeps both generic. For the contest
while Wren is busy: letting an event request jump the one-at-a-time rule (it would
need two requests in hand from one person, which the log and the talk don't do). The
river fish waits until the day after the contest so it can't block it; if the worms or
supper are still in hand on contest day, the contest is missed that year.

**Why.** ROADMAP section 9: fishing fills winter as well as afternoons. Rule 3 holds:
another lure, another fish job or another contest prize is a `.tres`.

**Cost.** The contest is a request, not yet a festival: one prize, no rivals. Winter
fishing takes some walking-to-the-ice the first time each day. Placeholder art: the ice
hole, the winter lure and the spinner, drawn by a script in the palette until Pixellab.

---

## 056 — Cooking: recipes as data, a stove that waits for Mabel, and food eaten from the hotbar

**Decision.** Stage 16 session 1 adds cooking, for energy only (ROADMAP section 9:
narrows 006, no selling chains). **Save version 17** (the recipes known).

- *Dishes are tools you eat.* A dish is a `ToolDef` whose action is the new
  `EatAction` (`energy`: what one helping gives back), kept in `data/dishes/`. So it
  sits on the hotbar like a packet of seeds, Tab and Q reach it, it shows a count and
  leaves the hotbar when the last is eaten (`consumed_on_use`). Its sell and buy
  prices are 0, so no shop or bin takes it (ContentDB warns if one ever has a price).
- *Eating is used on the farmer, not a tile.* `ToolAction` gained one method,
  `used_on_self()` (false for every tool so far). The player asks it first: a dish
  goes to `GameState.eat()` wherever the farmer is (the farm, the town, a shop, the
  Woods), and its tile methods are never asked. Eating at full energy does nothing
  and says so, so a helping is never wasted; otherwise energy goes up to today's
  maximum. EventBus `dish_eaten`, the "eat" sound, and the hotbar's name line says
  "Space to eat, +30 energy".
- *Recipes are data.* `RecipeDef` in `data/recipes/`: the dish, how many it makes,
  particular things (`ingredients`, a dictionary of item → count) and optionally some
  of a kind (`any_tag`, `any_count`, `any_what`: "any fish", "any 3 fruit"), found by
  the items' tags so a new fish or fruit works without touching a recipe. Of a kind,
  the cheapest go in first (a minnow before a pike; blueberries before the melon),
  and the menu says so. A new `&"fruit"` tag is on the strawberry, blueberry,
  cranberry, melon, apple, rhubarb, bilberries and blackberries.
- *Known recipes are saved* as `GameState.recipes`: recipe id → times cooked, for the
  almanac (Stage 19). `learn_recipe()` (EventBus `recipe_learned`), `cook()`
  (EventBus `dish_cooked`, the "sizzle" sound).
- *The stove.* In the farmhouse, against the back wall between the bed and the table
  (cell 4,2). It's always there, cold until `GameRules.kitchen_unlock`
  (`farmhouse_kitchen`) is earned; E at a cold stove says Mabel could teach you. E at
  a lit stove opens `CookMenu`, which works like the shop's counter: paused, a list
  of every known recipe with its energy, what's in the bag ("2 tomatoes (have 3)") and
  dimmed if something's missing; Space cooks one, Esc leaves. Cooking costs no energy
  and no time: its cost is the produce that could have been sold.
- *Where recipes come from.* A new `QuestDef.reward_recipes` (named in the reward
  text: "the recipes for tomato soup, potato and bean hash and fruit crumble").
  **Mabel's kitchen lessons** (`baker_kitchen`, ROADMAP 5.2 part 4): after the tarts,
  from summer day 15 (summer or autumn), a tomato, a green bean, a potato and some
  fruit → the farmhouse kitchen and her three favourites. **Her leek pies** (winter)
  now also give her recipe book: leek and potato soup, winter stew, bubble and squeak,
  pumpkin soup, fish pie, mushrooms on toast. **Wren's river fish** also teaches
  grilled fish. Recipes taught before the kitchen is open wait for it.
- *Ten dishes*, energy 30 to 70 (max energy is 100): tomato soup 30 (2 tomatoes),
  potato and bean hash 40 (potato, 2 green beans), fruit crumble 45 (any 3 fruit),
  leek and potato soup 40, winter stew 60 (leek, kale, sprouts), bubble and squeak 40
  (cabbage, potato), pumpkin soup 50 (a pumpkin), fish pie 70 (2 potatoes, any fish),
  mushrooms on toast 35 (any mushroom), grilled fish 30 (any fish).
- *v16 → v17*: `"recipes"`, empty, except that a game which had already finished
  Mabel's leek pies or Wren's river fish is given what they now teach (a frozen list
  in the upgrade step). `tests/saves/v16_example.json` was made by the real v16 build.

Options considered: a separate `DishDef` item class beside ToolDef (the hotbar,
selection and counts would all have needed teaching about a second kind of usable
thing); an "eat" key of its own (one more key to learn, and the roadmap says eat from
the hotbar); an `EatAction` that pretends every tile is usable (it would not work in
shops and the farmhouse, which have no tiles to use, and the cursor would lie).
Cooking time (a clock cost) was left out because Dave already finds the day short
of time; Stage 20's balance pass can add one. The kitchen as a separate building or
upgrade was left for later: Mabel opening it is the roadmap's "[unlock]".

**Why.** Energy is the game's main brake; food is a second lever on it, earned by
farming and foraging, with fishing and the Woods feeding into it. Rule 3 holds: a new
dish is two `.tres` files and an icon; teaching it is one line on a request.

**Cost.** One more method on the tool interface. The fish pie (70) is generous for a
minnow and two potatoes; Stage 20 should look at energy per gold across the dishes.
Placeholder art: the stove (lit and cold) and ten dish icons, drawn by a script in
the palette until Pixellab.

---

## 057 — The greenhouse is a second plot under glass, and bee hives are objects that make honey

**Decision.** Stage 17 session 1 adds the farm's greenhouse (ROADMAP 5.8, section 8) and
bee hives (section 9). **Save version 18** (the greenhouse's plot; a hive's honey in the
making). Fertilisers, the sickle's tiers and the brass sprinkler are session 2.

- *The old greenhouse stands on the farm from the start*, west of the farmhouse (door at
  cell 2,11; 80 × 48, five tiles by three). It's a `LocationDef` like the farmhouse, so
  `FarmLayout` makes its ground BUILDING terrain and the farm builds it from data. Until
  it's mended it shows a broken picture (new `LocationDef.locked_exterior`) and its door
  is shut (`requires_unlock`, the unlock `farm_greenhouse`) with a line that points the
  player towards someone who knows glasshouses. `Building` swaps the picture the moment
  the unlock arrives, and winter has a snowy roof for it (`SeasonTheme.object_sprites`).
- *Ivy mends it* with a fourth request, **A glasshouse of your own** (`ivy_greenhouse`):
  after her first planting (so from autumn in year 1), 30 timber and 800g for the
  glazier → `farm_greenhouse` and five strawberry seeds ("strawberries in the snow").
  ROADMAP 5.8 had the restoration itself open the greenhouse; her thanks line already
  promised "an idea for your farm", and a separate step keeps her own glasshouse in town
  hers. The cost is a number in the `.tres`, for Stage 20 to tune.
- *Inside is a plot that is a second FarmData* (`GameState.greenhouse`, built by
  `GreenhouseLayout`: 8 tiles wide, 6 deep, a walkway round it, the door at the bottom).
  It starts dug over. `FarmData.under_glass` marks it. Because it's a FarmData, every
  tool, crop rule, sprinkler, hive and the trowel work on it unchanged: the player now
  asks `GameState.plot_here()` (the farm's plot on the farm, the greenhouse's in the
  greenhouse, null elsewhere) instead of naming the farm, and so do harvesting, pulling
  weeds, picking things up and collecting honey.
- *Under glass, the seasons and weather don't reach.* Any seed can be planted whatever the
  season (`GameState.tool_usable_here()`: the player and the hotbar ask it instead of the
  seed directly). In the night (`TimeSystem._grow_greenhouse`) the plot grows with no
  season (nothing rests, nothing withers at the turn) and no weather (no heatwave thirst,
  no rain to water it, no storm, no frost), then giants and sprinklers as outside. No
  crows, aphids or weeds get in: `FarmHazards` is simply never run on it. Thirst still
  applies, so the can is still needed, and the morning's thirst warning counts both plots.
- *The greenhouse scene extends the farm's* (`greenhouse.gd` extends `main.gd`). `main.gd`
  now draws `plot` (whatever `_plot()` returns) and its `_ready` calls a few functions the
  greenhouse replaces: the surroundings (the glass room and the door instead of the
  farm's buildings and town gate), the season's tileset and overlay, the season's look of
  objects. So every crop, wilting tint, aphid, giant and object is drawn by one piece of
  code. The room has its own placeholder tileset (`greenhouse_tileset.tres`: brick paving,
  glass wall); the soil keeps spring's ground tiles all year. The evening light reaches in
  through the glass (it has a Daylight like the farm).
- *Bee hives* are placed like sprinklers (a `ToolDef` with `PlaceObjectAction`, at
  Marlow's for 500g from summer day 1, unlock `bees_on_sale`). An `ObjectDef` can now
  **make** something: `makes` (honey), `makes_every_days` (3), `makes_amount` (1),
  `makes_in_seasons` (spring to autumn; all year under glass), and `flower_radius` /
  `flower_bonus` (a flower within 4 tiles adds a jar). Flowers are the aphids' flowers (a
  crop tagged `flower`, past the seed) plus objects with `counts_as_flower` (the flower
  bed). `FarmData.run_makers()` runs every night on both plots, after the sprinklers; the
  tile keeps `made_days` and `made_ready`. A full hive makes no more until emptied.
- *Collecting:* E at a hive with honey takes it all (`GameState.collect_from_object`,
  EventBus `object_made` and `object_emptied`, the harvest sound); a jar floats over a
  full hive (a "Ready" child in its scene, which `PlacedObject` shows and hides); E at an
  empty hive picks it up, as for any placed object, and its days start again. The
  morning summary says when the bees have made honey. Honey sells for 80g.
- *v17 → v18*: an empty greenhouse plot (written out in the step, not built by today's
  code), and the greenhouse's five by three cells on the farm become BUILDING. As version
  7 did for the farmhouse, nothing there is lost: crops go back in the bag as their seeds
  (a tree as its sapling, also one reaching in from outside), sprinklers and decorations
  as themselves. `tests/saves/v17_example.json` was made by the real v17 build, with
  crops, a sprinkler and a scarecrow standing where the greenhouse now goes.

Options considered: the greenhouse as Ivy's restored glasshouse in town (no farm cells to
clear, but the roadmap and Ivy's own words put it on the farm); a greenhouse that appears
only once mended (it would land on crops mid-game, with no warning); a placeable
greenhouse (a building as an item is a much bigger change). For the plot: a new kind of
tile store beside FarmData (every tool would need teaching about it), or a flag on farm
tiles saying "under glass" inside the farm's own map (the greenhouse would then be a hole
in the farm, and the room couldn't have walls). For hives: honey kept in the hive's scene
(lost when the farm scene is rebuilt each morning, and never saved), or a separate
"hives" list in GameState (two records of where a hive stands). Picking a hive up with
honey in it was ruled out: E always collects first.

**Why.** The greenhouse is winter's main farming (ROADMAP section 3) and Ivy's reward;
reusing FarmData means the whole crop system works in it with no second copy. Bees are
passive income that rewards flowers in the layout. Rule 3 holds: another maker (a
mushroom log, say) is an ObjectDef with `makes`, and a different greenhouse is a
LocationDef and a layout.

**Cost.** `main.gd` is now also the greenhouse's base, so a change to how the farm draws
reaches the greenhouse too (usually what's wanted). A few cells beside the farmhouse are
taken from older farms (their contents returned). Honey is only sold for now; recipes or
requests can use it later. Placeholder art: the greenhouse (mended, broken, winter), its
inside tiles, the hive, its icon and honey, drawn by a script in the palette until
Pixellab.

---

## 058 — Fertilisers stay in the soil, the sickle is a tool with tiers, and the brass sprinkler ends Brann's line

**Decision.** Stage 17 session 2 adds the late tools (ROADMAP section 8, 5.4): two
fertilisers, the sickle and its tiers, and the brass sprinkler. **Save version 19** (fed
soil on a tile).

- *Fertilisers are bags that go into tilled soil and stay there.* A new `FertiliserDef`
  (a `ToolDef`, so it's on the hotbar, bought by the bag and used up a bag a tile) says
  what fed soil does: `skips_stages` and `keeps_wet_nights`, plus `soil_look`, a
  see-through 16 × 16 picture laid over the soil (a "FedSoil" layer just above the
  ground in `main.gd`, so it shows on the farm and in the greenhouse). One action,
  `FertiliseAction`, names its bag by id (as `PlaceObjectAction` names its object).
  The tile keeps the bag's id (`FarmTile.fertiliser`); `FarmData.can_fertilise()` and
  `fertilise()` put it in. It stays through harvests, so a bed fed once feeds every crop
  sown in it, and goes when the soil goes back to grass or something is put down on it
  (the same two moments a seed bed stops being one). One fertiliser to a tile.
- **Growth feed** (`skips_stages` 1): a seed sown in fed soil comes up at once, a stage
  ahead, so a parsnip is ripe in 3 watered nights, not 4. Feeding a seed just sown moves
  it on the same way. It never makes a crop ripe, and won't go on a crop that has started
  growing (that would be a free stage every time it's used). Marlow sells it from spring
  day 22 (unlock `feed_on_sale`), 40g a bag. A fed seed dug up straight away still gives
  its seed back.
- **Mulch** (`keeps_wet_nights` 1): watered soil under mulch stays wet one night longer
  (`FarmTile.kept_wet` counts the nights), so one can of water lasts two nights; it goes
  on any tilled soil, crop or none. Ivy gives ten bags with her autumn basket and asks
  Marlow to stock it (unlock `mulch_on_sale`), 25g a bag. ROADMAP had fertiliser from
  "Marlow; Ivy's line": growth feed is Marlow's, mulch Ivy's.
- *"One stage faster" as a skipped stage, not a quicker day.* A multiplier on grow time
  (as the difficulty uses) was the first idea, but every stage of most crops is one day
  and no stage can take less than a day, so a parsnip wouldn't grow any faster at all. Skipping
  the seed's stage works for every crop and is easy to see (a sprout appears the moment
  you sow).
- *The sickle* (`SickleAction`) cuts weeds (as E pulls them: fibre) and picks ripe crops
  (EventBus `crop_cut`, which GameState answers by picking the crop exactly as E does,
  dice for bunches and seeds included; a tool can't use GameState itself). Unripe crops
  are left alone, so a wide swing over a mixed bed is safe. Tiers like the hoe's: Sickle
  1 tile (1 energy), Wide sickle 3 in a row (2 energy, 400g), Great sickle 3 × 3 (4
  energy, 1200g, after the wide one and Brann's great tools). A giant or tree is picked
  once however many of its tiles the swing covers.
- *Brann's line, parts 4 and 5.* **Sickle work** (`blacksmith_sickle`, after better pipes,
  from autumn day 5): 30 fibre → the sickle, and the unlock `sickle_made` puts the wide
  sickle on his shelf. **The brass sprinkler** (`blacksmith_brass`, after the sickle,
  winter from day 10): 3 velvet shanks (winter's rarest forage, "to quench the brass")
  and 2500g → a brass sprinkler, and `brass_on_sale` puts more on his shelf at 2000g.
  The brass sprinkler is an `ObjectDef` with 24 `water_offsets` (two tiles out on every
  side), placed and picked up like the others.
- *v18 → v19*: no tile was fed in an older game, so the tiles need nothing. Ivy's autumn
  basket now gives mulch; an older game that had already handed it in is given the ten
  bags and `mulch_on_sale` (written out in the step, as v17 did for recipes).
  `tests/saves/v18_example.json` was made by the real v18 build (crops, a big sprinkler
  and the greenhouse planted; Ivy's basket and Brann's pipes done).

Options considered: fertiliser used up by each harvest (a decision every sowing, but a
regrowing crop would keep it for ever anyway, and it's one more thing to explain);
fertiliser as a mark on the tile with no item (nothing to buy or give); mulch as a
lasting "watered" flag (soil that never dries is a sprinkler with no cost). For the
sickle: harvesting inside `FarmData` (the bag isn't the farm's business) or a
GameState call from the tool (the load-order rule in tool_action.gd). For the brass
request: timber again (Brann has had 60 already), so the rarest winter forage instead,
which also sends the player to the Woods in the quiet season.

**Why.** Fertilisers give gold a use on the farm itself and reward planning a bed;
mulch lightens the watering that sprinklers otherwise own. The sickle turns weeding and
big harvests from many presses of E into a few swings. The brass sprinkler is the
late-game prize the roadmap gives winter. Rule 3 holds: a third fertiliser, a fourth
sickle tier or a bigger sprinkler is a `.tres`.

**Cost.** Fed soil is a little more state on every tile (saved only when there). A fed
bed lasts as long as it's kept sown, so feed is cheap over a season: Stage 20 should look
at its price, and whether it should go at the season's turn. Placeholder art: the two
bags, their soil looks, the sickle and the brass sprinkler, drawn by a script in the
palette until Pixellab. No new sounds: fertiliser uses the sowing sound, the sickle the
weeding and harvest sounds.

## 059 — Festivals are calendar events with a host, and a contest is a rule, rivals and prizes

**Decision.** Stage 18 session 1 adds the four festivals of ROADMAP section 3 (the spring
flower show, the summer fishing contest, the autumn harvest fair and lantern night), on
placeholder art. **Save version 20** (the festival log).

- *A festival is a `CalendarEvent` with a host.* New fields on the event, under a
  "Festival" group: `host` (a CharacterDef id) and `host_cell` (where they stand all day,
  instead of their usual spot), `host_lines`, a `contest`, `gift_items` with a
  `gift_line` (a keepsake handed over once on the day), and `decorations` (ObjectDef ids
  by cell, put up on the event's map for the day, like the town's own objects). Dates
  work as they always have: each festival is `first_day` and every 112 days (once a
  year): flower show day 24 (spring 24, which is also a market day), fishing contest day
  42 (summer 14), harvest fair day 77 (autumn 21), lantern night day 112 (winter 28).
- *A contest is a `ContestDef`*: a `ContestRule` (what can be entered and how it scores),
  `judged_at` (minutes; entries close then), `rivals` (`ContestRival`: a name, what they
  bring, a score range) and `prizes` (`ContestPrize`: gold and items, first place
  first), plus the host's words (`invite_lines`, `question`, `nothing_line`,
  `entered_line`, `waiting_line`, `results_line`, with {entry}, {score} and {time}
  filled in). Rules follow the QuestGoal pattern, one small script per kind in
  `scripts/festivals/`: **BestItemRule** (hand one thing over; it scores its own sell
  price, before difficulty; filtered by `tag` and/or `grown_only`; optional points for
  `bonus_object`s standing on the farm, `bonus_each` up to `bonus_most`) and
  **BiggestFishRule** (sign up, then the biggest fish landed in `location`'s `water`
  before the judging; needs the `rod`). A rule touches no autoload: the Festivals
  service counts the bonus objects and says whether an item is grown.
- *The Festivals autoload* (after Fishing) runs the day: what the host says
  (`talk`, then `question_for` the best three things in the bag that the rule accepts,
  or "Sign me up", with "Not yet" last), entering (`answer`: the item leaves the bag),
  the judging as the clock reaches `judged_at` (or as the day ends, if the farmer has
  gone to bed first), the prize given at once with a HUD message, and the results read
  out by the host afterwards (3rd, 2nd, 1st, and your place if lower). Rivals' scores
  come from dice seeded by the festival and the date, so a day always turns out the
  same. A tie goes to the farmer. Signed up and caught nothing: no place. The town asks
  `Festivals.spot_for` where a host stands, and talking to a host goes to Festivals
  first unless they're waiting for a request you can hand in now; markers: "!" for a
  contest still open (or a gift waiting), "?" once your result is in and unheard.
- *The four festivals.* **Flower show** (mayor, judged 2 PM): any flower (tag `flower`),
  +10 points per garden flower bed on the farm up to +50 ("tulips and the flower bed
  matter"); four rivals scoring 25–70; prizes 250g and a **bird bath**, 120g, 50g.
  **Fishing contest** (Wren at the pond, judged 2 PM): biggest fish from the town pond
  after signing up; rivals 15–40 cm; 400g and an **angler's cup**, 200g and 10 bait, 80g.
  **Harvest fair** (mayor, judged 3 PM): anything a crop gives; rivals 80–290; 500g and
  the **harvest fair cup**, 250g, 100g. **Lantern night** (mayor, evening): no contest;
  lanterns round the square glow after dark, and the mayor gives each farmer a **paper
  lantern** (a decoration that glows) once on the night. Prize decorations have no price
  (rewards only), like the sundial.
- *Wren's one-day request "The summer contest" (DECISIONS 055) is gone*: the festival
  replaces it (it gave 300g for any 25 cm fish). Its file, `data/quests/wren_contest.tres`,
  has to be deleted by hand. An old save that had done it keeps the entry in its request
  log, which does nothing.
- *The day.* The notice board's event page says when judging is ("Judging at 2 PM."),
  today and ahead; the morning summary says "… today!" with the judging time; the night's
  summary lists the result in gold ("Spring flower show: 1st place, 250g and a bird
  bath"). New EventBus signals `festival_entered`, `festival_judged`,
  `festival_gift_given`; sounds reuse the chime, the request-done jingle and "nope".
- *v19 → v20*: `GameState.festival_log` (saved as "festivals"): a list of
  `{"event", "year", "day", "place"}` plus `"entry"` and `"score"` for a contest, for the
  year review and almanac (Stage 19). Older games have taken part in nothing.
  `tests/saves/v19_example.json` is the v18 example brought up by the real v19 build.

Options considered: festivals as requests (`QuestDef` with `on_event`, as the contest hook
was): one prize, no rivals and no judging, so no; a separate `FestivalDef` beside the
calendar: a second way of saying "on this day", where the event already has dates,
location, unlocks and the notice board; judging on hand-in (no suspense, and the fishing
contest can't work that way); the prize kept until you talk to the judge (a prize missed
by going home early). Real rivals' entries from the town's own people: the townsfolk
named in contests are off-screen, so they need no art or schedules yet.

**Why.** The roadmap asks for four set-piece days, each a small activity on existing
systems; a contest that's a rule plus data lets each be a `.tres`, and a new kind (a
cooking contest, say) one small script. Seeded dice keep the result the same for a day
whatever the player does with their time, like the orders (DECISIONS 050).

**Cost.** Entries live only for the day (a save is always dawn). The harvest fair's
"a giant pumpkin wins outright" isn't in: a giant gives ordinary pumpkins, so the fair
can't tell; it needs a giant item or a giant counted in the log (session 2). The mayor's
year review at lantern night is Stage 19. Placeholder art: the flags, the two show
tables, the contest sign, the festival lanterns and the four prizes, drawn by a script
in the palette until Pixellab. Balance (rival ranges, prize gold) is for Stage 20.

## 060 — Ways out are data, the Lane joins the farm to the town, and the farm grows with debris to clear

**Decision.** Stage 19 session 1 starts ROADMAP section 13 (agreed 2026-11-17): the first
new place (the Lane), the farm grown to 48 × 32 with overgrown new ground, and the
mechanism every later place will use to join the map. Placeholder art. **Save version 21**
(the farm's new ground).

- *Exits are data.* A new `ExitDef` (`to`, the gap's `cells` just outside the edge, the
  `arrival` cell just inside) and `LocationDef.exits`. `Exits.add()` turns each into an
  `ExitZone` and a spawn point; `Exits.gap_cells()` tells the map which edge cells to draw
  as path. One naming rule means the two ends of a road never name each other's spawn
  points: leaving `here` for `to` arrives at "from_<here>" in `to`, and an exit to `to`
  makes "from_<to>" here. The farm (gate → the Lane), the Lane (west → town, east → farm),
  the town (east → the Lane) and the Woods (south → town) all use it; `FarmLayout.TOWN_GATE`,
  `TownLayout.FARM_GATE`/`ARRIVAL_FROM_FARM` and `WoodsLayout.TOWN_GATE`/`ARRIVAL_FROM_TOWN`
  are gone, and the farm scene's hand-placed "from_town" marker with them. The town's
  bridge to the Woods stays its own code: its zone and picture change with the unlock.
  `LocationManager.find(id)` added.
- *The Lane* (`lane.tres`, `scenes/lane.tscn`, `scripts/lane/`): 64 × 24, between the farm
  and the town (the farm gate now opens onto it). `LaneLayout` is a map function like the
  Woods': the lane two tiles wide end to end, a hedgerow each side (THICKET ground tiles,
  so solid) with gaps for what comes later (the allotments' path; Pip's and Dot's in
  session 2; the cliff path), the allotments north of the lane (fence and eight beds,
  drawn as tilled ground, for Stage 20's odd jobs), a stream near the farm end with a ford
  where the lane crosses, sparse trees, and a signpost at the top of the cliff path (E
  reads it: the path has slipped, someone will have to mend it; the Cove is Stage 21). It
  plays the farm's tune (the same stream, so it carries on from the farm). Tools are off;
  the rod finds no fish in the stream yet (`water_at` says none). A `Signpost` scene with
  its words on the scene is a small reusable interactable.
- *Hedgerows* reuse foraging (DECISIONS 052) unchanged: `lane.tres` has
  `forage_per_day = 6`, and the spots are the lane-side verges along both hedges.
  Primroses, wild garlic, elderflower, blackberries, hazelnuts and holly now have
  `found_in = [woods, lane]`; three new hedgerow-only kinds (wild raspberries in summer,
  sloes in autumn, rosehips in winter; tag `fruit`) give every season at least two.
- *The farm grows to 48 × 32.* The old farm (`FarmLayout.OLD_GROUND`, 30 × 20) keeps
  every cell where it was, so saves still line up; the new ground east and south starts
  overgrown. Each new tile rolls once (from the cell, so always the same) against
  `FarmLayout.DEBRIS_ODDS`: stones 10%, nettles 8%, brambles 8%, stumps 4%, trees 2%, about
  a third of the ground (about 300 pieces).
- *Debris is an object.* Stones, a stump, brambles and nettles are `ObjectDef`s with a new
  "Debris" group: `clears_to` and `clears_to_amount` (stone ×2, timber ×3, fibre ×1, fibre
  ×1), `clear_by_hand` and `hand_energy` (brambles 4, nettles 3). They stand on a tile as
  `object_id`, so they need nothing new in `FarmTile` or the save, block tilling and
  placing, and keep weeds off. Which tool clears what is on the tool: a new
  `ToolAction.clears` (ObjectDef ids) in each tool's `.tres` (the hoe: stones; the axe:
  stumps; the sickle: brambles and nettles), and those three actions ask `clears_at()`
  alongside their usual jobs. The swing costs what the tool's swing costs (the hoe's 2, the
  axe's 4); a wide tier clears a row. E pulls up brambles and nettles
  (`GameState.clear_by_hand`, before the interactables). `FarmData.clear_debris()` removes
  it and announces `object_removed` and a new `debris_cleared`; GameState puts what it
  gives in the bag. Trees on the new ground are ordinary trees and stay.
- *New item:* stone (sell 1g), for Stage 20's workbench.
- *v20 → v21*: the farm's tiles inside the old 30 × 20 and its west and north cliffs (with
  the gate) are kept; the old east and south cliffs are replaced by new ground and new
  cliffs ring 48 × 32. The sizes, odds and dice are frozen in the step (`V21_*`), today
  identical to `FarmLayout`'s, so an old farm's new ground is exactly a new game's.
  `tests/saves/v20_example.json` is the v19 example brought up by the real v20 build.

Options considered: debris as new terrain kinds (like THICKET): one per kind in the enum
and the tileset, and no picture standing up off the ground; debris as a new field on
`FarmTile`: a save change for something `object_id` already holds. Which tool clears what
on the debris (`ObjectDef.cleared_by` tool ids): a tool's action doesn't know its own id,
so it would have to be passed through every call; on the tool it sits beside the axe's
timber numbers and needs no change to the interface (rule 5). The ROADMAP's "stones, 4
energy": kept at the hoe's own swing cost (2), as about 300 pieces of debris are already
several days of energy; Stage 26 balances it. A bigger farm generated afresh for old
saves from today's `FarmLayout`: against rule 4 (a step must mean the same thing for
ever), hence the frozen copy.

**Why.** Dave's complaint (ROADMAP 13.1): nothing to do after 9 AM, and the farm and town
too close. Clearing is the energy sink spring was missing; the Lane puts distance and
something to pick on the way between home and the shops; exits as data make the Cove,
the coast road and the cliff path one `.tres` entry each.

**Cost.** Finds while clearing, the building size rule, and Pip's cottage and Dot's yard
are session 2. The Lane is placeholder (the hedge is the thicket tile, the allotment beds
the tilled tile). Placeholder sprites for the debris, stone, the three new forage icons
and the signpost are drawn by `art/build_stage19_placeholders.py` in the palette until
Pixellab (Stage 23). The stream doesn't fish yet. Travel times aren't measured yet
(session 2).

## 061 — Finds while clearing are data, buildings get a size rule, and homes are doors that talk

**Decision.** Stage 19 session 2 finishes the Lane and the bigger farm (ROADMAP 13.2, 13.3 #1,
13.5). Placeholder art. **Save version 22** (the finds).

- *Finds are a Resource.* A new `FindDef` (data/finds/): what it's `found_under` (debris
  ids, empty for any), its `chance`, how many `times` it can turn up, its `first_day` and
  `seasons`, what it says (`words`, and for one that turns up more than once, the next of
  its `pages` each time), what it `gives` (items), the unlock it earns (`gives_unlock`) and
  an object it leaves where it was dug up (`leaves_object`). When debris is cleared,
  `GameState` rolls the finds in file order, from the cell and the day (the same clearing
  on the same day always finds the same thing), the first to come up winning, and at most
  `GameRules.finds_per_day` (1) a day, so they come one at a time rather than in a heap on
  the first long day. `EventBus.found_while_clearing` tells the farm, which shows the words
  in a dialogue box (the farm scene now has one, as the town does).
- *The six finds:* five pages of the old farmer's notebook (from day 3; they hint at the
  axe head, the well and Stage 20's workbench), a rusty tool head (once, from day 2), an old
  seed tin each in spring, summer and autumn (potato, tomato, pumpkin seeds; twice each), and
  the cover of a buried well (once, from day 5, under stones or brambles), which leaves the
  old well standing there (an object whose E says something, like the Lane's signpost). A
  simulated spring of clearing 20 pieces a day turned up the tool head on day 2, the first
  page on day 3, a seed tin on day 4 and the well on day 9.
- *The rusty tool head is Brann's.* It earns `tool_head_found`, which a new request waits
  for: from day 8, Brann knows his father's mark on it and fits a new handle for 50 gold
  (`CommissionGoal`), giving the old farmer's axe. So clearing can pay for the tool that
  clears stumps. Someone who has bought Marlow's axe already gets a spare (he says so).
- *The building size rule* is in art/STYLE.md: a door opening at least 24 × 36 px in the
  middle of the bottom row, buildings about 1.5 × the old size, roofs 40–50% and varied.
  `Building` now handles a picture an even number of tiles wide: its two-tile doorway sits on
  the door cell and the one to its right, so a two-wide path leads straight in (an odd width
  is centred on the door cell, as before, so the farmhouse and the shops don't move).
  `Building.origin()`, `doorstep()` and `door_cells()` replace the sums the town and the farm
  each did for their doors' spawn points and doorsteps.
- *Homes are doors that talk.* Pip's family's cottage and Dot's yard are `LocationDef`s with
  their door on the Lane, like the shops on the town, but no `scene_path`: a new
  `door_words` says who lives there, and `LocationManager.closed_message` gives those words,
  so the door stays shut and stepping up to it says them. ContentDB allows a location with
  no scene only if it has an outside and door words. `LaneLayout` keeps their plots clear of
  trees and lays the paths from the hedge gaps to their doors; Dot's shed faces south like
  every building, so its path runs down beside it and round to the front. Her cart stands
  in the yard (an object whose E says something).
- *Travel time,* measured walking in the sandbox: the farmhouse door to the town square is
  20.8 real seconds, **40 game minutes** (ROADMAP 13.2 aimed at about 50). The town's
  growth to 48 wide (with the bakery and tavern) will add about 4. Left as it is: Stage 26
  looks at the clock's pace once everything is in.

Options considered: finds as a field on each debris `ObjectDef` (a list of what's under
stones): a find under several kinds would be written several times, and the once-only and
per-day rules would have nowhere to live. Finds rolled with the global dice: not
repeatable, so not testable, and a reload would re-roll. A home as its own kind of
resource (HomeDef): a second way of putting a building on a map, when `LocationDef`
already has the door, the picture and the outside; a home that later gets an inside only
needs its `scene_path`. Moving the existing shops and farmhouse to the new size now: their
art is real Pixellab art, and a placeholder at the new size would be a step back; they're
redrawn at the new size in Stage 23, when the town grows to fit them.

**Why.** ROADMAP 13.3 #1: clearing should now and then turn something up that tells the
farm's story and feeds requests. 13.5: the farmer is wider than today's doors; the rule
has to exist before any building art is made.

**Cost.** The notebook's pages can't be read again yet (Stage 20's workbench may give the
notebook a use). A find's "+N" items show on the HUD under the dialogue box. The old well
does nothing but talk; mending it could come later. Save version 22, so Stage 20's change
becomes 23 and later stages shift by one. `tests/saves/v21_example.json` is the v20 example
brought up by the real v21 build.

## 062 — Requests handed to someone else, by a time: Dot's errands and the allotments' odd jobs

**Decision.** Stage 20 session 1 (ROADMAP 13.3 #3 and #4) gives the early game two daily
uses of time and energy on the Lane. No save change.

- *A request can go to someone else, by a time.* `QuestDef.hand_in_to` names who takes it
  in when that isn't the giver (`receiver()`); `QuestDef.due_minute` is a time of day on its
  last day, and the Quests service checks it as the clock moves (`time_changed`), so it runs
  out there and then; `late_line` is added to "Out of time: …". Talking to someone first
  hands in anything ready for them (their own request or a parcel addressed to them:
  `ready_for`), and the "?" over them says so; the giver still asks nothing else while it's
  open. The request log says "Take it to Hollis".
- *Goals got three small hooks*, all no-ops by default: `on_taken` (a `CarryGoal` puts the
  parcel in the bag), `on_expired` (it takes it back), and `finishes_itself` (an
  `AllotmentGoal` is paid the moment its last tile is done, its words going to the HUD).
- *Two new kinds of order pattern* extend `OrderTemplate` (DECISIONS 050), so the dice by
  date, the ids, choosing, declining and clearing away each morning all carry on as before.
  Each makes its own goal (`make_goal`); the Quests service picks what each asks for
  (`_pick_deliveries`, `_pick_errands`, `_pick_job`). `always_up` puts a pattern up every day
  beside the place's others, and taking it leaves the others up. `choice_text` lets a
  pattern word its choices; the words gain {to}, {time} and {plot}.
- *Dot* is a CharacterDef living on the Lane, at her gate (46, 15). Day 1: a letter for the
  mayor (no deadline; 15g; opens `dot_errands`). Then `dot_errands.tres`: two errands a day,
  each a parcel, letter or flour sack (ItemDefs that sell for nothing, tag `parcel`) to a
  different person who's about, by noon, 2, 4 or 6 PM, paying 20–35g (by the difficulty) on
  delivery. A shopkeeper is only given a time at least an hour after their shop opens and
  no later than it shuts. An errand whose time has passed isn't offered.
- *The allotments' jobs* are pinned on a slate by their gate (`JobSlate`, at (19, 8), its
  id `Quests.ALLOTMENTS` like the board's). Three patterns, all `always_up`: weed a plot
  (4–8 weeds, 3g each + 8; not in winter), water a plot before noon (the bed, 3g a tile + 6;
  not in winter), dig over a plot (the bed, 5g a tile + 6). Each lands on a different bed
  (shuffled by the date). The `Allotments` service (a new autoload) knows which tiles the
  job in hand wants, which are done today (kept across scene changes, cleared each morning),
  and announces each one (`EventBus.allotment_worked`), which the goal counts.
  `AllotmentBeds` draws the beds as it says: weeds, a holder's crop on dry soil, a bed gone
  back to grass, watered or dug; each weed answers E (`AllotmentWeed`).
- *Tools on other people's ground.* `ToolAction.away_work` (hoe: weed and dig; can: water;
  sickle: weed) and a default `can_use_away`/`apply_away` that ask the place
  `work_wanted_at`/`do_work`; the axe and the rod still say for themselves. The Lane passes
  these to `Allotments`. Energy is the tool's swing, as in the Woods; E on a weed costs what
  a weed on the farm does.

Options considered: a FarmData for the allotment beds (the greenhouse's way, DECISIONS 057):
every tool would work unchanged, but so would planting your own seeds on someone's bed, the
night's growing and the summary's counts would go round it, and the farm's tilled/watered
signals would be counted as farm work. A separate jobs system with its own log: a second
request log, markers and expiry for something that is a request. Saving the beds' state:
nothing needs it, as everything is due the day it's taken and the game saves in the morning.

**Why.** Dave's complaint (ROADMAP 13.1): nothing to do after 9 AM, and the only early money
is crops. A spring day now has three paid jobs worth about 100g for their energy and a
parcel run across the map against the clock.

**Cost.** Placeholder art (Dot, the slate, the three parcels; `art/build_stage20_placeholders.py`).
Errands go to people, not yet to homes' doors (the ROADMAP's "each errand introduces a
home" waits for Stage 22's homes and schedules). The holders' "goodwill" (seeds or plots for
jobs done) isn't counted yet: it would be a save change. Job and errand pay is a first
guess for Stage 26's balance. Turning Dot down hides her errands for the day; the slate can
be read again any time.

## 063 — The workbench's plans are recipes, every buyer drops its price for plenty, and Mabel's bakery is a shop

**Decision.** Stage 20 session 2 (ROADMAP 13.3 #7, #8, #9) gives stone, timber and fibre a
use, makes where you sell matter, and lets gold buy energy from day 5. **Save version 23**
(the workbench on the farm, and plans for requests already done).

- *The workbench is a farm object.* `ObjectDef` `workbench` (scene `scenes/farm/workbench.tscn`,
  script `Workbench`) stands at (11, 11), against the farmhouse's east wall, faced from the
  path below; like the shipping bin it's in `FarmData`, answers E, and is never picked up.
  It starts **one leg short**: E with 3 stones (`GameRules.workbench_mend_item`/`_count`)
  props it level (`GameState.mend_workbench`), which earns `GameRules.workbench_unlock`
  (`workbench_mended`). So the first stones off the new ground have a use on day 1, and the
  old farmer's notebook ("once the workbench has a new leg") pays off.
- *A plan is a recipe.* `RecipeDef` gains `made_at` (`&"stove"` or `&"workbench"`,
  `RecipeDef.PLACES`), `item` (what a workbench plan makes; `product()` is the dish or the
  item) and `taught_by_unlock` (known as soon as that unlock is earned). Plans are kept in
  `GameState.recipes` with the dishes, so they're taught, saved and counted exactly like
  them; `known_recipes(place)` sorts them out, `cook()` checks the place is open
  (`can_make_at`: the kitchen, the bench) and emits `item_made` for a plan (the "chop" sound).
  The stove's `CookMenu` takes a `place` and becomes the workbench's "Plans you know" menu.
  A request's reward line says "the plans for a bird box".
- *Nine plans.* Mending the bench teaches the old farmer's three: fence ×2 (2 timber),
  hay bale (8 fibre), scarecrow (4 timber, 6 fibre). People teach the rest, as rewards on
  requests that already exist: Brann's test, stone wall ×2 (4 stone); Pip's strawberries,
  bird box (3 timber, 1 fibre); Ivy's first planting, flower bed (6 stone, any flower);
  Wren's worms, bait ×4 (2 fibre); Ivy's autumn basket, mulch (10 fibre); Ivy's timber, log
  pile (6 timber). Three new decorations (stone wall, bird box, log pile) are made only here.
  Nothing made at the bench makes goods for sale (DECISIONS 006 stands).
- *Every buyer drops its price for plenty* (`DemandDef`: `full_price_count`, `drop_per_extra`,
  `lowest_rate`). A buyer pays its full rate for the first so many of one item in a day,
  then each one after pays a little less, down to a floor; by morning it's back to full.
  Each buyer counts each item on its own. The bin: 40 at full, then 1% less each, floor 60%
  (`GameRules.bin_demand`; the bin's count is just what's in it). Marlow (80%): 20, 2%, 50%.
  Rosa (125%): 15, 3%, 60%. Mabel (110%): 6, 5%, 50%. Counter counts live in `Economy`
  (`bought_today`), cleared at `day_started`, a new game or a load; never saved, since the
  game saves in the morning. The shop menu says "(plenty today)" and what it'll pay
  tomorrow; the HUD says when the bin has had plenty of something.
- *Buyers can be choosy.* `ShopDef.buys_tags`: Mabel takes only `fruit` and `baking` (a new
  tag on honey and pumpkins). `Economy.shop_buys` asks it; the menu lists only what she'd take.
- *Mabel's bakery* is a shop like the others (`LocationDef` `bakery`, `ShopDef` `bakery`,
  the shared interior), 96 × 96 at the new building size with its two-cell door at (25, 12),
  in the gap between Marlow's and Brann's (the flower beds, lamp and tree that stood there
  went). Shut with a card in the window until `mabel_arrives` (spring day 5), then open
  7 AM – 2 PM. She sells four foods (dishes with a `buy_price`, `sold_only_by` the bakery):
  bread roll +20 (22g), cheese scone +30 (30g), fruit loaf +45 (42g), pasty +60 (55g). Food
  you cook stays the better deal; this is energy for gold before you can cook.
- *v22 → v23.* The workbench goes on (11, 11), or if that cell is dug, planted, built on or
  has something standing there, the first bare cell of a short list beside the farmhouse and
  bin, and failing those the bare cell of the old ground nearest it; nothing in an older game
  is moved or lost. It starts broken. A game that has finished one of the six requests is
  given its plan (`V23_TAUGHT_BY_DONE`, frozen). `tests/saves/v22_example.json` is the v21
  example brought up by the real v22 build, with a parsnip and a sprinkler put where the
  bench goes (so the upgrade has to look further) and Pip's strawberries done.

Options considered: a separate `PlanDef` beside `RecipeDef` (the ingredients, "any flower",
the known list, the menu and the save would all have been written twice); the bench inside a
new shed building (an interior scene and a building footprint on saved ground for one
object); recipes known from day 4 by the calendar (the ROADMAP's day 4; mending it with
stones gives the same timing to anyone who has cleared a little, and a reason to); a global
"market saturation" across all buyers (simpler, but then walking to a second buyer wouldn't
help, which is the point); counting the flood in gold rather than items (a pumpkin would
flood a buyer that eight radishes don't).

**Why.** ROADMAP 13.3: the early game's spare energy needs more uses, clearing needs to pay
in something besides space, and a big harvest should be worth a walk. The bakery turns gold
into energy before the kitchen, which makes gold and energy a real trade from week 1.

**Cost.** Placeholder art (the bench mended and broken, three decorations, the bakery, four
foods; `art/build_stage20_s2_placeholders.py`). Mabel is in the square and behind her counter
at once until Stage 22's schedules. The bakery's room is the shared shop interior. The
ROADMAP's crab pot (Stage 21, Tam), rain barrel, compost bin and path stones aren't plans yet.
Every price and every demand number is a first guess for Stage 26.

## 064 — The Cove: a place reached two ways, tides worked out from the clock, and rockpools that only the low tide uncovers

**Decision.** Stage 21 session 1 (ROADMAP 13.2 and 13.3 #5) opens the Cove from day 1, with
its tides, its beach and its rockpools. Tam, his handline, sea fishing, crab pots and sea
fish are session 2 (save version 24). Placeholder art. **No save change** (still 23).

- *The Cove* (`cove.tres`, `scenes/cove.tscn`, `scripts/cove/`): 56 × 36, west of the town.
  `CoveLayout` is a map function like the Lane's, with one more input: whether the tide is
  out. The coast road comes in from the east edge to the harbour; the quay (paved) has the
  old lighthouse, Tam's fish shed and the tide board on it, and the pier runs out into the
  harbour; a breakwater of rocks parts the harbour from a sandy beach; cliffs at the east
  end, with the cliff path cut through them up to the Lane. Below the beach's strand line
  is the shore the tide uncovers: wet sand, a rocky shelf full of pools under the cliffs,
  and a sand bar out to a little rocky islet. Rosa's cottage stands above the road. The
  three buildings are homes seen from outside (`door_words`, DECISIONS 061), at the new
  building size (placeholder: the lighthouse 64 × 128, the shed and the cottage 128 × 96).
- *Two ways in, both data* (DECISIONS 060): the town's road now leaves the west edge too
  (`town.tres`: the Cove), and the Lane's cliff path carries on past the signpost to the
  bottom edge (`lane.tres`: the Cove; `LaneLayout.CLIFF_PATH` is three rows longer). The
  signpost no longer says the path has slipped. So the map is the loop ROADMAP 13.2 drew:
  farm, Lane, town, Cove, and back up the cliff path.
- *Tides are worked out, not saved or rolled* (`Tides`, `TideRules` in
  `data/tide_rules.tres`): low water comes every 745 game minutes (12 h 25 min, the real
  sea's), counting from 10:20 AM on spring day 1, so twice a day and 50 minutes later each
  day; the tide is out for 90 minutes either side. Like market day and the day's forage, a
  save, a reload or a walk in and out can never put it wrong. A low tide after midnight
  belongs to the day it's in (the game's day ends at 2 AM). The tide is out about a
  quarter of the waking day.
- *The tide in the scene.* As the clock moves the Cove asks `Tides.is_out()`; when it
  changes, the tidal shore is redrawn (wet sand and rockpools, or sea, which is solid), the
  rockpools' forage is put out or taken back, and a line on the HUD says so ("The tide's
  going out. The rockpools are showing. The tide's out until 1:30 PM."). Anyone still out on
  the shore when it comes in is put back on the strand line above ("The tide's come in! You
  splash back up the beach."), so nobody is ever stranded. Walking in says what the tide is
  doing.
- *Sea forage is forage* (DECISIONS 052), with two small additions. `ForageDef.at_low_tide`
  marks what lives in the rockpools (shrimps, mussels, winkles, shore crabs, oysters):
  `Forage.spots_today(..., low_tide = true)` lays it on the pools with dice of its own and
  `LocationDef.low_tide_forage_per_day` of them (8 at the Cove), and the ordinary spots (the
  strand line, 5 a day: seashells, sea glass, seaweed, samphire in summer) never get it. The
  Woods' and the Lane's forage is laid out exactly as before (same dice, same kinds; checked
  for a whole year in three weathers). `ForageDef.gives` and `gives_count` let something be
  picked up as something else: driftwood, which washes up on the strand on stormy days,
  goes in the bag as 2 timber. What was picked stays picked all day, tide or no tide.
- *The day's low tides* are a page on the notice board ("Low tide at the Cove today: 12:00
  PM and 12:25 AM. The rockpools and the sand bar are uncovered for an hour and a half
  either side.") and a line in the morning summary; the harbour's tide board gives them
  and what the tide is doing now.
- *New ground tiles* in row 3 of the seasonal ground images, after the paving: sand, wet
  sand, rockpool, sea, pier planks, rocks (`GroundTiles.SAND` … `ROCKS`; the sea and the
  rocks are solid in all four tilesets). `art/build_ground.py` now keeps those columns.

Options considered: the tide saved and stepped by TimeSystem (a save change, and a reload
could disagree with the clock); a fixed low tide each day (no reason to come back at a
different hour, which is the point of 13.3 #5); tides as two calendar weathers (the tide
turns within a day, the weather doesn't). Rockpool spots as a second place id
(`&"cove_pools"` in `found_in`): a place that isn't a place, and it would need a
`LocationDef` of its own; a flag on the forage and a count on the place say it directly.
Flooding that blocks the player in on the islet until the next low: realistic, but six
hours stuck is no fun; wading ashore keeps the time cost without the trap. Driftwood "the
morning after a storm": yesterday's weather isn't kept, and keeping it is a save change for
one item; on the stormy day itself is close enough.

**Why.** ROADMAP 13.3 #5: a daily time window that moves, so where to be at what hour is a
choice, and the bigger map's far end has a reason to be visited at a particular time. It's
open from day 1 (Dave's decision, 13.7), so spring has a second place to gather from.

**Cost.** The Cove plays the town's tune and has no sound of the sea yet. Placeholder art
for the ground, the three buildings, the tide board and ten icons
(`art/build_stage21_placeholders.py`) until Stage 23. The pier doesn't fish and Tam isn't
there yet (session 2). Most of the map's bottom half is open sea until there's something to
fish it with. Storms only come in summer and autumn, so driftwood does too. Every sea forage
price is a first guess for Stage 26.

## 065 — Tam has a counter of his own, the handline is a rod for the sea, the tide sets the wait, and crab pots are kept by GameState

**Decision.** Stage 21 session 2 (ROADMAP 13.3 #5, #6, #8) brings Tam to the Cove, sea
fishing off the pier and crab pots. **Save version 24** (the pots). Placeholder art.

- *Tam is a person with a counter.* `CharacterDef.counter` (a `ShopDef` kept inside his
  .tres, id `tam_catch`) lets someone who stands outdoors buy and sell without a shop to
  walk into. The Cove builds him like any townsperson (`tam.tres`, `location` cove, from
  `tam_arrives`, spring day 7) and hands the conversation to `ShopCounter`, which now takes
  the giver's id and their lines: `serve(shop, giver, lines)`. So his requests, the "!" and
  "?" and the menu all work as a shopkeeper's do, and his requests are his
  (`giver = &"tam"`). He buys `fish` and `sea` (`buys_tags`) at 100%, paid now: the bin's
  price without the wait, so a walk to the Cove beats Marlow (80%) for the sea's things.
  15 of a kind at full price, 3% less each after, floor 50%. Dot's errands can be to him.
- *Three requests.* Tam's bait bucket (day 7): 3 rockpool finds, any mix → the handline.
  Tam's three from the sea (day 10): catch 3 fish in the sea → 50g, a crab pot and its
  plans. Crabs for the city: 3 brown crabs → 200g.
- *The handline is a rod limited to the sea.* `FishAction.waters` (empty: any water)
  makes it the same tool script with a different .tres: no new branch in Fishing. Wren's
  rod can fish the sea too. The fine rod's tier only shortens the wait when the rod is
  what's being cast (`Fishing.wait_factor` checks the held tool).
- *Where the sea can be fished.* `CoveLayout.water_at(cell, tide_out)`: sea next to the
  pier, the quay or the breakwater, so the line goes in from somewhere you'd stand. At high
  tide the covered wet sand beside the breakwater counts too.
- *The tide sets the wait, and a fish can wait for the tide.* `FishingRules.sea_waters`
  ([&"sea"]) never freezes, and its wait is ×0.7 with the tide in and ×1.4 with it out
  (`tide_wait_multiplier`), worked out from `Tides` like everything else about the tide.
  `FishDef.only_at_high_tide` (the bass); `FishDef.bites` and `ContentDB.fish_biting` take
  `tide_in`, defaulting to true so fresh water is unchanged.
- *Eleven sea fish*, one .tres each, chosen so every season has several and the evenings
  have their own (whiting, the conger eel after dark).
- *Crab pots.* A pot is a `ToolDef` used like a seed (`consumed_on_use`), with a new
  `SetPotAction` that asks the place `pot_wanted_at`/`set_pot` (rule 5: the tool never
  knows where the pier is). Pots go in the sea either side or off the end of the pier
  (`CoveLayout.pot_cells`, 22 cells, never on the tidal shore). Once set a pot is
  GameState's (`crab_pots`: location → cell → the day baited, 0 if not), because it stays
  put for good and has to be saved; `CrabPot` nodes only draw it, redrawn on
  `EventBus.crab_pot_changed`. E on a pot: hauls it if it has had its night (2 energy),
  else baits it, else says it's fishing, else (empty, nothing to bait it with) it comes back
  up into the bag. Hauling baits it again from the bag. `CrabPotRules`
  (`data/crab_pot_rules.tres`, on `GameRules.crab_pots`): the bait in the order it's used
  (winkles, Wren's bait, mussels, shrimps), a day to fill, the catch by weight (shore crab
  10, brown crab 8, lobster 2) and a 20% chance of a second. The catch is rolled from the
  cell and the day it was baited, so a reload can't reroll it.
- *v23 → v24.* `crab_pots: []`. Nobody had a pot before Tam. `tests/saves/v23_example.json`
  is the v22 example brought up by the real v23 build.

Options considered: Tam as a market-stall keeper (a `ShopDef` id as his giver, as Brann
is): his requests and his line of the day would have lived on a shop, and a stall needs a
picture and an event; a `counter` on a person keeps him a person. A separate handline
`ToolAction` (a second copy of the cast). Crab pots as `ObjectDef`s on a plot (the Cove has
no `FarmData`, and giving it one for 22 cells would be a far bigger change than a small
dictionary). Rolling the catch at dawn and storing it (a save field for what is only ever
a function of the day). Bait as any item with a "crab_bait" tag (a list in the rules says
the order it's used in, which a tag can't).

**Why.** ROADMAP 13.3: the Cove needs something to do at high tide as well as low (the
pier), a small daily round (the pots), and a buyer that makes the walk pay (Tam).

**Cost.** Placeholder art (Tam, eleven fish, the handline, the pot and its floats, two
crabs; `art/build_stage21_s2_placeholders.py`). Tam is on the quay day and night until
Stage 22's schedules. A pot can't be moved except by emptying it with no bait in the bag.
Every price, weight and wait is a first guess for Stage 26.

## 066 — The music is the season's: Dave's own tunes, two a season, taking turns everywhere

**Decision.** Dave composed eight pieces, two for each season, to replace the generated
tunes from DECISIONS 042 (farm, town, woods). A side task between Stage 21 and Stage 22.
**No save change.**

- *The season owns the music.* `SeasonTheme.music` (an `Array[AudioStream]`) lists the
  season's tunes, and `SeasonTheme.music_volume_db` how loud they play. Every place plays
  them: the farm, the Lane, the town, the Cove, the Woods and every room inside. So walking
  from the farm to the Cove carries on with the same tune, and the turn of the season
  cross-fades to the new season's.
- *A place can still have its own.* `LocationDef.music` stays: a place (or its outside)
  with a tune of its own plays that instead, looping, all year round. That is for
  somewhere that should sound different, like Stage 22's tavern. The five outdoor places'
  `music` entries were emptied, so nothing uses `farm.ogg`, `town.ogg` or `woods.ogg` any
  more (still in `assets/audio/music/`; Dave can delete them, and `art/build_sounds.py`
  still writes them).
- *Taking turns.* `Audio` keeps the list for here and now and picks the next tune at
  random from all but the one that played last, so with two tunes they alternate and the
  same one never plays twice running; with three or more the order varies. Three seconds
  before a tune's end the next one starts and the two cross-fade
  (`TRACK_CROSSFADE_SECONDS`), because Dave's tunes end at full volume and a hard stop
  then silence would be noticeable. A tune playing that is in the new place's list
  carries on where it is, so doors never restart the music.
- *The files.* MP3 as Dave made them (192 kbps, 44.1 kHz, 90–150 s each). Godot 4 imports
  MP3 directly, so nothing was converted; the import leaves `loop` off, which is what lets
  `Audio` notice the end and change tune. Renamed to `<season>_<title>.mp3` without the
  timestamps: spring `spring_harvest_path`, `spring_harvest_meadow`; summer
  `summer_fields`, `summer_harvest_path`; autumn `autumn_acres`, `autumn_harvest_hush`;
  winter `winter_farm_loop`, `winter_harvest_loop`.
- *Which is which.* Six names say their season. "Harvest Path" and "Harvest Meadow" were
  made together, before the summer pair, so they are spring; "Harvest Hush" was made with
  "Autumn Acres", so it is autumn. A guess from the timestamps: moving a tune is one line in
  a season's .tres.
- *Loudness.* The new tunes measure about −12 to −17 LUFS, the old ones −24 to −26, and the
  sound effects were balanced against the old. Each season's `music_volume_db` is −10 dB,
  which puts them back where the old music sat (on top of the Music bus's −4 dB).

Options considered: keeping music per place and giving each place a season → tune table
(eight tunes don't divide into five places, and Dave asked for the music by season);
putting the playlist in `game_rules.tres` keyed by season id (the season's look, weather
and now its sound all live on its `SeasonTheme`, so one file says what a season is);
converting to Ogg Vorbis like the old music (no need: MP3 imports, and Dave's files stay
as he made them); normalising the files' loudness (changes his files; a number in data is
easier to adjust by ear); a strict alternation (random-but-not-the-last is the same with
two tunes and still varies with more).

**Why.** Dave's own music, in by season, and room to add more: a new piece is a file and
one more entry in that season's list, never a code change.

**Cost.** −10 dB is set by measurement, not by ear; Dave may want it a little up or down.
The old generated tunes and their import files are left on disk unused.

## 067 — People keep a schedule: where they are is worked out from the clock, and on the map you're on they walk

**Decision.** Stage 22 session 1 (ROADMAP 13.4, 13.3 #11). Stage 22 was split in two:
session 1 the machinery (weekdays, schedules, walking, knocking, the request log saying
where people are), session 2 the content that uses it (Nell's tavern, the three new
people's questlines, homes in a larger town). **No save change.**

- *Weekdays.* Spring day 1 of year 1 is a Monday and the days run on from there
  (`Schedules.weekday`, from `GameState.day_number`). With 28-day seasons every season
  starts on a Monday, and market day (every 7 days from day 3) is always a Wednesday. The
  HUD's date says "Spring · Wed 3 · Year 1", the morning message "Wednesday, day 3".
- *A schedule is data.* `CharacterDef.schedule` is a `ScheduleDef` (data/schedules/): a
  home and a list of `DayPlan`s, each for some weekdays, seasons and weathers, with its
  `ScheduleStop`s (from a time, a place and a cell, and words for the request log). The
  first plan that fits today is used, so a rainy-day plan goes before the everyday one.
  A stop's place is an outdoor map (they stand on the cell), a building (indoors: behind
  a shop counter, or at home), or empty (away: the mayor's evenings until his house is
  built in session 2). Someone without a schedule stands on their `spots` as before.
- *Worked out, not simulated.* `Schedules.stop_at(person, minute)` is a pure function of
  the date, weekday, season, weather and clock, like market day and the tides. Nothing is
  saved and nobody is moved about off-screen: arriving anywhere, everyone who should be
  there is already standing in place. A festival's host is at the festival all day, as
  before.
- *Walking where you are.* `PeopleHere` (scripts/people/), one per outdoor map with
  people (the town, the Lane, the Cove), asks every ten game minutes where everyone
  should be. Someone whose stop moved walks there along an `AStarGrid2D` path (2.5 tiles
  a second, `GameRules.people_walk_speed`); someone leaving walks to the road that leads
  towards their next place (a breadth-first walk over every LocationDef's exits) or to
  the door of the building they're going into, and is gone; someone arriving comes in
  along the road or out of the door. Which cells can be walked is found by asking the
  physics world whether a pair of feet fits on each cell, so trees, fences, walls, water
  and the tide are all avoided with no list of them, and a new map needs only the node.
  While walking an Npc doesn't block the farmer (nobody gets stuck in a doorway) and can
  still be talked to. No walk cycles yet (Stage 24): the picture bobs and turns.
- *Talking moved with them.* The town, the Lane and the Cove each had their own way of
  answering their people; now `PeopleHere` does it the same way everywhere: a festival
  host about the festival, a counter of their own (Tam), requests, orders (Dot's errands),
  or the day's line. The scenes keep what's theirs: the board and the stalls in town, the
  allotment slate on the Lane.
- *Knocking.* Walking up to the door of a home with no inside while someone who lives
  there is in (`EventBus.door_knocked`) brings them to the door to talk, so being at home
  doesn't hide anyone: Pip on a rainy day, Dot after six, Tam in his shed (with his
  counter). Nobody in: the door's own words, as before.
- *Shops with a keeper who walks about.* `ShopDef.keeper_id` names the keeper's
  CharacterDef (Mabel): the counter asks and takes her requests, and her schedule has
  her indoors there while it's open. That ends Mabel standing in the square and behind
  the counter at once (DECISIONS 063's known gap).
- *Errands fit the day.* Dot's errands to someone with a schedule are only due by a time
  they can be found all through the hour before (not the mayor at 6 PM on a Sunday, when
  he goes home at 4; not Mabel after the bakery shuts).
- *The request log says where.* Under each request: "Pip is playing by the ford on the
  Lane until 7 PM, then at home in Pip's cottage on the Lane (knock)."
- *The first schedules.* Mayor (fountain, the square; Sunday short), Mabel (bakery till
  2, then the garden and the square; Sunday on the beach), Pip (town till 3 then the
  ford; weekends the ford and the beach; indoors in rain), Wren (the pond; Saturday off
  the pier), Ivy (the glasshouse), Dot (her gate; Wednesday the market; Sunday short),
  Tam (the quay; Sunday short). Wren, Ivy and the mayor are "away" at night until session
  2 gives them homes.

Options considered: simulating everyone all the time (they'd need saving, and a person
could get stuck somewhere unseen); one schedule list with conditions on each stop
(harder to read than "Pip's weekend"); hand-listing each map's walkable cells (a second
copy of what the colliders already say, wrong as soon as a tree moves); navigation
meshes (more set-up than a tile grid needs); a new autoload for schedules (there's no
state to keep, so static functions).

**Why.** People being *somewhere* gives the bigger map a reason: a route to plan, a
reason to come back at the right time, and Stage 22 session 2's tavern evenings and
Stage 24's walk cycles both need it.

**Cost.** Only the map you're on is lively; arriving mid-walk shows someone already at
their next spot. The walkable grid is rebuilt (a couple of thousand small physics
queries) whenever someone sets off, at most once a game minute. Wren, Ivy and the mayor
have no home to knock at yet.

## 068 — Nell's tavern: a room of its own, a chalkboard that caps what she buys, true rumours about tomorrow, darts on Fridays; homes for everyone in a bigger town

**Decision.** Stage 22 session 2 (ROADMAP 13.3 #10, #11). **No save change** (still v24).

- *The town grows to 48 × 32.* The new ground is south and east of the old map (Back
  Street along the bottom, a lane down to it past the square, a path up to Wren's), so no
  old cell, door or stop moved. The Lane's exit cells and the town's arrival point were
  moved to the new east edge.
- *The Wheatsheaf is a room, not a shop counter.* Its LocationDef points at
  scenes/tavern.tscn (scripts/town/tavern.gd), built in code like the shops' rooms: the
  bar, barrels, fire, three tables, the chalkboard and the dartboard on the back wall
  (`TavernFixture`: face it and press E, like the notice board). Nell keeps it like
  Mabel keeps the bakery (`ShopDef.keeper_id`), talked to across the bar: her requests
  first, then tonight's rumour, then the menu. Everyone else in the room is there by
  their schedule (a stop at `&"tavern"` with a cell in the room) and `PeopleHere` runs
  indoors too: in and out by the door, with the keeper left out. It opens on day 8
  (`tavern_opens`), 4 PM to 1 AM.
- *The chalkboard caps what Nell buys.* `ShopDef.chalkboard`: such a shop buys only
  today's three things (`Tavern.wanted_today`, chosen by dice seeded with the day from
  `TavernRules.chalkboard_items`, only what's in season), and only five of each
  (`Economy.sellable_amount`). Her rate is 1.5, so it's a better price for a little of
  the right thing: a reason to look at the board, not a second bin. The town's notice
  board says what's on it.
- *Rumours are true, and about tomorrow.* Worked out from what the game already knows:
  the forecast (`GameState.forecast`), tomorrow's low tides, what bites or grows
  tomorrow, tomorrow's chalkboard; which kind rotates by the day, and the words are
  templates in data/tavern_rules.tres. A rumour you can act on is worth a walk to the
  tavern; a made-up one would teach you to ignore Nell.
- *Darts is a small game of skill, once a night.* Fridays from 7 PM: three darts, each
  aimed in two presses (stop the sweep across, then up and down), scored by ring.
  Tonight's best is a regular's (named from who's in the room at 7) with a score from
  dice seeded by the day, so it's the same however often you look. Beat it and the pot
  (120g) is yours. The `Tavern` autoload keeps only "played tonight, and what you
  scored", not saved (the game saves in the morning; reloading starts the day again).
  Every number is in `TavernRules`.
- *Hot meals are dishes sold only there* (`sold_only_by`): a ploughman's from the start,
  the hotpot and the fish supper taught by Nell's requests (unlocks on the dishes).
- *Requests.* Nell four, Dot three (one of them a parcel to the tavern before it opens, so
  you meet Nell in her day), Tam two; Dot's errands can now be to Nell.
- *Homes for everyone.* The mayor's house and the town hall on Back Street, Wren's cottage
  by the river in town (not in the Woods: it uses the town's exits and people as they
  are), Ivy's cottage by the allotments on the Lane. All are LocationDefs with
  `door_words` and no inside: knocking brings out whoever's in (DECISIONS 067). The
  mayor's weekday middays are at the town hall, so knocking there finds him.
- *Evening plans wait for the tavern.* `DayPlan.requires_unlock`: a plan whose unlock
  isn't open is skipped and the next that fits is used, so each tavern evening has an
  ordinary evening after it for the first week. `Schedules.todays_plan` does the
  choosing (`ScheduleDef.plan_for` is no longer used).
- *Walking door to door.* `PeopleHere` now also shows someone who leaves one building for
  another on the same map (the mayor from his house to the tavern), and indoors walks
  people to and from the room's door.

Options considered: the tavern as a counter on its front like the bakery (no room for
people to be in of an evening, or for darts); Nell buying anything, like Marlow (a third
place to dump the harvest); random rumours (not worth listening to); darts as a dice roll
(no reason to play it yourself); saving the darts night (nothing else in an evening is
saved, and you can't save mid-evening).

**Why.** ROADMAP 13 wants evenings to have somewhere to go and people to be found there;
the chalkboard and rumours give a short daily reason to visit, darts a weekly one.

**Cost.** Placeholder art for the tavern, the new homes, the furniture, Nell and the
dishes (art/build_stage22_s2_placeholders.py) until Stage 23. The regulars don't play
darts themselves; their score is only a number.

## 069 — Every building redrawn at the new size; the shop row and the farmhouse plot make room, and winter roofs come from one script

**Decision.** Stage 23 session 1 (ROADMAP 13.5): real Pixellab art for all sixteen
buildings, at the size rule's sizes (art/STYLE.md), and the maps changed where the
bigger ones didn't fit. **Save version 25** (the farm's buildings stand on more cells).

- *How the art was made.* Pixflux, the STYLE.md prompt template, `color_image` =
  art/palette.png (so every picture is on the 41 colours), `init_image` = the picture it
  replaces, two seeds each, the better kept. Dave picked the light take (strength 80) from
  a look test: it keeps each placeholder's shape, door and roof and adds real texture.
  The five old pictures (farmhouse, greenhouse, three shops) were scaled up first and run
  at 150; the general store, the forge and the seed shop came back with flat roofs, so
  they were redone from a scaled-up front with a hipped roof drawn on by script (strength
  100). Sizes: farmhouse 128 × 112, the three shops 128 × 112, the greenhouse (and its
  ruin) 80 × 64; the rest keep the sizes their placeholders already had (tavern 160 × 128,
  town hall and mayor's house 128 × 112, Pip's, Dot's, Tam's and Rosa's 128 × 96, the
  bakery, Wren's and Ivy's 96 × 96, the lighthouse 64 × 128). Garbled sign text on the
  bakery was painted out.
- *Winter roofs from one rule* (art/build_winter_roofs.py) instead of a hand-made mask per
  building: a roof's colours are the ones found (almost) only in the top part of the
  picture, so windows, doors and walls keep theirs; the roof's main colour and brighter
  become snow white, darker shades pale blue, the outline the snow's shadow blue. Each
  building has its `_winter.png` in winter.tres's `object_sprites`, keyed by location id,
  which `Building` already looked up (DECISIONS 034).
- *The town's shop row* at the new size: the seed shop's door moves to (6, 12), the
  general store's to (15, 12), the bakery's to (23, 12), the forge stays at (31, 12), so
  they stand at x 3-10, 12-19, 21-26 and 28-35 with a one-cell gap between each (a lamp, an
  open way up to the old glasshouse, a flower bed). The forge covers the pond's old south
  bank, so the pond is two rows deep (31-36, rows 2-3) and its bank is rows 4-5, reached
  from the pond path, which moves a cell east (x 36-37) to join the bridge path. Wren's
  pond stop and the fishing contest (host, flags, sign) move onto the new bank; Ivy's
  glasshouse stops move to its sides. One tree that would be inside the general store goes.
- *The farmhouse plot.* The farmhouse is 128 × 112 on the same door cell (8, 11): its
  doorway is now cells 8 and 9 (even width, DECISIONS 061), and it stands on x 5-12, rows
  5-11, two rows into the north field (the field's buildable ground shrinks by 16 cells;
  thicket only grows on grass, so nothing else changes). The greenhouse grows up a row (x
  0-4, rows 8-11). The workbench moves from (11, 11), now inside the house, to (13, 11),
  against the new east wall above the bin; the two trees that stood inside go.
- *Save version 25* does for old games what version 18 did for the greenhouse: the new
  cells become BUILDING terrain, and whatever was on them goes back in the bag (a crop as
  its seeds, a tree as its sapling, a sprinkler, hive or decoration as itself; a crop
  reaching in from outside goes too); the workbench moves to the first bare cell by the
  new east wall. The areas and the list of things that go back are written into the step.
  `tests/saves/v24_example.json` is a new game saved by the Stage 22 build, with a crop,
  an apple tree, a sprinkler, a hive, a scarecrow and weeds put where the new buildings
  stand: loaded now, each is given back and the workbench is at (13, 11).

Options considered: keeping the farmhouse at 80 × 64 (it would stay smaller than Pip's
cottage, and the farmer still wouldn't fit its door); moving it onto the new ground (the
player's start, the path, the bin and the doorstep would all move, and everything Dave
knows about his farm with them); a smaller footprint than the picture, so the roof could
overhang the field without taking it (crops would be hidden under the roof and could only
be reached from behind it). Moving the forge off the pond instead of shrinking the pond:
there's no other room on the north side of the road without moving every shop. Winter
masks drawn by hand per building (sixteen masks to keep in step with the art).

**Why.** ROADMAP 13.5 and the size rule (DECISIONS 061): the farmer has to fit the doors,
roofs should slope and vary, and every building is redrawn, not only the new ones.

**Cost.** Stage 25's save version becomes 26. The north field is 16 cells smaller. The
roofs' snow is a recolour, so it follows the roof's tile pattern rather than lying in
drifts. The tavern's, the seed shop's and the general store's signs are Pixellab's own
(the tavern's says "Inn").

## 070 — The Cove's ground from the terrain tool; the backlog's small pictures four to a strip

**Decision.** Stage 23 session 2: real Pixellab art for the Cove's six ground tiles and for
162 placeholder pictures from Stages 12 to 22. No save change, no data change; one code
change, the sea's mirroring.

- *The Cove's ground.* Pixellab's terrain tool (`/create-tileset`, standard, 16 px), one
  terrain pair per tile (sand on grass, wet sand on sand, the rock shelf and the rocks on
  wet sand, the sea on wet sand, the pier on the sea), keeping only the plain tile of the
  wanted terrain. The tool can't take a palette, so each tile is mapped onto two or three
  palette shades by brightness rank (DECISIONS 032's method), and the rockpool shelf,
  which has real colours (grey, teal, weed green), onto the nearest of seven. The first
  rock shelf had no pools, so it was redone with the pools named. The same six tiles go
  in all four seasons' ground images, as the placeholders did. Sources are kept in
  art/ground_sources/cove/.
- *The sea is mirrored at random* (`GroundTiles.transform_for`), like the grass is turned,
  so its crests don't line up into a grid; only mirrored, never turned, so they stay
  level. The pond and the cliffs are still drawn as they are.
- *The Lane* needed no tiles of its own: it draws with the farm's real grass, path,
  thicket (its hedges), stream and cliff tiles.
- *Small pictures* (icons, 16 × 16): pixflux, the STYLE.md template, palette as
  `color_image`, four to a 64 × 16 strip with the four placeholders as `init_image`
  (strength 150), as Stage 8's icons were; pixflux can't make anything under 1024 px.
  Strays that crossed into a neighbour's cell are cleared by script.
- *Bigger pieces* (furniture, debris, signs, poles, people): pixflux, one each, the
  placeholder centred on a canvas of at least 32 × 32 (strength 100; people 150), cut back
  to the placeholder's size, so every picture keeps its size and where it stands. People
  are shifted so their feet are on the old row. Grass tufts pixflux drew at the foot of a
  few standing things (barrels, tide board, bird box, hive, well, lantern) were removed.
- Two seeds each (7 and 21), the better kept; where neither beat the placeholder (the
  sprinklers, the sickle, the float, aphids, the broken bridge, the contest sign, the
  ruined glasshouse, the Woods footbridge) the placeholder stays for session 3.

Options considered: Pixellab's tiles-pro tool for the Cove (Stage 6 found it draws a grid
at every tile edge); pixflux strips for the ground (Stage 6: flat single colours);
transition tiles between sand and grass (a Wang tileset needs autotiling code in every
map, for a small gain; the hard edges match the rest of the game). One picture per call
for the icons (four times the calls, and icons drawn together match each other better).

**Why.** ROADMAP 13.5: the world's art. The Cove was the last place still drawn with flat
placeholder ground, and the backlog's pictures were recoloured shapes.

**Cost.** About 400 generations (two takes of everything, a few redone), about $1.30 of
Pixellab credit. Every picture is open to Dave's eye: any can be redone in session 3.

## 071 — The backlog's last pictures, and Stage 24's portraits and panels made early

**Decision.** Stage 23 session 3 (2026-11-19, art only, recorded afterwards in session 4):
the growth sheets of the 17 Stage 12 crops, the giants and the apple tree, drawn as one
pixflux strip per crop with the placeholder as `init_image` (eight takes each, the best
kept; frame 0, the planted seed, is the parsnip's on every crop); the sprinklers (the
placeholder's spray copied back on), the field deed, the float, the sickle, aphids, the
contest sign and Ivy's ruined glasshouse (the farm's ruin shrunk, so the two match).
The broken bridge, the Woods footbridge, the soil overlays and the greenhouse floor stay
as they are: no take beat them. Stage 24's pictures were made while the art tools were
warm: 13 portraits (`assets/sprites/portraits/<sprite>.png`, three 64 × 64 busts:
neutral, happy, worried; neutral from each person's sprite at strength 50–70, the faces
by Pixen edits) and the UI nine-patches (`assets/ui/`). Nothing uses those yet.

**Why.** ROADMAP 13.5. No code, data or save change; every picture keeps its size.

## 072 — Soft ground edges: a display-only dual grid, grounds in height order, one set each

**Decision.** Stage 23 session 4 (ROADMAP section 14). Every outdoor map (the farm, the
Lane, the town, the Cove, the Woods) gets a `GroundEdges` node just above its Ground
layer, which draws the ground a second time so that where two kinds meet the join is soft.
No save change, no rule change: the Ground layer still holds one plain tile per cell and
still gives the water, sea and cliffs their collision.

- *Dual grid.* GroundEdges' layers sit half a tile up and left, so each picture tile's
  middle is a corner where four cells meet, and it's chosen from what those four cells
  are. Sixteen pictures per ground cover every mix of four corners (a "mask": 1 top-left,
  2 top-right, 4 bottom-left, 8 bottom-right), which is exactly the 4 × 4 set Pixellab's
  terrain tool returns.
- *Height order, one set per ground.* `GroundTiles.EDGE_GROUNDS` lists twelve grounds
  lowest first: sea, pond water, wet sand, the rock shelf, sand, path, paving, tilled,
  wet tilled, grass, rocks, thicket. At each corner the lowest ground there is drawn whole;
  every higher one is drawn over it with its edge picture on its own layer, counting as
  present wherever the cell is it or anything higher (so higher grounds always sit on a
  bed of lower ones). So grass needs one set (grass over anything), not one per pair.
  The cliffs and the pier keep square edges: they count as highest and are drawn again,
  square, on a top layer.
- *It reads the Ground layer's pictures, not the game's state.* `GroundTiles.draw()` tells
  GroundEdges (through a meta on the layer) which cell changed, and it looks at the tile
  drawn there. That breaks no architecture rule 1 (it only decides how other pictures
  look) and means no map's drawing code changed: the hoe, a field going back to grass,
  the tide, the allotment beds and the Woods' logs all redraw their edges for free. Marked
  corners are redrawn once at the end of the frame.
- *The edge pictures* are a second source (id 1) in each season's ground tileset:
  `assets/tilesets/edges_<season>.png`, made by `art/build_ground_edges.py`: one row per
  ground and variant (two variants), one column per mask, and a row of scatter pieces
  (tufts and flowers cut from the grass details, two stones). Every edge is the ground's
  own plain tile cut to a shape with a darker rim, so it joins the plain tiles in every
  season. **Grass's shape is real Pixellab art** (the terrain tool, "short lush green
  meadow grass" over "dirt path", transition 0.25, seed 7, picked from four takes; kept
  in `art/ground_sources/edges/grass_over_path.png`): its ragged dark lip and the shadow it
  throws are kept and coloured with our own grass and path. The other eleven sets are
  placeholders: a line bent by tileable sine waves through a blend of the four corners,
  until session 5 makes them with Pixellab once Dave likes the look.
- *Scatter.* About a third of the corners on a join (not water, sea or tilled soil) get a
  tuft, a flower or a stone on their own layer, mirrored at random. Never saved.
- *Outlines.* The Cove's beach is made less ruled as data in CoveLayout (grass bites into
  the sand's top row, sand spills into the grass, dry sand steps into the shore's top row,
  extra wet sand and sea notches along the low tide's edge) and the Lane's stream wanders
  like the Woods' (STREAM_BENDS), straight where it meets the hedges and the ford. The
  strand line, the rockpools, the crab-pot spots, the sea's fishing spots and the hedgerow
  forage are unchanged (compared cell by cell). The farm's pond (its cells are saved in
  FarmData) and the town's pond (fishing and the contest) keep their cells; their corners
  round off anyway.

Options considered: Godot's own terrain sets ("match corners" autotiling on the Ground
layer: one set per PAIR of grounds, the editor's peering bits for every tile, and collision
and pictures tangled in one layer); a set per pair of grounds (dozens of sets instead of
twelve); a shader blending the grounds (soft, but blurry rather than pixel art, and a new
technique for one look). Making all twelve sets with Pixellab now (the plan says to show
Dave one first: if he wants the grass different, the rest would be redone).

**Why.** ROADMAP section 14: Dave asked for Stardew-like organic joins instead of square
tile edges.

**Cost.** Four Pixellab terrain sets (the look test), well under $0.10.

## 073 — Every soft edge from Pixellab, read against one shared outline; a pond bank; animated foam

**Decision.** Stage 23 session 5 (ROADMAP section 14), after Dave approved session 4's
grass-over-path look (2026-11-19). The eleven placeholder edge sets are replaced by
Pixellab's, grass over pond water gets a bank, and the sea gets foam. No save change, no
rule change.

- *One terrain set per ground.* Pixellab's terrain tool (`/create-tileset`, standard,
  16 px, transition 0.25, view high top-down, **seed 7** like grass) made a set for each
  ground over the one it usually meets: pond water over sea, wet sand over sea, rock shelf
  over wet sand, dry sand over wet sand, path over sand, paving over path, tilled soil over
  path, wet tilled over dry tilled, boulders over sand, hedge over grass, and grass over
  pond water with a "sandy pond bank with small grey pebbles" between. Seeds 7 and 21 were
  both made; 7 was better in nearly every pair (21 often drew a plain upper tile, so no
  edge at all). The sources are kept in `art/ground_sources/edges/<ground>.png`, sixteen
  tiles side by side by mask.
- *The shared outline.* With one seed, Pixellab draws the **same outline** for every pair;
  only the band along it differs (a dark rim, a lighter lip, a wet darkening outside,
  foam, a sandy bank). We checked this by measuring every set against the wet-sand one.
  So the outline is kept once (`shape.png`, white = upper ground) and each ground's set is
  read pixel by pixel against it: Pixellab's own colours of the upper ground become our
  plain tile's pixel; band pixels become one of our tile's main colours or its rim colour,
  whichever sits as far in brightness from our tile as the band sits from Pixellab's (so
  winter's snow gets a snow-coloured band, and a berry never becomes a whole band); a dark
  band just outside becomes a see-through shadow, a light one a see-through lightening,
  so they suit whatever lower ground they fall on. Grass keeps session 4's own set.
- *Why not two variants from two seeds.* Every edge picture must meet its neighbours where
  the outline crosses a tile side, and two seeds cross at different places. So both
  variant rows of a ground hold the same pictures for now (the layout keeps the rows, so
  a matching second set can go in later without code).
- *The pond bank.* Grass over pond water would otherwise show grass's lip hanging over
  water. It gets its own two rows (`GroundTiles.BANK_ROW`, rows 25–26), picked when the
  lowest ground at the corner is pond water (`edge_tile()` is now told the lowest ground).
  The bank is told apart by hue (green = grass, blue-green = water, the rest = bank) and
  coloured from the season's sand tile. One special pair, not a set per pair: the height
  order stays.
- *Foam.* A layer of its own in GroundEdges, straight after the sea's, so whatever lies on
  the sea covers its inner half. Where the lowest ground at a corner is the sea, the foam
  picture for the corners that aren't sea is drawn (`GroundTiles.foam_tile()`, rows 27–30).
  The pictures are worked out from the shared outline: a white ring with a pale fringe
  1, 2, 3, then 2 pixels out on the water, four frames the tileset animates (0.35 s each),
  so it runs up the beach and back. It follows the tide by itself, since the tide redraws
  the cells. Wet sand's own static foam line is dropped in favour of it.
- *Not done.* The cliffs keep their square tops (they're drawn square on a top layer;
  softening only their lip would need a cliff-top set drawn under them and wasn't worth a
  new layer yet). The sea has no edge set of its own (it's the lowest ground, so nothing
  ever needs one). Edge scatter keeps session 4's pieces (cut from the Pixellab grass and
  path details already).

Options considered: reading each set's own shape by colour alone (failed where the two
grounds share colours: path over sand, wet over dry tilled, the rock shelf over wet sand
came out speckled); keeping Pixellab's colours as drawn (off our palette, and wrong in
every season but spring); a set per season from Pixen (four times the sets, and the
outline would drift between seasons, so the seasons wouldn't line up); foam from pixflux
strips (wouldn't follow our outline exactly).

**Why.** ROADMAP section 14; Dave liked session 4's grass edge and asked for the rest the
same way.

**Cost.** 23 Pixellab terrain sets (22 + one test), about $0.16 of credit ($4.92 left).

## 074 — A pixel font and a Theme; portraits with moods; eight facings that fall back to four

**Decision.** Stage 24 session 1 (2026-11-19, code; no save change).

- *Fonts and a Theme.* `assets/ui/theme.tres` is the project's theme (Project Settings →
  GUI → Theme → Custom), so every Label, Button and PanelContainer picks it up: monogram
  (CC0) at 16 for all text, Pixelify Sans (OFL) at 13 for headings, Stage 23's wooden
  nine-patch for panels and its buttons for menu rows (a row is plain ink until picked or
  hovered, then sits on the orange button, so the keyboard's place in a list is obvious).
  Fonts are imported with antialiasing, hinting and subpixel positioning off. Their licences
  are beside them (assets/fonts/), and the credits screen (Stage 26) will name them.
- *Sizes.* monogram is only pixel-exact at 16 (one font pixel to one game pixel), so every
  size the code asked for below 12 (the old default font's 8, 9 and 10) becomes 16, and 12
  and over (titles) becomes a heading. The old sizes stay in the code as "what this text
  is"; `UiStyle.font_size()` makes the choice in one place.
- *Ink on paper.* The panel is cream, so text on a panel is dark ink with no outline
  (`UiStyle.style_panel_label`), and text on the world (HUD, hotbar, floating numbers, the
  "!" over heads) stays light with a dark outline (`style_label`). Both take the same colour
  names (TEXT, TEXT_DIM, GOLD, WARNING); `UiStyle.ink()` swaps each for its ink (GOLD
  becomes a dark blue accent, WARNING a brick red), so screens still say what a line is.
- *Four characters added to monogram.* It has no middle dot, en or em dash or times sign,
  which the game's text uses. A fallback font fixed the glyphs but made every line taller
  (Godot sizes a line for the tallest font in the chain), so art/fonts/extend_monogram.py
  draws the four in monogram's own grid and writes assets/fonts/monogram.ttf; the original
  is kept in art/fonts/ (ignored by Godot).
- *Portraits.* `CharacterDef.portrait` and `ShopDef.keeper_portrait` point at the strips in
  assets/sprites/portraits/ (three 64 × 64 busts: neutral, happy, worried). `DialogueBox.say()`
  and `ask()` take the portrait and a mood; the box shows a framed bust in its left margin.
  The mood comes from what's happening (`Quests.mood_for()`: happy when a request is handed
  in, worried when one of theirs is due today or late; happy when you take an order or at a
  festival; worried at a closed shop), or a line can set its own face with a leading tag,
  `"[worried] The nets are torn again."`, stripped before it's shown. A few existing lines
  are tagged. No portrait (notice board, slate, chalkboard): no frame.
- *Eight facings.* `Facing` (scripts/people/facing.gd) picks one of eight from a direction,
  and the animation `walk_down_right` if the SpriteFrames has it, else the straight facing's
  (`walk_down`) chosen by the old rule. So nothing looks different until eight-way sheets
  arrive, and they can arrive one character at a time. The farmer's tools and E always act
  on the cell straight ahead (the straight facing), so no tool rule changed.
- *Walk cycles for people.* `CharacterDef.walk_frames` (a SpriteFrames named like the
  farmer's) makes an `Npc` an AnimatedSprite2D that walks and idles facing the way it went;
  without one it's the still picture, bobbing, as before. PeopleHere's paths now cut corners
  on open ground (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`: only where both side cells are open,
  so nobody clips a wall or slips diagonally into a door).

Options considered: a Theme per screen (four places to change instead of one); a fallback
font for the missing characters (taller lines everywhere); keeping light text on a dark
panel (the nine-patch Dave approved is cream); moods chosen only by code (no way for a line
in a .tres to look worried) or only by tags (every hand-in line would need one); eight-way
facing for tools (a hoe on a corner cell would change every tool's rules).

**Why.** ROADMAP 13.5 (font, theme, portraits) and section 15 (eight-way characters): the
code half of Stage 24, so the two art sessions only make pictures and SpriteFrames.

## 075 — Eight-way walk sheets from Pixellab's character tool, one layout for everyone

**Decision.** Stage 24 art (2026-11-19, cloud; no save change, no code change).

- *One sheet layout.* Every walker's sheet is the farmer's, grown to 448 × 504: 56 × 56
  cells, row 0 the eight standing pictures (down, left, right, up, then down-right,
  down-left, up-right, up-left), rows 1-8 eight-frame walks in that same order. Each
  SpriteFrames names them `idle_<facing>` (1 frame, speed 2) and `walk_<facing>` (8 frames,
  speed 10), exactly as player_frames.tres always has, so Facing and Npc need nothing new.
  The farmer keeps his file names (farmer.png, player_frames.tres) and his four straight
  rows unchanged; everyone else gets `<id>_walk.png` and `<id>_frames.tres` beside their
  still picture.
- *How they're drawn.* Pixellab's v3 character tool turns each person's existing front
  picture into eight views (the farmer: his four existing views given, the four diagonals
  drawn), then its walking template animates each view (eight frames). Every diagonal is
  drawn, not mirrored, because most people aren't symmetrical (Dot's satchel, Ivy's scarf).
- *Tidied by script.* Each direction is shifted so the feet sit on the same line as the
  still picture and it's centred in the cell, and stray specks under 20 pixels (a ground
  line the tool sometimes draws under the boots) are removed. Three things were redone: Mabel
  first came out holding a rolling pin (a new character with "empty hands" in the words), the
  child's walking-down came out a size larger (redrawn), and the angler's walking-up kept
  drawing a ground line under his boots (taken off by script, row by row).
- *Who uses them.* The eight people with a CharacterDef get `walk_frames`. The five keepers
  only ever behind a counter (Marlow, the grocer, the seed merchant, the seed shop, the
  smith) have sheets made in the same pass for when they step out; ShopDef has no
  walk_frames, so nothing changes for them yet.

Options considered: mirroring the left diagonals (cheaper, but swaps which side bags and
scarves are on); one sprite sheet per direction (eight files a person instead of one);
regenerating the farmer's straight rows too (Dave already likes them).

**Why.** STAGES.md Stage 24 sessions 2-3 and ROADMAP section 15: the art half of eight-way
characters, landing on DECISIONS 074's fallback so each sheet just switches on.

## 076 — A test of calmer ground from a bought asset pack, behind a switch, kept out of git

**Decision.** A side test on 2026-11-20, not a stage (no save change, no rule change). Dave
found our ground tiles busy (lots of speckle and in-between shades) and bought the "Cozy
Village & Farm" 16 px pack (flat colours, clean outlines, its own palette). Its ground is
fitted into our ground system as a second look that can be switched on and off; nothing
else (buildings, people, props, our edge code's rules) changes.

- *Same layout, so no code knows.* `art/build_cozy_ground.py <pack folder>` starts from our
  own ground pictures for each season and puts the pack's tiles in our places (GroundTiles):
  grass, flowery grass, the grass and path details, the path, tilled and watered soil, the
  pond (ice in winter), paving (the pack's stone path), sand, wet sand (the pack's sand a
  step darker) and the sea (the pack's deep water). The rock shelf, the rocks, the hedges,
  the cliffs and the pier keep ours (the pack has none like them).
- *The edges come from the pack's corner autotiles.* They are the same idea as our dual
  grid (16 tiles by which corners are the upper ground; the pack numbers its corners TL TR
  BL BR, we use 1 2 4 8), so each is read straight into our edge rows: grass from its grass
  over dirt (grass pixels only; the shadow it throws becomes our see-through shadow, so it
  suits any lower ground), the pond bank from grass over water (winter: snow over ice),
  paving from stone path over grass, sand from sand over water with its pale surf line
  becoming our foam (still, not animated: the pack's animated sheet only ripples the
  water), pond over sea from its water over deep water. Path, tilled and watered soil have
  no pack sheet, so they take grass's outline filled with their own tile and a dark rim.
  The edge scatter row is left empty: fewer bits is the point.
- *A switch.* Each season's cozy tileset (`assets/tilesets/cozy/ground_tileset_<season>.tres`)
  is a copy of ours pointing at the cozy pictures, so it swaps in exactly like a season.
  `SeasonLook.cozy_ground` (on by default) picks it when the folder exists, and **Ctrl+G**
  flips it while playing (GroundEdges catches the key, so it works on every outdoor map).
  With it off, or the folder gone, the game is pixel for pixel what it was (checked by
  rendering every test view both ways). Reverting for good: delete `assets/tilesets/cozy/`;
  the switch code can stay or go.
- *Licence: kept out of git.* The pack may be used in the game but not passed on as files,
  and the GitHub repository is public, so `assets/tilesets/cozy/` is in `.gitignore`. The
  build script holds no pack art and is committed; anyone with the pack can rebuild.
  If Dave keeps the look, before any release we decide between making the repository
  private or keeping the pictures out of it (a build step from the pack on his PC).
- *Palette: the pack's colours are kept exactly.* None of its 46 colours is in
  `art/palette.png` (all 41 of ours differ), and recolouring the pack to ours would bring
  back the busier shades the test is meant to judge. So for the test the checker is
  expected to list them as off-palette. If Dave keeps the look, the palette is rebuilt from
  the art as DECISIONS 015 says (it will then hold both sets while the rest of the art
  catches up).

Options considered: Godot's own terrain autotiling with the pack's sheets (a second system
beside GroundEdges, one set per pair of grounds); recolouring the pack onto our palette;
swapping our .png files in place (no quick way back, and the pack's pictures would land in
the public repository).

**Why.** Dave's request (2026-11-20): compare the Lane, town and farm with a calmer ground.

**Credit.** Not added: the pack asks none; Dave may credit (and donate to) the author if he
keeps it, and then it goes in the credits (Stage 26) and a README.

## 077 — The cozy pack's ground is kept; the palette grows to 74; the pictures stay out of git

**Decision.** Dave tried DECISIONS 076's test on 2026-11-20 and said "keep". So:

- *The cozy ground is the game's ground.* `SeasonLook.cozy_ground` stays on by default.
  The old ground pictures and tilesets stay where they are, because the game falls back to
  them whenever `assets/tilesets/cozy/` is missing (a fresh copy from GitHub). **Ctrl+G stays
  as a debug switch**: it only changes which pictures the ground layers show, never the
  game's state or the save, and does nothing without the cozy folder, so it is harmless. It
  can go at release (Stage 26) along with the old ground pictures if nobody needs them.
- *The palette* (`art/palette.png`) is rebuilt as DECISIONS 015 says: our 41 colours, then
  the 33 pack colours the ground uses (74; 128 × 160, darkest first in the new rows). The
  checker now accepts the ground. New art should lean on the pack's colours.
- *The pictures stay out of git* while the GitHub repository is public (the pack's licence
  allows using them in the game, not sharing the files). `art/build_cozy_ground.py` rebuilds
  them from the pack on Dave's PC. Before release, either the repository goes private (then
  the folder can come out of `.gitignore` and be committed) or the release build is made on
  Dave's PC, where the folder exists. Keep a copy of the pack's zip somewhere safe: it is
  the only source.
- *Credit.* `CREDITS.md` (new, at the top of the project) names the pack, the fonts and the music; the pack asks no credit,
  but Dave wants to give it. The pack's files don't name the author, so the name comes from
  the store page it was bought from (left for Dave to fill in).
- *Not yet.* The pack's props (fences, the stone wall, the well, stalls, lamps, benches) are
  a later, separate step. Its buildings are not planned: ours are bigger with sloped roofs.

**Why.** Dave's verdict on the test, 2026-11-20.

## 078 — A test of calmer cliffs and calmer paving, behind Ctrl+K; three more packs looked at

**Decision.** A second side test on 2026-11-20, over the cozy ground DECISIONS 077 kept (no
save change, no rule change, collision unchanged). Dave found the cliffs "a big jar" and the
paving outside Tam's shed (the quay) too busy. Both are swapped for calmer pictures, as a
look that can be switched on and off.

- *The cliffs become raised ground.* Ours were one speckled dark-grey tile, repeated: a hard
  band round every map and a dark block in the Cove. The Cozy Village & Farm pack draws a
  cliff as a grassy top (snowy in winter) with a dark outline where it stops and a brown
  earth face along its south side (`01_Terrain/Cliffs/cliffs_<season>.png`). GroundEdges
  already redraws "square" ground (cliff, pier) on its own layer on the game's grid; with
  the test's tileset it now draws each cliff cell from a row of sixteen pictures, chosen
  by which of its four sides open onto something that isn't cliff (1 north, 2 east, 4
  south, 8 west; `GroundTiles.cliff_tile`). South open gives the face; a cliff two cells or
  more deep gets a face two tiles high (a second row: the face's upper half, for the cell
  just above the foot). Beyond the map's edge counts as cliff, so a border shows no edge
  on its outer side. The Ground layer underneath still holds the plain CLIFF tile and its
  collision, so walking, the save and every map's code are untouched.
- *The paving becomes flagstones.* The pack's stone path is small bright cobbles. The calm
  paving is big 16 × 8 slabs in two of the pack's greys, a half slab apart, no highlights;
  its soft edge takes grass's outline (as the path's does) rimmed in the seam colour.
  Paving is also the town square, so the square changes too (the same tile: one look).
- *Where it lives.* `art/build_calm_test.py <CozyVillageFarm folder>` (run after
  `build_cozy_ground.py`) writes `assets/tilesets/cozy/calm_ground_<season>.png`,
  `calm_edges_<season>.png` (two more rows at the bottom: 31 and 32) and
  `calm_tileset_<season>.tres`. Same folder, so still git-ignored (licence, public repo).
- *The switch.* `SeasonLook.calm_test` (on by default when the files exist) picks the calm
  tileset over the cozy one; **Ctrl+K** flips it in the game (GroundEdges, like Ctrl+G). A
  tileset without the cliff rows draws cliffs square as before, so with it off the game is
  exactly the kept cozy look. `follow_tileset()` now re-marks every cell so the cliffs
  redraw when the tileset changes. Reverting: delete the `calm_*` files.

Also looked at (no art used yet): three more packs by the same author, Michel Clauwaert —
Coast, Beach & Fishing; Seasons & Festivals; Game UI Kit. Same 16 px grid and style; their
58-colour palette is the cozy pack's 46 plus 12 (25 of the 58 are not yet in
`art/palette.png`). Same licence: use in the game, never pass the files on (the UI kit
says so for its fonts too), so anything taken from them is git-ignored like the cozy
ground. The pack's sea cliff (grey stone) was tried on paper and not used: its face is
as speckled as ours. The findings and recommendations went to Dave for choosing.

Options considered: Godot's own terrain autotiling for the cliffs; the Coast pack's stone
quay tiles or its boardwalk for the quay (both still busy); the dirt path for the quay.

**Why.** Dave's request, 2026-11-20: the cliffs and the path outside the fisherman's hut
are too busy; keep everything on one theme.


## 079 — E forgives a near miss: the tile ahead first, then the nearest tile around

**Decision.** E (interact) still tries the tile straight ahead first, exactly as before. If
nothing there answers, it now reaches for the tiles around the farmer: the eight
neighbours and the tile under their feet, leaving out the three behind them. They are
tried nearest first to a point 12 px in front of the feet, in the way the farmer faces,
using all eight facings (so facing down-right reaches the corner tile first, and what's
in front beats what's beside). Two tiles away is never reached.

- *What a near miss reaches.* Every interactable (forage and driftwood, rockpools, crab
  pots, people walking or standing, keepers behind a counter or stall, the tavern's
  fixtures, the notice board, the job slate, signposts, the bin, the bed, the stove, the
  workbench, allotment weeds), and a ready crop by hand on the farm, in the greenhouse and
  on an allotment.
- *What it doesn't.* A placed object (sprinkler, decoration, hive) only answers E on the
  tile ahead, because E picks it up; the one exception is a hive with honey waiting, as E
  collects that. It says so with an optional `aim_exactly()` on the interactable
  (PlacedObject has it; nothing else needs one). Pulling weeds and clearing brambles by
  hand cost energy, so they also stay on the tile ahead. Tools (hoe, can, seeds, axe, rod,
  sickle…) are unchanged: tile-exact.
- *Walking people.* An Npc's talk cell already follows it as it walks; the near miss means
  catching someone as they pass no longer needs them exactly in front.
- *Knocking* is stepping onto a door's zone (ExitZone), not E, so it's unchanged; the
  person who comes to the door is then talked to with the forgiving E.
- Where: `Player._interact()` and `_reach_cells()` (scripts/player.gd),
  `PlacedObject.aim_exactly()`. No save change: nothing new is saved.

Options considered: bigger `occupies()` areas on each interactable (many files, and every
new thing would need to remember it); a physics Area2D in front of the farmer (another
moving part, and harder to make prefer the nearest); a plain distance radius around the
farmer ignoring facing (would talk to someone behind you).

**Why.** Dave, 2026-11-20: picking up forage and talking to people needs you in exactly
the right position.


## 080 — The calm cliffs and flagstones are kept; a test of a proper harbour in the Cove, behind Ctrl+H

**Decision.** Dave, 2026-11-20, chose from the report on DECISIONS 078: keep the calm cliffs
and flagstones (Ctrl+K stays as a debug switch, like Ctrl+G), and try the Coast, Beach &
Fishing pack's harbour in the Cove. A third side test over the calm look (no save change, no
rule change, collision unchanged):

- *The quay stands in the sea.* Every sea cell just south of paving shows the pack's stone
  quay wall (four animated frames, the water lapping at it), with its left and right ends
  where the paving stops, and a ladder now and then (picked by cell, so it never moves).
- *The pier stands on posts.* Pier cells are drawn from the pack's wooden deck set, chosen by
  which sides open onto something that isn't pier (as the cliffs are: 1 N, 2 E, 4 S, 8 W),
  and the sea cell south of the pier's end shows its posts in the water (left, middle,
  right, single).
- *The breakwater and the rock shelf.* Rocks wear the pack's breakwater top, with its foot
  in the water below; the rock shelf is the same stone, its light strokes softened, with
  a small dark pool, so a whole shelf of them stays calm. Both keep a soft edge (grass's
  outline filled with the stone, rimmed dark).
- *How.* `art/build_harbour_test.py <CoastBeachFishing folder>` (after the calm test's
  script) writes `assets/tilesets/cozy/harbour_ground_/harbour_edges_/harbour_tileset_<season>`:
  the calm pictures plus row 33 (pier deck by open sides) and rows 34-37 (the fronts:
  `GroundTiles.Front`, four frames down, 6 fps). GroundEdges draws the fronts on a layer of
  their own ("HarbourFront") on the game's grid; the Ground layer and its collision are
  untouched. `SeasonLook.harbour_test` picks the harbour tileset over the calm one;
  **Ctrl+H** flips it. Without the files, or with it off, the game is exactly the calm look.
  Still git-ignored (licence, public repo).

**Why.** Dave's picks, 2026-11-20: the calm look stays; the Cove should read as a harbour.


## 081 — A test of the packs' props, festival dressing and a wooden UI, behind Ctrl+P and Ctrl+U

**Decision.** The rest of Dave's picks from DECISIONS 078's report, as one more side test
(no save change, no rule change, nothing new to walk into):

- *Props.* Our bench, lamp post, old well, hay bale, log pile, notice board, scarecrow, bee
  hive and cart wear the Cozy Village & Farm pack's pictures; fences (wood), the garden fence
  (white) and the stone wall wear its 4-bit sets, each piece picked from its neighbours of
  the same kind (index N*8 + E*4 + S*2 + W*1), so rows join up and corners turn, and a
  neighbour taken away (on the farm) re-picks. `SeasonLook.skin_object` asks
  `PackLook.texture_for()` and keeps the bottom edge where ours was. Buildings, trees,
  people and crops stay ours.
- *Harbour clutter* in the Cove from the Coast pack: bollards and rope posts along the quay's
  edge, dock lamps, a life-ring post, crates, a barrel, a net rack, a fish-drying rack
  (animated), a net pile, a rope coil, an anchor, and two bobbing buoys.
- *Festival dressing* in town from the Seasons & Festivals pack, only on its day: the flower
  show (pastel bunting over the square, a maypole, a flower arch, flower barrels, a spring
  banner); the fishing contest (rainbow bunting by the pond, kites, a beach umbrella, a
  picnic blanket, a cooler, a lemonade stand); the harvest fair (harvest bunting, a pumpkin
  booth, a banner, corn bundles, a hay stack, pumpkins, a cider barrel, a wheelbarrow of
  pumpkins); lantern night (a lantern string, a lit tree, double lantern posts, paper
  luminaria, a winter banner); market day (a fair banner, a balloon cart, a popcorn cart,
  flag poles; these stand aside when a festival shares the day). Bunting and lantern
  strings are drawn over people, as the pack says.
- *Wooden UI* from the Game UI Kit: the panel (every panel: menus, the dialogue box, the
  day's summary, shops), the buttons' hover/focus/pressed pictures, the hotbar's slots and
  the portrait frame. Our fonts (monogram, Pixelify Sans) and ink colours stay. The
  portrait frame became a nine-patch so the kit's 54 px frame fits ours.
- *How.* `art/build_pack_look.py <cozy> <coast> <seasons> <ui>` copies the chosen pictures
  into `assets/packs/` with `pack_look.json` (what goes where); `scripts/pack_look.gd`
  (PackLook) reads it. Pieces are only looks: no collision, never saved. `assets/packs/` is
  git-ignored like the cozy ground (licence, public repo).
- *The switches.* `PackLook.props_on` and `PackLook.ui_on`, on by default when the folder
  exists. **Ctrl+P** flips props and dressing, **Ctrl+U** the wooden UI (outdoors, where
  GroundEdges listens). Without the folder the game is exactly as before.

Options considered: the packs' buildings and characters (smaller and flatter than ours;
not asked for); the UI kit's fonts (Dave asked to keep ours); putting the dressing in each
CalendarEvent's `decorations` (those are ObjectDefs with their own scenes, and would put
pack art into tracked data files).

**Why.** Dave's picks, 2026-11-20: the harbour props, festival dressing, the Wood UI keeping
our fonts, and the cozy pack's props, each as a switchable, git-ignored test.

## 082 — Dave's scenery: a scene per map that he fills by dragging pictures in the editor

**Decision.** Each outdoor map has a scenery scene, `scenery/<map>.tscn` (farm, town, Lane,
Woods, Cove; the greenhouse may have one too), that Dave opens in the Godot editor and fills
by dragging pictures from the FileSystem dock. The map loads it when it opens. It's
decoration only: nothing is saved (no save change), no rule reads it, and a missing or
broken scene leaves the map as it was.

- *The scene.* Its root is a `SceneryLayer` (@tool) with four groups: `OnTheGround` (flat,
  always under the farmer), `Standing` (sorted by their feet with the farmer and everyone
  else), `Solid` (the same, but the farmer bumps into a small block at each picture's foot)
  and `Overhead` (over everyone, z 20 like PackLook's bunting). A picture dropped on the
  root counts as Standing. In the editor the root shows the map behind the pictures (the
  backdrop, an internal child, so it's never saved and can't be picked), draws the map's
  edge, moves each new picture's origin to its feet without moving it on screen (people
  and things sort by their feet), and shows the first frame of a strip.
- *The loader.* `Scenery.add_to(map, entities, id)`, one line at the end of each map's
  `_ready()`. Standing and Solid are moved into the map's y-sorted `Entities` with y-sort on,
  so their pictures sort among the people (a y-sorted node in a y-sorted node merges into
  its sort). OnTheGround goes just before Entities. A picture named `..._4f.png` is played
  as 4 frames side by side (`..._pingpong_3f` goes there and back; two-frame pictures sway
  slowly); `..._on_off_2f` (string lights) is lit from 19:30 to 06:30; a name with a season
  in it (`oak_summer.png`) turns into this season's picture when one is beside it.
- *The backdrop.* **Ctrl+B** in the game, only when run from the editor, photographs the whole
  map you're on (a second viewport sharing the world, the ground's used rectangle at 1:1,
  with the farmer, the day's light, the weather and the scenery hidden) into
  `scenery/backdrops/<map>.png` and its top-left corner into `<map>.json`. The maps are
  drawn by code, so without it the editor would show an empty grey page.
- *The pictures.* `art/build_scenery_library.py <cozy> <coast> <seasons>` copies the packs'
  single pictures into `assets/scenery/` by kind (nature, props, harbour, seaside,
  creatures, festival; 571 pictures), takes frame sizes out of the names, and cuts the
  joining 4-bit sheets into stand-alone pieces (fence and wall runs and posts, bunting and
  string-light spans). Ground tiles, buildings, characters, items, UI and the animals'
  many-row sheets are left out. Our own pictures in `assets/sprites/` can be dragged too.
- *Git.* `assets/scenery/` and `scenery/backdrops/` are git-ignored (the packs' licence; the
  repository is public). The scenes, `scenery/*.tscn`, are kept in git: they hold only where
  each picture goes and its file's name, no pictures. On a copy without the library a scene
  with pack pictures in it doesn't load and the map is as before (a warning in the output).

Options considered: placing scenery from a data file of cells and picture names (like
PackLook's pieces; exact, but Dave would be typing coordinates, not placing things);
editing the map scenes themselves (they're mostly built by code at run time, so there's
nothing to see, and a slip could break a map); a painting tool inside the game (much more
code to build for the same result). Solid things block only the farmer: townsfolk walk
through scenery, so a Solid picture on a path won't trap anyone, but it could block the
farmer's way to a door or an exit, which is why Solid is a group Dave chooses and not the
default.

**Why.** Dave (2026-11-20) wants to dress the world himself, dragging the packs' props in
with the mouse, without touching code or saves.

**Kept, 2026-11-21.** Dave: "happy with them" (the scenery layer and the furnished homes,
084).

## 083 — A test of furnished rooms from the Cozy Interiors pack, behind Ctrl+R

**Decision.** Dave liked DECISIONS 079–081 ("happy with all of the changes", 2026-11-21)
and sent the same author's **Cozy Interiors & Town Life** pack (v1.0) to fill the shops
and houses. As before, a side test that changes only looks: no save change, no rule
change, nothing new to do.

- *Which rooms.* The ones you can walk into: the four shops (which until now shared one
  bare room), the farmhouse and the Wheatsheaf. The greenhouse keeps its own look. The
  townsfolk's homes have no rooms yet (they are LocationDefs with door_words), so there is
  nothing to furnish there; making them enterable would be new rooms, a separate step.
- *Each shop its own.* Hollis: warm planks, sacks, barrels of produce, herbs drying.
  Marlow: plaster and birch, crates, a fabric shelf, a coat on a stand. Mabel: cream
  wallpaper, terracotta tiles, the bakery oven (animated), bread counters, a menu board.
  Brann: stone walls and flags, the forge (animated), grindstone, quench barrel, tool
  racks, torches. The farmhouse: log walls, the pack's bed, a nightstand, a kitchen corner
  either side of our stove, a grandfather clock and a sleeping cat. The tavern: the bar
  with taps and mugs, a bottle shelf and keg rack, two tapped barrels, the stone fireplace
  (animated), the three tables set with mugs, a pie, bread and a candle, stools, lanterns
  and a grey cat asleep by the fire. Windows show their night picture after 7 PM.
- *How.* `art/build_interior_look.py <CozyInteriors>` bakes one picture per room (the
  pack's 2-tile wall faces across the back, its 47-piece wall tops round the edge, floor,
  rugs, door mats, stools) and copies the standing pieces with `interior_look.json` into
  `assets/packs/interiors/` (git-ignored with the rest of `assets/packs/`).
  `scripts/interior_look.gd` (InteriorLook) is called with one line at the end of each
  room's setup (interior.gd, farmhouse.gd, tavern.gd): it lays the picture over our tiles,
  stands the pieces among the people (y-sorted), and hides our own sprites that a pack piece
  stands in for (counter, shelves, bed, table, bar, tables, barrels, fireplace). Those keep
  their collision and what E does, so the keeper, the bed, the stove, the chalkboard and
  the dartboard all work as before. A few new pieces along the walls are solid (barrels,
  plants, shelves); none is where anyone stands or walks, the tavern's schedule cells
  included.
- *Safe if rooms change.* The room sizes and doors are written into the build script; if a
  room no longer matches, InteriorLook leaves it as ours (with a warning) rather than
  showing a wrong picture.
- *The switch.* `InteriorLook.on`, on by default when the folder exists. **Ctrl+R** in a
  room flips it. Without the folder the rooms are exactly as before.
- *Palette.* Every picture keeps the pack's colours exactly (the same 55-colour palette as
  the other packs); the build script checks that and lists the 14 not yet in
  `art/palette.png`. If Dave keeps it, the palette is rebuilt with them (DECISIONS 015, 077).

Not used: the pack's people and pets' walk sheets (ours stay; only two sleeping cats),
its doors and stairs (our doors are gaps in the bottom wall), its decorating and cooking
UI, and its 47-blob rugs (the fixed rugs are enough). Options considered: swapping
interior.png's five tiles (the pack's walls are two tiles tall and its tops a 47-piece
set, so they don't fit one tile each); a TileMapLayer per room built at runtime (more
moving parts for rooms that never change shape while you're in them).

**Why.** Dave's ask, 2026-11-21: "interiors from the same set so we can fill out the shops
and houses".

**Kept, 2026-11-21.** Dave: "happy with all of the additions". `InteriorLook.on` stays on
by default and **Ctrl+R** stays as a debug switch, like Ctrl+G and Ctrl+K. `art/palette.png`
gains the 14 colours (74 to 88, 128 × 176, darkest first in the new rows), so the
checker accepts the rooms. The pictures stay out of git with the other packs'.

## 084 — The townsfolk's homes become rooms you can go into, furnished from the Cozy Interiors pack

**Decision.** Dave liked the furnished shops, farmhouse and tavern (DECISIONS 083, kept)
and asked for the townsfolk's houses next (2026-11-21: "Townsfolk houses decorate now
please"). Until now the homes were pictures with a door that only spoke (`door_words`,
DECISIONS 061) or brought whoever was in to the door (knocking, DECISIONS 067). Seven of
them now have an inside. No save change, no new rules, nothing new to do.

- *Which.* The seven homes: the mayor's house and Wren's cottage in town, Pip's family's
  cottage, Ivy's cottage and Dot's yard on the Lane, Tam's fish shed and Rosa's cottage in
  the Cove. Left as they were: the town hall (an office, with its own hours on the door)
  and the lighthouse (padlocked).
- *One room for all.* `scenes/home.tscn` with `scripts/town/home.gd`, as the four shops
  share `interior.tscn`. Each home's LocationDef now names it (`scene_path`) and says its
  shape: `room_size`, `room_door_x` (the left of the door's two cells) and `resident_cell`
  (where whoever lives there stands). A new home is data, never code.
- *Who's in.* The room adds a PeopleHere for itself, as the Wheatsheaf does (DECISIONS
  068), so a person's schedule decides it: someone at home stands at the home's resting
  spot and talks as they do outside (requests, Tam's counter, their line for the day);
  someone whose day takes them out walks to the door and goes; someone coming home comes
  in at the door and walks to their spot. PeopleHere gained one optional argument for
  this, the resting spot, used for a stop that is plain "at home" (no cell of its own).
- *Visiting hours.* A home's door is open from 8 AM to 8 PM (`open_from`, `open_until` on
  the LocationDef, in minutes; -1 means never shut, as for the farmhouse). Out of hours it
  behaves exactly as before: shut, knocking brings whoever's in to the door, and with
  nobody in it says its `door_words`. You can stay inside past 8 PM; it just won't let
  you back in. Options considered: always open (walking into a sleeping house at 1 AM
  felt wrong), and open only while someone's in (Rosa is never home, being no
  CharacterDef, so hers could never be seen, and doors would open and shut as people come
  and go).
- *What makes each one theirs.* `art/build_interior_look.py` gains seven rooms, built the
  same way as 083's into `assets/packs/interiors/` (git-ignored). The mayor: red damask,
  parquet, a marble fireplace with armchairs either side, a tall bookcase, a grandfather
  clock, a globe, his writing desk, his own portrait, a piano. Wren: log planks, a stove,
  fish drying on a rack, his rods in a rack, a mounted fish, a barrel of the catch. Pip's
  family: yellow paper, the family kitchen, mum's bed, Pip's bunk and toy chest, a sea
  picture for a would-be pirate, a hamster in its wheel, the dog asleep. Ivy: mint
  stripes, plants everywhere, a spinning wheel, tea for two, a canary, herbs drying, a
  white cat. Dot: parcels and sacks, the packing bench, her round pinned on a board, a
  coat by the door, an unmade bed, her old dog. Tam: harbour boards, fish on the shelf and
  in barrels, a hammock, the chart table, a ship's lantern. Rosa: whitewash and
  terracotta, a grocer's kitchen, barrels of veg, geraniums under the windows, a black cat
  by the stove. Windows go dark after 7 PM, as in 083.
- *Solid pieces.* A piece can now be solid more than one row deep (`depth`, read by
  InteriorLook), so nobody walks over the far end of a bed or a desk. Every room keeps a
  clear way from the door to its resting spot.
- *Without the pack* (a copy of the repository, which is public) a home is a plain room
  with our interior tiles: everything still works, it just isn't furnished.
- *Palette.* Two more of the pack's colours are used (#5a2f6e, #f2c29b); `art/palette.png`
  grows from 88 to 90 (a twelfth row, 128 × 192).

**A snag found in testing.** The room scene was first copied from the shops' room, which
puts the farmer at a spot that, in a room ten cells wide, is on the doormat: physics saw
them there for a moment and the door sent them straight back out. `home.gd` now places the
farmer before it lays the door, and the scene's own spot for them is well inside.

**Why.** Dave's ask, 2026-11-21. The homes were the last buildings you could only look at.

**Kept, 2026-11-21.** Dave: "happy with them". The doors' hours stay 8 AM to 8 PM.

## 085 — The almanac, the mayor's year review and a second year (Stage 25)

**Decision.** Stage 25 as ROADMAP sections 3 and 13.6 describe it: a collections book, the
mayor's review of the year with a title at lantern night, and the first things that only
year 2 has. Save version 26.

- *The almanac.* Press **L** anywhere. Six pages: crops, fish (river, stream and pond), sea
  fish, forage (the Woods and the Lane), sea forage (the Cove) and recipes (dishes cooked
  at the stove; the workbench's plans and the bakery's and tavern's food aren't in it). A
  seventh page, Years, has each year's review and this year so far. 89 entries today. An
  entry is filled in once it's been grown (picked), caught, found or cooked; until then
  it's a dark shape with a hint under it (when and where it grows, bites or turns up).
  Q / Tab turn the page, the arrows (or WASD) pick an entry, L or Esc close it. The game
  is paused while it's open, as in a shop: it's a book you sit down with, and that keeps
  the arrow keys from walking the farmer. It won't open over another menu.
- *Pages are worked out from content.* A new crop, fish, wild thing or recipe .tres is in
  the book with no code change (rule 3). Which page is decided by what it is: a fish that
  lives only in the sea is a sea fish, a wild thing found in the Cove is sea forage. The
  six pages themselves are a list in `Almanac.PAGES`; options considered were a
  page Resource per page (more files for something that changes once in a blue moon) and
  one long list (89 entries is too many to page through).
- *What's kept.* Fish and dishes were already counted (the fish log, recipes cooked).
  New in the save: crops picked and wild things found (`collections`), this year's tally
  for the review (`year_stats`: gold earned by selling, crops picked and their kinds, fish
  and their kinds, wild things and their kinds, dishes cooked and their kinds, requests
  finished, new almanac entries) and every year's review (`year_reviews`). The Almanac
  autoload listens on EventBus and writes them; GameState holds and saves them, so the
  save is still exactly what GameState has.
- *The year review.* At lantern night, when the mayor hands over his lantern, he reads out
  the year: what you picked and sold, caught, found and cooked, the requests you finished
  and how you did at the festivals, how full the almanac is, and then a title. The tally
  becomes a score (a point per 500g earned; 3 per kind of crop, 2 per kind of fish, 1 per
  kind of wild thing and of dish, 2 per request, 6 for a festival win and 2 for second or
  third) and the score a title: "A promising start" (0), "Finding your feet" (40), "A good
  pair of hands" (90), "The valley's grower" (150), "Talk of the town" (210), "Pride of the
  valley" (280). Every number, title and line is in `data/year_review_rules.tres`
  (YearReviewRules, on GameRules), for Stage 26's balance pass to tune. Kinds count more
  than amounts on purpose: a year spent trying things should beat a year of nothing but
  parsnips. In year 2 he says so if you've done better than last year.
- *Missed lantern night.* The year still closes the night it turns. The review is written
  down anyway, and the first morning's summary says the mayor left a note; the Years page
  has it. Options considered: the mayor tells you next time you speak to him (he'd be
  reading out a year that's already over, in spring), or no review at all (harsh for
  missing one evening).
- *A keepsake.* The lantern the mayor already gives at lantern night is the year's
  keepsake; no new decoration was drawn.
- *Year 2.* A calendar unlock, `year_two` (day 113, spring 1 of year 2), says so in the
  morning's news. With it: Rosa's city orders (`rosa_city_orders`: twice the bin's price,
  8 to 18 of a thing, crops plus honey, mackerel, cod and pollack; three times as likely
  as her ordinary orders on market day), the mayor's request "The valley's almanac" (fill
  in 12 new entries: 600g and his father's bird bath) and Pip's "Pip's shadows" (5 new
  entries, from summer: 300g). Both use a new kind of request, AlmanacGoal, which counts
  entries filled in after it's taken, on any page or one. Left for later, because they
  need new art or people: Hollis's rare catalogue and Fennel's exotic greenhouse seeds
  (ROADMAP section 3). Hollis already sells every season's seeds all year, so the
  greenhouse is never short of something to grow.
- *Older saves (25 -> 26).* Nothing counted crops or wild things before, so an upgraded
  game's book starts with whatever's in its bag (a crop's produce or a wild thing there is
  counted as grown or found once) plus the fish and dishes it already had. Its tally
  starts on the day it's upgraded and is marked partial, so the mayor says he started his
  book late; in year 1 the fish already caught are carried into it.

**Why.** ROADMAP 13.6 (agreed 2026-11-17): the almanac gives the later game something to
fill, the review gives the first year an ending, and year 2 needs a reason to be played.
