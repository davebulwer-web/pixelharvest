# Pixel Harvest — playthrough checklist

For a full playthrough (Stage 26, before balance session 2). Tick what works, and jot
down anything that feels slow, too rich, too hard, confusing or broken, with the day and
place. Those notes are what balance session 2 works from.

## Making the build and "installing" it

The export is set up and was tested in the sandbox, but the finished game is one 130 MB
file with the packs' pictures in it, too big (and not allowed) to send across, so it's
made on your PC in the editor:

1. Once only: in Godot, **Editor → Manage Export Templates… → Download and Install**
   (about 1 GB, for 4.7.2). Close the window when it says installed.
2. **Project → Export…**. **Windows Desktop** is already in the list on the left.
3. Click **Export Project…** at the bottom. Untick **Export With Debug**, leave the file
   name as `builds/windows/PixelHarvest.exe`, click **Save**. It takes a minute.
   A warning about rcedit or the icon is harmless: the file just keeps Godot's icon.
4. Open `F:\Pixel Harvest\builds\windows\` and double-click **PixelHarvest.exe**. That
   one file is the whole game. To "install" it, copy it anywhere (e.g.
   `C:\Games\Pixel Harvest\`) and right-click → **Send to → Desktop (create shortcut)**.
5. Windows may say "Windows protected your PC" the first time, because the file isn't
   signed: click **More info**, then **Run anyway**.

Good to know:

- The build and F5 in the editor share the same saves and settings, in
  `%APPDATA%\Godot\app_userdata\Pixel Harvest\`. Your current save is **Game 1**. For
  a clean playthrough use **Saved games → Game 2**, then **New game**, so Game 1 is kept.
- The build has the bought packs' pictures in it: it's for you only. Don't share or
  upload it. The `builds` folder is git-ignored for that reason.
- After any change to the game, repeat steps 2 and 3 to make a fresh build.

## The checklist

### Start and menus
- [ ] The game opens on the title over the farmhouse; Continue, New game, Saved games,
      Settings, Controls, Credits and Quit all work
- [ ] Saved games: Game 1 shows your farm; Game 2 is empty; picking Game 2 then New game
      starts a fresh farm; after a night's sleep, Game 1 still shows your old farm
- [ ] Credits page reads properly (nothing cut off)
- [ ] Settings: music and sound levels, full screen, window sizes x1 to x4, Pixels,
      Animations, Toolbar Large / Small, all stick after quitting and reopening
- [ ] Esc in the world: Resume, Settings, Title screen and Quit (both ask first)

### The toolbar (new: twice the size)
- [ ] It looks in proportion at the window size you play at, and in full screen
- [ ] Q / Tab move along it; the selected tool's name shows above it
- [ ] With lots of things in the bag it goes to two rows; with very many tools the ends
      show "<3" / "5>" and Q / Tab still reach everything
- [ ] It hides while someone's talking, and comes back after
- [ ] Settings → Toolbar → Small brings back the old size

### Spring (year 1)
- [ ] First days: hoe, water, plant parsnips, sleep, crops grow; the shipping bin pays
      overnight; the morning summary makes sense
- [ ] The clock: is a day the right length now (12 real minutes; it was 10)? Is the walk
      to town too long, about right, or too short?
- [ ] Energy: do you run out too early, or never?
- [ ] Clearing the new ground: stones, stumps, brambles; finds turn up now and then
- [ ] The Lane: Dot's errands, the allotment jobs, the hedgerow forage
- [ ] Town: Hollis's seeds, the general store, Brann the smith, Mabel's bakery, the
      notice board, Rosa's market orders on market day, the tavern and darts
- [ ] The Cove: Tam's handline, rockpools at low tide, crab pots off the pier
- [ ] Townsfolk walk between places and their homes open 8 AM to 8 PM
- [ ] The Flower Show (festival) works and feels worth going to
- [ ] Money: by the end of spring, can you afford the first upgrades
      (wide watering can 200, wide hoe 250, north field 500)? Too easy or too hard?

### Summer, autumn, winter
- [ ] Seasons turn: crops out of season die, the look and music change
- [ ] Weather: rain waters crops, storms, heatwaves, snow and frost behave as expected
- [ ] Crows, weeds, aphids: annoying in a good way, or just annoying?
- [ ] The Woods: fishing with Wren, the axe and timber, the fallen logs
- [ ] Cooking at the stove; the workbench's plans
- [ ] The greenhouse and bees once unlocked
- [ ] Each festival in its season; lantern night and the mayor's year review in winter
- [ ] The almanac (L) fills in as you go
- [ ] Year 2 starts with its new requests

### Looks and feel
- [ ] Little animations (smoke, lit windows, critters) feel right; Ctrl+Y turns them off
- [ ] Nothing flickers, overlaps or sits in the wrong place
- [ ] Any crash or freeze: note what you were doing; the editor's Output panel (F5) shows
      the error

### Money and pace notes (for balance session 2)
- Which crops did you mostly grow, and why?
- When did gold stop being a worry?
- Anything you could never afford, or never needed?
- Days that felt empty, or too busy?
