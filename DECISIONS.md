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
