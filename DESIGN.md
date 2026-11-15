# Pixel Harvest — design

## One paragraph

A top-down pixel-art farming game. The player walks a farm, tills soil, plants, waters,
weeds and harvests, on a day cycle ended by sleeping or by running out of energy. Four
seasons gate which crops will grow and visibly change the farm. Crops are either
single-harvest or regrowing. Produce is sold through a shipping bin, and later through a
town with shops, a blacksmith, a periodic market and a handful of characters who offer
quests. Progression comes from **buying out your own labour**: tool tiers that widen area
of effect, energy upgrades, sprinklers that remove watering entirely, and more plots to
fill. Difficulty is a set of multipliers chosen at new game. No animals, no combat, no
prestige loop.

## The core loop

1. Wake with full energy.
2. Water yesterday's crops, harvest what's ready, till and plant new ground.
3. Drop produce in the shipping bin.
4. Sleep (in the farmhouse bed). Crops advance one growth stage. Bin is sold overnight; gold arrives at dawn.
5. Spend gold on seeds, tools, upgrades and plots.

Energy is the brake. Every meaningful action costs some, and when it's gone the day ends
whether you're finished or not. That makes "how much farm can I service in a day" the
central question, and makes every upgrade that reduces actions-per-tile feel like a real
gain.

## Why this is a progression game, not an idle game

Nothing happens while the game is closed. There is no offline accumulation and no
real-time growth. The compounding happens across in-game days, as the player converts
gold into labour saved. This was a deliberate choice (`DECISIONS.md` 002) — it removes an
entire subsystem and it suits a game where you walk around and do things by hand.

## Progression spine

The intended arc, roughly in order:

| Phase | What changes | What it feels like |
|---|---|---|
| Opening | A few tiles, one or two crops, everything by hand | Every tile is deliberate |
| Early | Better hoe and watering can — area of effect 1 → 3 tiles | The same day covers three times the ground |
| Middle | Energy upgrades; more plots; regrowing crops planted for steady income | Planning a season rather than a day |
| Late | Sprinklers remove watering; harvest is the only daily chore | The farm runs itself; you choose what to grow, not whether you can keep up |
| Endgame | Cosmetics, farm layout, filling the crop collection, quests | Playing for the look and the completion |

The design intent at every step: **the chore you used to do by hand becomes automatic.**

## Time and calendar

- A day ends on sleep, or when energy hits zero.
- No in-game clock within a day. Actions cost energy, not time.
- Seasons of a fixed number of days (length to be set in Stage 6), then the year rolls over.
- Out-of-season crops die at the season change — that's the planning pressure seasons exist
  to create.

## Crops

Two kinds, distinguished by a single field on the crop definition:

- **Single-harvest** — plant, water through N growth stages, harvest once, tile clears.
- **Regrowing** — after maturing, produces again every few days until the season ends.
  Berries, beans. Lower per-harvest value, better over a season, worth the early investment.

No quality tiers and no crop processing (jam, wine, cheese). Both were considered and
deferred (`DECISIONS.md` 006); the Resource architecture leaves room if they're wanted later.

## World

- **The farm** — the starting area, expanding as plots are bought.
- **The town** — arrives in Stage 7. A seed shop, a general store that buys produce, a
  blacksmith for tool upgrades, plus a market that appears every so often with better prices
  and rarer seeds. Two or three characters give simple quests ("bring me 20 parsnips") in
  exchange for gold, seeds or cosmetics.

Until the town exists, buying and selling happens through a menu and a shipping bin on the
farm, so the full loop is playable from Stage 4 onward.

## Difficulty

A `DifficultyDef` resource chosen at new game: multipliers on sale prices, seed costs,
energy costs and grow times. Not separate code paths — difficulty is data.

## Explicitly out of scope

Animals. Combat. Mining or foraging areas. Fishing. Marriage or relationship systems.
Multiplayer. Prestige or reset loops. Any of these could be added later on top of the
existing architecture; none should shape it now.
