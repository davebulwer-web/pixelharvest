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
export_presets.cfg   The Windows export (DECISIONS 091): Project → Export → Windows Desktop
                     writes builds/windows/PixelHarvest.exe. builds/ is git-ignored: a build
                     has the packs' pictures in it, for Dave's own testing only
icon.svg
scenes/              .tscn scene files
scenery/             Dave's scenery: one scene per map that he fills by dragging pictures in
                     the editor (how-to: scenery/HOW_TO.md); backdrops/ is git-ignored
                     (DECISIONS 082)
scripts/             Game code
  autoload/          Global services (EventBus, ContentDB, GameState, Economy, SaveSystem,
                     Audio, DayReport, Fishing, Festivals, Allotments, Tavern, Almanac…);
                     Almanac keeps the collections book's counts and the year's tally,
                     and the mayor's year review (DECISIONS 085); Settings keeps the
                     player's volume and screen choices in user://settings.cfg, apart
                     from the save (DECISIONS 086)
  farm/              The farm's data and layout, the farmhouse with its bed and its
                     stove and cooking menu (Stove, CookMenu; DECISIONS 056), the
                     workbench by the farmhouse, which uses the same menu for its
                     plans (Workbench; DECISIONS 063), the
                     farm's effects, the night's hazards (FarmHazards) and the
                     morning's crows; the greenhouse's room and plot (Greenhouse,
                     which extends main.gd, and GreenhouseLayout; DECISIONS 057)
  town/              The town, its map, shop interiors and fronts (Mabel's bakery is one:
                     DECISIONS 063), people, notice board (Stage 7),
                     the river and the bridge to the Woods; Nell's tavern, the Wheatsheaf:
                     its room (tavern.gd), the chalkboard and dartboard (TavernFixture) and
                     the darts game (DartsGame; DECISIONS 068); the town hall is a
                     LocationDef with door_words; the townsfolk's homes (the mayor's,
                     Wren's, and those on the Lane and in the Cove) share one room, Home
                     (home.gd, scenes/home.tscn), shaped by each home's LocationDef and
                     open 8 AM to 8 PM (DECISIONS 084)
  woods/             The Woods: their map, the day's forage (Forage, ForageSpot; DECISIONS 052)
                     and fallen logs (FallenLogs, FallenLog; DECISIONS 053)
  lane/              The Lane between the farm and the town: its map (LaneLayout), its
                     hedgerow forage, the signpost (DECISIONS 060); Pip's cottage,
                     Dot's yard and Ivy's cottage (DECISIONS 068) are LocationDefs with
                     door_words (DECISIONS 061); Dot at her gate, the
                     allotment holders' slate (JobSlate) and the beds as today's jobs
                     leave them (AllotmentBeds, AllotmentWeed; DECISIONS 062)
  cove/              The Cove: its map (CoveLayout: the harbour, the beach, the shore the
                     tide uncovers), the tides worked out from the clock (Tides), the
                     harbour's tide board (DECISIONS 064); Tam on the quay, the sea off
                     the pier, and the crab pots' floats (CrabPot; DECISIONS 065)
  people/            Where the townsfolk are (Schedules: worked out from the clock, and
                     weekdays) and the people on the map you're on, walking between
                     their stops and talking (PeopleHere; DECISIONS 067); which of eight
                     ways someone faces and which animation that plays, falling back to
                     four (Facing; DECISIONS 074)
  scenery/           Scenery: puts a map's scenery scene into it when it opens, animates
                     strips, lights string lights, takes the backdrop (Ctrl+B);
                     SceneryLayer: the scene's root, which helps in the editor (DECISIONS 082)
  ambience/          Ambience: the little things that move by themselves on the outdoor
                     maps (chimney smoke, lit windows, butterflies, birds, leaves,
                     sparkles, fish), added with the scenery; off in Settings or Ctrl+Y
                     (DECISIONS 088)
  exits.gd           Exits: builds a place's ways out from LocationDef.exits (ExitDef;
                     DECISIONS 060)
  ground_tiles.gd    GroundTiles: where each kind of ground is in the seasonal tilesets
                     (the hedge is drawn by art/build_calm_hedge.py, DECISIONS 087);
  ground_edges.gd    GroundEdges: the soft edges where grounds meet, a display-only
                     dual grid over every outdoor map's ground (DECISIONS 072)
  ui_style.gd        UiStyle: the colours and sizes code asks for by name, text on the
                     world (light, outlined) or on a panel (ink), panel and button boxes
                     from the theme (DECISIONS 074)
  dialogue_box.gd    DialogueBox: lines and questions, with the speaker's portrait in a
                     mood (DECISIONS 074)
  almanac_book.gd    AlmanacBook: the almanac on screen (L), its pages and the Years page
                     (DECISIONS 085)
  menus/             The title screen (TitleScreen) the game opens on, over the game it
                     loaded, and the Esc menu (PauseMenu); what they share, with the
                     Settings, Controls and "are you sure?" pages (MenuScreen; DECISIONS 086);
                     the Saved games page (three games: save.json, save_2.json, save_3.json)
                     and the Credits page (Credits: the player's short version of
                     CREDITS.md; DECISIONS 090)
  items/             Inventory
  fishing/           FishingLine: the float, the line and the reel bar (DECISIONS 054)
  tools/             ToolAction scripts (hoe, watering can, planting, placing objects
                     and decorations, the trowel's digging, pest spray, the axe's
                     chopping, which also works in the Woods: DECISIONS 053; the
                     fishing rod's cast: DECISIONS 054; eating a dish, which is
                     used on the farmer, not a tile: DECISIONS 056; feeding the
                     soil and the sickle's cut: DECISIONS 058; Tam's handline is the
                     rod's cast for the sea only, and a crab pot is lowered off the
                     pier: DECISIONS 065)
  upgrades/          UpgradeEffect scripts (tool tier, max energy, field)
  festivals/         ContestRule scripts: what a festival's contest judges (best item,
                     biggest fish; DECISIONS 059)
  quests/            QuestGoal scripts (deliver, deliver any of, deliver one of each,
                     harvest, sell, give gold, grow a giant, deliver with a fee, catch
                     fish, carry a parcel, do an allotment job: DECISIONS 062; fill in new
                     almanac entries: DECISIONS 085) and the saved QuestLog
data/                Content resources (.tres), indexed by ContentDB
  game_rules.tres    Starting conditions and global numbers (GameRules)
  hazard_rules.tres  Thirst, weeds, crows and aphids: every number (HazardRules,
                     DECISIONS 045, 048)
  tide_rules.tres    When the Cove's tide is out: the period, the first low tide and the
                     window either side (TideRules, DECISIONS 064)
  fishing_rules.tres The wait, the strike and the reel bar's numbers, the ice, the lures and
                     the fine rod (FishingRules, DECISIONS 054, 055); the sea and its tide
                     (DECISIONS 065)
  crab_pot_rules.tres What baits a crab pot and what it catches (CrabPotRules, DECISIONS 065)
  tavern_rules.tres  Nell's chalkboard, her rumours' words and darts night's numbers
                     (TavernRules, DECISIONS 068)
  year_review_rules.tres  What the mayor's year review counts and the titles it gives
                     (YearReviewRules, DECISIONS 085)
  crops/             CropDef — how each plant grows and looks, and its rules (trellis,
                     perennial, hardy…; DECISIONS 047; giants and 2 × 2 trees, 048)
  produce/           ItemDef — what a harvest gives, and its sell price (and fibre, timber,
                     bait, and the lures: LureDef, DECISIONS 055)
  tools/             ToolDef — tools, seeds and sprinklers (all things you use), and
                     fertilisers (FertiliserDef: what fed soil does; DECISIONS 058)
  decorations/       ToolDef — decorations for the farm, placed like sprinklers (DECISIONS 039)
  objects/           ObjectDef — things standing on the farm (tree, bin, sprinklers, decorations,
                     bee hives: an object can make something, like honey; DECISIONS 057;
                     debris on the new ground, cleared for what it gives: DECISIONS 060)
  upgrades/          UpgradeDef — bought once: tool tiers, energy, fields
  seasons/           SeasonTheme — each season's name, look, weather odds and music (crops
                     list their own seasons)
  weather/           WeatherDef — sunny, rain, storm, heatwave, snow, frost: what each does,
                     looks and sounds like (DECISIONS 046)
  locations/         LocationDef — the farm, the farmhouse, the greenhouse, the Lane, the town,
                     the Woods, the Cove, each shop (and where its door is, or its ways out: exits),
                     and homes seen from outside (door_words; DECISIONS 061)
  shops/             ShopDef — a shopkeeper, their words, and what the counter offers; what
                     it buys (buys_tags) and how its price drops for plenty (DemandDef,
                     DECISIONS 063; the bin's is in game_rules.tres)
  characters/        CharacterDef — townsfolk you can talk to (not shopkeepers); one can
                     have a counter of their own (Tam, DECISIONS 065); their portrait and,
                     once drawn, their walk cycle (walk_frames; DECISIONS 074)
  schedules/         ScheduleDef — where each person is through the day: a home and
                     DayPlans of ScheduleStops, by weekday, season and weather (DECISIONS 067)
  events/            CalendarEvent — what happens on which days (market day) and its stalls,
                     and the festivals: host, contest, rivals, prizes, decorations (DECISIONS 059)
  quests/            QuestDef — requests from townsfolk or shopkeepers: who asks, for what,
                     and the reward
  difficulties/      DifficultyDef — chosen at new game: multipliers on prices, energy, growing
  ambience/          The little moving things: AmbientEffect files (effects/: what, where,
                     when, how often), BuildingAmbience files (buildings/: chimneys and
                     windows in pixels of the picture) and AmbienceRules (DECISIONS 088)
  audio/             SoundBank — what each sound the game plays sounds like (DECISIONS 042)
  unlocks/           UnlockDef — things that open up over time, from a request or a date
                     (DECISIONS 043); content waits for one with `requires_unlock`
  orders/            OrderTemplate — patterns for requests made fresh each day: Rosa's
                     market orders, the notice board's daily jobs (DECISIONS 050), Dot's
                     errands (ErrandTemplate) and the allotments' odd jobs (JobTemplate;
                     DECISIONS 062)
  forage/            ForageDef — wild things found in the Woods, the Lane's hedgerows and
                     the Cove: items, with the seasons, places and weather they grow in
                     (DECISIONS 052); rockpool forage only at low tide, and driftwood
                     picked up as timber (DECISIONS 064)
  fish/              FishDef — fish: items, with the water, seasons, hours and weather
                     they bite in, their size and fight (DECISIONS 054); sea fish, some only
                     at high tide (DECISIONS 065)
  dishes/            ToolDef with an EatAction — food: eaten from the hotbar for
                     energy, never sold (DECISIONS 056); the bakery's sold by Mabel
                     (DECISIONS 063)
  recipes/           RecipeDef — what goes into each dish; known recipes are taught by
                     requests and cooked at the farmhouse stove (DECISIONS 056); and the
                     workbench's plans, made_at the workbench (DECISIONS 063)
  finds/             FindDef — what now and then turns up while clearing the farm's new
                     ground: what it gives, earns or leaves standing (DECISIONS 061)
tests/saves/         Old-version save files, for proving save upgrades still work
assets/sprites/      Character and object art from Pixellab (town/ holds the shops and keepers,
                     farm/ the farmhouse and its furniture, decorations/ the farm's decorations,
                     forage/ the wild things' icons, woods/ the Woods' own pieces,
                     fish/ the fish's icons, fishing/ the float,
                     dishes/ the dishes' icons, lane/ the Lane's pieces, cove/ the Cove's)
assets/sprites/portraits/  Each person's three busts (neutral, happy, worried), 64 × 64 each
assets/ui/           The UI Theme (theme.tres, the project's theme) and its nine-patch
                     pictures: panel, portrait frame, buttons (DECISIONS 074)
assets/fonts/        monogram (text) and Pixelify Sans (headings), with their licences
assets/tilesets/     Ground and world tilesets
assets/scenery/      Pictures for Dave's scenery, cut from the bought packs by
                     art/build_scenery_library.py (git-ignored: the packs' licence); ambient/ and
                     creatures/critters/ feed the little moving things too
assets/sprites/ambient/  Our own little moving things: a jumping fish, a songbird, a window
                     halo (art/build_ambient_art.py; DECISIONS 088)
assets/audio/        Sound effects (sfx/*.wav) and the weather's loops (ambience/*.ogg), made by
                     art/build_sounds.py; music (music/: Dave's own tunes, DECISIONS 066; picked
                     by file name, season_ or festival id_, no list to edit: music/HOW_TO.md,
                     DECISIONS 087)
art/                 Art specification and generation log (not shipped art); art/fonts/
                     holds monogram's original and the script that adds four characters
                     to it (ignored by Godot: .gdignore)
```
