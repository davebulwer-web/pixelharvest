# Pixel Harvest — working brief

**Read this first in every session, then read `STAGES.md` to find the current stage.**

## What this is

A top-down pixel-art farming game in **Godot 4.7.2, standard build, GDScript** (not .NET).

- Game design: `DESIGN.md`
- Decisions and the reasoning behind them: `DECISIONS.md`
- Stage plan and current position: `STAGES.md`
- Art specification and Pixellab prompt template: `art/STYLE.md`

The project exists as much to build skill as to produce a game. Dave has 35 years in IT
and sound project instincts, but is new to programming and new to Godot. So:

- Explain the non-obvious. Comment **intent**, not syntax.
- Prefer the clear solution to the clever one.
- When there's a real architectural choice, say what the options were and why you picked
  one — and add an entry to `DECISIONS.md`.
- Never hand over a wall of code with no explanation of how to run or test it.

## How we work

**Claude cannot run Godot on Dave's machine.** Files are written into `F:\Pixel Harvest`
through the device bridge. Dave presses F5 and reports what happened.

**Claude can run Godot 4.7.2 headless in its own sandbox**, and must use it. Before any
file is delivered:

```bash
# Download once per session (~78MB) if not already present:
curl -sL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q godot.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64

# Then, against a copy of the project:
godot --headless --path . --import          # catches parse errors, bad resources
godot --headless --path . --quit-after 10   # catches runtime errors on startup
```

**Always run `--import` before any other Godot invocation on a fresh checkout.** Without
it every texture fails to load and the resulting errors are misleading — they look like
broken resources when nothing is wrong.

**Claude can also see the game running.** `xvfb` is available, so Godot can render with a
real OpenGL driver to a virtual display and write out frames:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 \
    --write-movie /tmp/frames/shot.png --quit-after 60
```

Combined with a temporary autoload that presses input actions in `_physics_process`, this
makes movement, animation, collision and Y-sorting verifiable before delivery. Two rules
learned the hard way: drive input from `_physics_process`, never `_process` (otherwise the
press/release races the player's own physics step and produces phantom bugs), and delete
the test harness before shipping.

Delivering code that hasn't been through that is not acceptable — Dave can't debug it
himself, so an avoidable error costs him a wasted session.

Other working rules:

- **One stage per session.** Long sessions are where architecture quietly rots.
- **Commit at every state where the game runs**, not at every change. Dave runs git himself.
- **Update `STAGES.md`** at the end of each session.
- Suggested model per stage is in `STAGES.md`. Use Opus where a wrong decision is expensive
  to unwind; Sonnet once the pattern exists and the work is more of the same.

## Architecture rules

These are what keep the game extensible. Breaking one is a decision to be recorded, not a
shortcut to be taken quietly.

1. **Data is separate from presentation.** `FarmData` holds the authoritative state of every
   tile. The TileMapLayer only *draws* it. Never read game state out of the tilemap.
2. **Systems talk through `EventBus`.** Emit a signal describing what happened; let others
   subscribe. Don't take a direct reference to another system merely to react to it.
3. **All content is a Resource.** Crops, tools, upgrades, seasons, quests are `.tres` files
   with a typed script, loaded by `ContentDB`. *Adding content must never require code
   changes.* This is the main defence against rewrites.
4. **Saves are versioned.** Every save carries `save_version` and passes through a migration
   function, even while there is only one version.
5. **Tools act on tiles through one interface.** A new tool is a definition plus a small
   handler, never another branch in a growing `if/else`.
6. **No balance numbers in scripts.** Grow times, prices, energy costs live in resources.

## Conventions

- Static typing everywhere: `var cell: Vector2i`, `func advance_day() -> void`.
- `snake_case` for files and functions, `PascalCase` for classes and nodes.
- Signals are past tense: `crop_harvested`, never `harvest_crop`.
- Content IDs are `StringName`: `&"wheat"`, not `"wheat"`.
- One autoload per service, in `scripts/autoload/`.
- Docstring comments (`##`) on every script, saying what it is *for*.

## Layout

```
project.godot        Engine config — see DECISIONS.md 009 before changing display settings
icon.svg
scenes/              .tscn scene files
scripts/             Game code
  autoload/          Global services (EventBus, ContentDB, GameState, Economy, SaveSystem…)
  farm/              The farm's data and layout, the farmhouse and its bed
  town/              The town, its map, shop interiors and fronts, people, notice board (Stage 7)
  items/             Inventory
  tools/             ToolAction scripts (hoe, watering can, planting, placing objects
                     and decorations)
  upgrades/          UpgradeEffect scripts (tool tier, max energy, field)
  quests/            QuestGoal scripts (deliver, harvest, sell) and the saved QuestLog
data/                Content resources (.tres), indexed by ContentDB
  crops/             CropDef — how each plant grows and looks
  produce/           ItemDef — what a harvest gives, and its sell price
  tools/             ToolDef — tools, seeds and sprinklers (all things you use)
  decorations/       ToolDef — decorations for the farm, placed like sprinklers (DECISIONS 039)
  objects/           ObjectDef — things standing on the farm (tree, bin, sprinklers, decorations)
  upgrades/          UpgradeDef — bought once: tool tiers, energy, fields
  seasons/           SeasonTheme — each season's name and look (crops list their own seasons)
  locations/         LocationDef — the farm, the farmhouse, the town, each shop (and where its door is)
  shops/             ShopDef — a shopkeeper, their words, and what the counter offers
  characters/        CharacterDef — townsfolk you can talk to (not shopkeepers)
  events/            CalendarEvent — what happens on which days (market day) and its stalls
  quests/            QuestDef — townsfolk's requests: who asks, for what, and the reward
tests/saves/         Old-version save files, for proving save upgrades still work
assets/sprites/      Character and object art from Pixellab (town/ holds the shops and keepers,
                     farm/ the farmhouse and its furniture, decorations/ the farm's decorations)
assets/tilesets/     Ground and world tilesets
art/                 Art specification and generation log (not shipped art)
```
