# Adding your own music

No code and no lists to edit: **the folder is the list.** Put a file in this folder
(`assets/audio/music/`) with the right start to its name, and the game plays it.
(DECISIONS 087.)

## 1. Name the file

The start of the file name says when it plays. After that, an underscore and anything
you like (lower case, no spaces, is safest).

| Name starts with  | Plays                                                          |
|-------------------|----------------------------------------------------------------|
| `spring_`         | everywhere in spring                                           |
| `summer_`         | everywhere in summer                                           |
| `autumn_`         | everywhere in autumn                                           |
| `winter_`         | everywhere in winter                                           |
| `flower_show_`    | in town (and its shops) on the Flower Show day, spring        |
| `fishing_contest_`| in town on the Fishing Contest day, summer                     |
| `harvest_fair_`   | in town on the Harvest Fair day, autumn                        |
| `lantern_night_`  | in town on Lantern Night, winter                               |
| `market_day_`     | in town on market days (every week)                            |
| `any_`            | in a season that has no tunes of its own (a safety net)        |

Examples: `spring_morning_dew.mp3`, `winter_snowfall.ogg`, `lantern_night_carol.mp3`,
`harvest_fair_fiddle.mp3`.

**Falling back.** On a festival day the festival's tunes play in town; everywhere
else (the farm, the Lane, the Woods...) the season's tunes carry on. If a festival
has no file of its own, the season's tunes play there too, as now. If a season has
no files at all, the `any_` ones play; with none of those either, it's silent.
The tavern keeps its own tune if it has one.

A season (or festival) with **two or more** tunes plays them in a random order, never
the same one twice running. With **one**, it repeats.

## 2. The file itself

- **Format:** MP3 is fine (it's what your current tunes are). OGG also works. WAV works
  but the files are huge, so avoid it for long pieces.
- **Looping:** don't loop it. Leave the tune with a proper ending. The game starts the
  next tune 3 seconds before the end and fades the two into each other, so there's no
  gap. (Don't tick Godot's "Loop" option in the Import tab either: a looping file never
  ends, so it never hands over to the next one.)
- **Loudness:** your current tunes are about 10 dB louder than the game's sounds, so the
  game plays every season's music 10 dB down (`music_volume_db` on each season in
  `data/seasons/`). Make new tunes about as loud as your others and they'll sit right.
  The player's own Music volume in Settings comes on top of that.
- **Length:** anything. Two to four minutes is typical.

## 3. Put it in and try it

1. Copy the file into `F:\Pixel Harvest\assets\audio\music\`.
2. Switch to the Godot editor. It notices the new file and imports it (a short progress
   bar). Wait for that to finish. **This step matters:** a file Godot hasn't imported
   yet is skipped (the Output panel says "Music: couldn't load ...").
3. Press F5. The new tune joins the season's (or festival's) list straight away.

**Hearing it quickly.** The tune you just added is one of several, so it may not come
up first. To hear it at once: temporarily move the season's other files out of the
folder (to your desktop, say), press F5, then put them back.

For a festival tune, play to that day (or load a save from near it) and walk into town.
The festival days are in `data/events/` (`first_day` is the day of the season).

## 4. Taking a tune out

Delete the file (or move it out of the folder). That's all: nothing else refers to it.
Godot will also tidy away its `.import` file.

## 5. Git

Music files are yours, so they go in git like the rest (`git add -A` picks them up, and
the `.import` file that Godot makes for each one belongs with it).

## Notes

- Spelling counts: `Spring_` works too (case doesn't matter), but `spring-` with a
  dash, or `sprng_`, won't match anything and the file is simply never played.
- The old `farm.ogg`, `town.ogg` and `woods.ogg` here match nothing, so they don't play.
  They can be deleted whenever you like.
- A festival that's added later (a new file in `data/events/`) gets music the same way:
  start the file name with its `id`.
