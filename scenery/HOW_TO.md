# Dave's scenery: how to dress a map

Each outdoor map has a scenery scene in this folder: `farm.tscn`, `town.tscn`, `lane.tscn`,
`woods.tscn` and `cove.tscn`. Whatever pictures you put in one show up on that map every time
the game runs. It's decoration only: it doesn't touch the save, and it can't break a quest.

## 1. Open the map's scenery

1. In Godot, find the **FileSystem** panel (bottom left) and open the `scenery` folder.
2. Double-click the map you want, e.g. `farm.tscn`. It opens in the middle in **2D** view.
3. You'll see the whole map behind, with a thin yellow line round its edge. That picture is
   only a guide (a "backdrop"): you can't click it or change it, and it isn't saved.

**No map behind?** Press F5 to play, walk to that map and press **Ctrl+B**. "Backdrop saved"
appears at the bottom left. Stop the game, close the scenery tab and double-click it again.
Do the same whenever a map changes (a new building, the tide out in the Cove...).

## 2. Pick a group

In the **Scene** panel (top left) the scene has four groups. Click one before you drag:

| Group | For | How it behaves |
|---|---|---|
| **OnTheGround** | flat things: flowers, puddles, rugs, shells, leaves | always under the farmer |
| **Standing** | upright things: trees, lamps, barrels, signs | the farmer walks in front of and behind them |
| **Solid** | the same, when he shouldn't walk through: fences, walls, big rocks | he bumps into its foot |
| **Overhead** | bunting, string lights, branches | always over everyone |

If you forget and nothing is picked, the picture goes on the top line and counts as Standing.
To move a picture to another group later, drag its line in the Scene panel onto the group.

## 3. Drag pictures in

1. In FileSystem, open `assets` → `scenery`. The pictures are sorted into `nature`, `props`,
   `harbour`, `seaside`, `creatures` and `festival`.
2. To see them as pictures rather than names, click the little square button at the top of
   FileSystem, next to `res://`: the panel splits, and its lower half shows the open
   folder's pictures (if they show as a list, the four-squares button above that half
   switches to thumbnails). To search, type in **Filter Files**, e.g. `lamp` or `barrel`.
3. Drag a picture onto the map and let go where it should stand. Its feet go where its
   bottom edge is.

Our own pictures in `assets/sprites/` work too. Drag **pictures** (`.png`) only, never the
game's scenes (`.tscn` files such as `bench.tscn`): those can have jobs in the game.

Handy keys while a picture is selected:

- drag it to move it; the **arrow keys** nudge it one pixel at a time
- **Ctrl+D** makes a copy (good for a row of fence or bunting)
- **Delete** removes it, **Ctrl+Z** undoes
- **Flip H** in the Inspector (right) mirrors it
- to line things up on the 16-pixel tiles, turn on **Use Grid Snap** (the magnet-and-grid
  button above the map, or Shift+G); its **⋮** menu → *Configure Snap* sets the step to 16

## 4. Save and try it

Press **Ctrl+S** to save (a `(*)` on the tab means unsaved changes). Then F5 and walk to that
map. If the game is already running, stop it and press F5 again: it reads the scenery when
it starts.

## Pictures that do more

- A name ending `_3f`, `_4f` and so on is an **animation** (3 or 4 frames side by side). The
  editor shows the first frame, the game plays it. `pingpong` ones go there and back.
- A name with `on_off` (the string lights) is **lit after dark**, from 7:30 pm to 6:30 am.
- A name with a **season** in it (`oak_summer`, `holly_winter`) changes with the season,
  when the other seasons' pictures are in the same folder. Place any one of them.
- Fences and walls come as `..._horizontal`, `..._vertical` and `..._post` pieces; bunting
  and lights as `..._span`. Line copies up side by side.

## Little moving things (smoke, birds, sparkles...)

The game already adds some small animations by itself: chimney smoke, windows lit after
dark, butterflies, songbirds, gulls, falling leaves, fireflies, sparkles on the water and
snow, ripples and jumping fish. **Settings → Animations** (or **Ctrl+Y**) turns them all
off and on. There are three ways to add more:

**1. Drag one in by hand.** The animations are in `assets` → `scenery` → `ambient` (smoke,
sparkles, ripples, splashes, fireflies, leaves) and `creatures` → `critters` (butterflies,
robins, ducks, squirrels, frogs...) and `creatures` → `birds`. Our own are in `assets` →
`sprites` → `ambient` (a jumping fish, a songbird). Drag them into a scenery scene like any
picture; they play in the game. Two words in a picture's **name** change how it plays.
Rename its line in the Scene panel (double-click the name):

- **now and then**, e.g. `Fish now and then`: plays once, hides for a few seconds, plays
  again. Good for a fish jumping in one spot, or a splash under the pier.
- **night**, e.g. `Lantern night`: only shows after dark, fading in at dusk like the lamps.

Put water things (ripples, fish, sparkles) in **OnTheGround**, flying and floating things
in **Overhead**.

**2. Smoke or lit windows on a building.** Each building has a file in
`data/ambience/buildings/` (`bakery.tres` and so on). Double-click one and the Inspector
shows two lists: **Chimneys** (the top middle of each chimney) and **Windows** (a box
round each window: x, y, width, height). The numbers are pixels in the building's picture,
counted from its top-left corner: open the picture in `assets/sprites/...` and hover the
mouse over it in an image editor to read them. Press **+ Add Element** for another.

**3. A new kind of thing that comes and goes by itself.** Each kind is a file in
`data/ambience/effects/`. In FileSystem, right-click one (say `butterflies.tres`) →
**Duplicate...**, give it a new name, and change it in the Inspector:

| Setting | What it does |
|---|---|
| Pictures | the strip(s) to use; one is picked at random each time |
| Motion | Once (plays on a spot), Wander (hovers about), Fly Across, Fall |
| Ground | where it can appear: Grass, Pond, Sea, Water (pond or sea), Any |
| Places | farm, lane, town, woods, cove (empty = everywhere) |
| Seasons, Weather, Not Weather | when it may play (empty = always) |
| From Minute / Until Minute | the hours: 360 is 6 AM, 1200 is 8 PM; both 0 = all day |
| Per Minute, Most At Once, Flock | how often, how many, how many together |
| Frame Seconds, Speed, Lifetime | how fast it plays and moves, how long it stays |
| Glows | drawn as light, for things that shine at night |
| Above | over people (birds, leaves) or on the ground under them (sparkles) |

Stop and start the game (F5) to see a change. If a picture can't be found, that one just
doesn't play; nothing breaks.

## Don't lose your work

- **Save often** (Ctrl+S), and commit the `scenery` folder's `.tscn` files with the rest of the
  game. They're the record of where everything goes, and they hold no pack pictures, so
  they're fine in the public repository.
- The pictures themselves (`assets/scenery/`) and the backdrops are **kept out of git** on
  purpose (the pack licence). Keep the pack zips safe: the pictures can be made again from
  them with `art/build_scenery_library.py`.
- **Don't rename or move** a picture in `assets/scenery/` after you've used it: the scene finds
  it by its name and place. (If a scene can't find a picture, that map just shows no
  scenery, and the Output panel says why.)
- Keep **Solid** things off paths, doorways and the ways out of a map, or the farmer could get
  stuck. Townsfolk walk straight through scenery, so they never get stuck.
