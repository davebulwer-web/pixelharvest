# Pixel Harvest — content roadmap (proposal)

**Status: agreed by Dave on 2026-11-15, all recommendations in section 12 accepted.** The
stages are now in `STAGES.md` (10 to 20). Nothing here is built yet; each reversal of an
earlier decision gets its own `DECISIONS.md` entry when it's built.

The engine is done: farming, tools and tiers, seasons, the town, shops, the clock, market
day, requests, decorations, difficulty, sound and juice. What's missing is the *game* on
top of it. This document proposes that game: what the first year feels like, what unlocks
when, who asks for what, which crops and hazards exist, what else there is to do, and the
order to build it in.

---

## 1. Why it feels thin today

Read straight from the data files, not guessed:

| Problem | Where it comes from |
|---|---|
| **Everything happens on day 1.** All four people's first requests are offered at once. | Every `QuestDef` has `first_day = 1`. Nothing else gates them. |
| **Nothing is revealed.** Every seed, upgrade, sprinkler and field is in a shop from the first morning. You can see the whole game on day 1. | Shops are filters over all of `ContentDB`; nothing is locked. |
| **No risk.** A crop can't be lost except at the season turn. Forgetting to water costs a day, nothing more. | "A day without water is simply a day of no growth — nothing dies of thirst yet" (`CropDef`). No weeds, pests, crows or weather exist. |
| **Few real choices.** Eight crops, and only two behave differently (regrowing). The rest differ only in numbers. Winter has two crops. | `CropDef` has five gameplay fields; only `regrow_days` changes behaviour. |
| **Nothing to do once watered.** The day runs 6 AM to 2 AM; watering takes minutes; the rest is walking to shops or sleeping. | Farming is the only activity. The town is shops and talk. |
| **Rewards don't change anything.** Requests pay gold (and one sprinkler, one sundial). Nothing opens up. | `QuestDef` rewards are gold and items only. |
| **The scarecrow is a lie.** It's sold as farm kit but does nothing. | DECISIONS 039: decorations do nothing. |

The fix isn't more of the same content. It's four things, in this order of value:

1. **Pacing** — drip-feed the game. Something new arrives every few days for the whole first
   year, and finishing things *opens* things.
2. **Pressure** — small, fair hazards so that a day's work matters and upgrades protect you
   from something, not just save you time.
3. **Choice** — crops with different *rules*, not just different numbers.
4. **Variety** — at least one thing to do that isn't farming, so the long afternoon has a use.

**On timing (Dave's question):** yes, now, before the balance pass. Balancing the current
loop would be thrown away as soon as hazards, unlocks and new crops land, because they
change every number that matters (how many tiles a player can keep alive, what a day earns,
when upgrades are affordable). The balance pass moves to the very end. One exception: a
short **pacing playtest** of one spring after Stage 10, because pacing is the part only
playing can judge.

---

## 2. Guiding rules for the content

- **One new thing at a time.** No day should introduce two systems. A new crop, a new
  person, a new hazard, a new place: each gets its own few days.
- **Introduce, then pressure, then relieve.** Weeds appear (a chore), then crows (a threat),
  then the scarecrow and sprinklers make them manageable. The upgrade feels earned because
  the problem was felt first.
- **Finishing things opens things.** A request's best reward is access: a shop's next
  catalogue, a place, a tool, a building. Gold is the small part.
- **Everyone has a story.** Each person's requests form a short arc with a payoff that
  visibly changes the town or the farm.
- **The calendar is the spine.** Seasons and fixed days (market, festivals) give the year a
  shape the player can plan around.
- **Data, not code.** Every item below fits the existing architecture: new crops, people,
  requests, places and events are `.tres` files. New *kinds* of thing need a small script
  once (as DECISIONS 024 says), then are data forever.
- **Hazards are fair and visible.** Every threat is announced the day before or seen in the
  morning, has a counter you can buy or earn, and is scaled by difficulty (Relaxed can switch
  most of them off).

---

## 3. The first year, season by season

This is the arc the stages build towards. Days are days of the season (1–28).
**[unlock]** marks something that opens up; **[new]** something introduced.

### Spring — "getting the old farm going"

| When | What happens |
|---|---|
| Day 1 | Wake in the farmhouse with a hoe, a can and 10 parsnip seeds. **Only the mayor** has a request: *"Plant those parsnips and bring me the first five you pull."* Hollis sells parsnips and radishes only. |
| Day 2–4 | Mayor's request done → **[unlock]** Hollis's full spring stock (potato, spring onion, peas). Day 3 is the first market day (Rosa, Fennel). Pip appears at the market and asks about strawberries (exists). |
| Day 5 | **[new] Mabel** arrives with her first request (parsnips, exists). |
| Day 6 | **[new] Weeds** start appearing on tilled soil overnight. The mayor's daily line warns you. |
| Day 8 | **[unlock] Brann's forge opens** ("back from the city"): wide hoe and wide can. Brann's first request: *"Sell me on your farm: show me 300g of produce sold and I'll take you seriously."* |
| Day 10–14 | Mabel's second request (potatoes). Brann's done → **[unlock]** great tools and Marlow's land deeds (the north field). |
| Day 15 | **[new] Crows.** The first morning, a crow has taken one crop and the mayor mentions it. The scarecrow at Marlow's now *works*. |
| Day 18 | **[new] Hollis's line** begins: *"Grow me one of every spring crop."* Reward: **[unlock]** the summer catalogue a week early, plus rhubarb crowns (perennial). |
| Day 20 | **[new] Mayor: the old bridge.** *"The bridge to the woods washed out years ago. Help the town fund it: 500g into the box."* → **[unlock]** the Woods at the start of summer. |
| Day 24 | **[new] Spring flower show** (festival): bring your best flower; tulips and the flower bed matter. Small prize, a decoration. |
| Day 25–28 | Notice board and Hollis warn that spring crops die at the turn. Autumn garlic is advertised (plant in autumn, harvest next spring). |

### Summer — "the farm grows up"

| When | What happens |
|---|---|
| Day 1 | **[unlock] The Woods** (if the bridge was funded): foraging (berries, mushrooms, herbs) and a stream. **[new] Weather:** the first rain day waters everything. |
| Day 2 | **[new] Wren's line:** *"Nothing's biting. Bring me some fresh worms from the woods and I'll show you something."* → **[unlock]** the fishing rod. |
| Day 5 | **[new] Brann's sprinkler line:** sprinklers are no longer just sold. Brann needs timber (from clearing thicket or the woods) and gold to "work out the design". → **[unlock]** sprinklers at the forge. Big sprinklers come later in the line. |
| Day 8 | **[new] Heatwave** (weather): unwatered crops wilt a day sooner. Chillies love it. |
| Day 10 | **[new] Rosa's orders:** market-day bulk orders with a deadline ("12 tomatoes by next market day"), better pay than the bin. Repeatable all year. |
| Day 14 | **[new] Summer fishing contest** (festival) at the town pond. Wren hosts. |
| Day 15–20 | Mabel's line moves on: she teaches the first **recipes** (if cooking is in) → **[unlock]** the farmhouse kitchen. |
| Day 21 | **[new] Storm** (weather): no crows that night, but unfenced tall crops can be flattened. Fences gain a purpose. |
| Day 25 | Corn and sunflowers advertised for late summer into autumn. |

### Autumn — "the big harvest"

| When | What happens |
|---|---|
| Day 1 | **[new] Pests** (aphids): one patch of crops is infested; it spreads to neighbours each night unless sprayed (Marlow sells spray). Gentle, one patch at a time. |
| Day 3 | **[new] Ivy, the retired gardener** (new character) appears by the ruined glasshouse behind the town. Ivy's line is the **greenhouse restoration**: timber, gold, one each of several autumn crops, a fish. → **[unlock]** the greenhouse by winter if done. |
| Day 7 | Mabel's pumpkin pie (exists, moved later in her line). |
| Day 10 | Apple saplings at Fennel's cart (perennial tree). |
| Day 14 | Pip's line: *"There's a giant pumpkin in a book! Can you grow one?"* → explains **giant crops** (a 3 × 3 block of ripe pumpkins can merge). |
| Day 21 | **[new] Harvest fair** (festival): judges the best crop of the year by value; the giant pumpkin wins outright. Prize: a trophy decoration and gold. |
| Day 25 | **[new] Early frost warning.** Frost on day 27 kills tender crops a day early unless you've harvested. Leeks, brussels sprouts, kale, garlic shrug it off. |

### Winter — "the quiet season"

| When | What happens |
|---|---|
| Day 1 | Snow. Outdoor farming is thin on purpose: kale, leeks, sprouts, parsnips, and garlic sleeping in the ground. **The greenhouse** (if restored) grows anything, any season, on a small plot. |
| All season | Ice fishing (a hole in the pond), winter foraging (holly, pine cones, winter mushrooms), cooking, clearing thicket for timber, and buying the long-goal upgrades. |
| Day 10 | Brann's last request: the **brass sprinkler** (24 tiles), the late-game prize. |
| Day 28 | **[new] Lantern night** (festival): the town lights lanterns; the mayor gives the **year review**: what you grew, earned, caught and finished, and a title ("A promising start" up to "Pride of the valley"). Year 2 begins. |

### Year 2 onwards

Year 1 is the story; year 2 is the farm. Lines that finished stay finished. New in year 2:
harder Rosa orders, Hollis's rare catalogue, Fennel's exotic seeds for the greenhouse, the
brass sprinkler line's completion, and the almanac (collections) to fill. No prestige loop
(DECISIONS 008 stands).

---

## 4. Unlocks: the mechanism

The one new system that fixes "everything at once". Built first (Stage 10).

- **An unlock is a name** (`&"woods"`, `&"forge_open"`, `&"sprinklers"`). The game keeps a
  saved list of the ones earned (`GameState.unlocks`).
- **Requests give unlocks** as a reward: `QuestDef.reward_unlocks`, alongside gold and items.
- **Anything can require one:** items in shops, upgrades, requests, locations (the woods,
  the greenhouse), characters (Ivy appears), calendar events. One field each:
  `requires_unlock`.
- **Some unlocks come from the calendar** rather than a request (`first_day` already does
  this for requests; the same idea for shops: "the forge opens on day 8").
- **The morning summary says what's new** ("Hollis has new seeds in"), so the player always
  knows something opened.
- **Old saves** get every unlock that their progress implies, so nobody loses access to
  something they already had (save version 10).

Rule for writing content: **an unlock is announced by a person or the notice board, never
silently.**

---

## 5. Questlines per person

Each line is 4–6 requests, offered one at a time (the system already does that), spread
across the year with `first_day`, seasons and unlocks. Lines already built are marked
*(exists)*. New request *kinds* need a goal script; they're listed in section 5.9.

### 5.1 Mayor Bramble — the valley's revival (the spine and the tutorial)

1. **First pull** — bring 5 parsnips (replaces "sell 200g" as the opener; teaches the loop).
   → 50g, **[unlock]** Hollis's spring stock.
2. **The mayor's welcome** — sell 200g of produce *(exists, moves to day 4+)*. → potato seeds.
3. **The old bridge** — put 500g in the town box (new goal: *donate gold*). → **[unlock]** the Woods, summer.
4. **The pride of the valley** — sell 1,000g *(exists)*. → sundial.
5. **The harvest fair** — enter something at the fair (autumn). → trophy.
6. **Year review** — automatic at Lantern night. → a title and a keepsake decoration.

### 5.2 Mabel the baker — baking, then cooking

1. Parsnip cakes — 5 parsnips *(exists)*.
2. Pasties — 5 potatoes *(exists)*.
3. Summer tarts — 6 strawberries or blueberries (new: *deliver any of*).
4. **Kitchen lessons** — bring the ingredients for her three favourite dishes → **[unlock]**
   the farmhouse kitchen and those three recipes (if cooking is in; otherwise a sprinkler).
5. Pumpkin pie — 1 pumpkin *(exists)* → sprinkler.
6. Winter pies — 5 leeks for leek pies → a recipe book (more recipes).

### 5.3 Pip — curiosity and discovery

1. Strawberries — harvest 3 *(exists)*.
2. **Mushroom hunt** — find 3 different mushrooms in the woods (new: *forage*). → a field
   guide that shows forage spots on the map for a day.
3. **The biggest fish** — catch any fish over a size (if fishing is in). → a fishing lure.
4. **The giant pumpkin** — grow one (new: *harvest giant*). → **[unlock]** giant crops explained, plus a rare seed.
5. **Snow farmer** — build a snowman (a winter decoration placed on the farm). → a festive decoration.

### 5.4 Brann the blacksmith — tools and sprinklers

1. **Prove the farm** — sell 300g (the forge opens; wide tools on sale before this).
   → **[unlock]** great tools.
2. **The sprinkler design** — 20 timber + 200g. → **[unlock]** sprinklers.
3. **Better pipes** — 40 timber + 600g + something from the woods. → **[unlock]** big sprinklers.
4. **Sickle work** — bring 30 weeds' worth of fibre (new item from weeding). → the sickle (harvests and weeds in an area).
5. **The brass sprinkler** — winter; big gold cost + rare forage. → **[unlock]** brass sprinkler (24 tiles).

### 5.5 Wren the angler — fishing (only if fishing is in)

1. **Worms** — bring 5 worms (forage in the woods after rain). → the fishing rod.
2. **Something for supper** — catch 3 fish. → bait.
3. **The river fish** — catch one in the woods' stream. → a better rod (faster bite).
4. **Ice and patience** — catch a fish through the ice in winter. → a winter lure.
5. **The old one** — the pond's legendary fish (year 2). → a trophy decoration.

### 5.6 Hollis (seeds) — variety

1. **One of everything** — ship one of each spring crop (new: *ship variety*). → **[unlock]** summer catalogue early + rhubarb crowns.
2. Summer set — one of each summer crop. → **[unlock]** sunflowers/corn early, chilli seeds.
3. Autumn set. → garlic and the year-2 rare catalogue.

### 5.7 Rosa (market) — orders

Repeatable **market orders** after Rosa's intro request: a crop, a count and a deadline (the
next market day), paying 150% of the bin. Drawn from what's in season. New goal kind:
*deliver by a deadline*. Two or three on offer at once, so the player chooses.

### 5.8 Ivy (new) — the greenhouse

New character, by the ruined glasshouse. A three-part restoration through autumn:
1. 50 timber (clearing). 2. 1,500g. 3. One of each autumn crop plus a fish or forage item.
→ **[unlock]** the greenhouse: a small indoor plot that ignores seasons. Later requests from
Ivy are about perennials (apple trees, rhubarb) and exotic seeds.

### 5.9 Notice board — help wanted

After the first week, the notice board posts one small **daily job** chosen from templates
("Marlow needs 4 cabbages today", "Wren wants 2 worms"), worth a little gold. These keep
every day worth a trip to town once the story lines are waiting on growth.

### New request kinds (goal scripts) these lines need

| Goal | Used by | Notes |
|---|---|---|
| Donate gold | Mayor's bridge, Brann, Ivy | Hands over gold, no items. |
| Deliver any of | Mabel's tarts | A list of accepted items. |
| Ship variety | Hollis | One of each item in a list, counted from shipping. |
| Forage / catch | Pip, Wren | Counted from new EventBus signals the activities emit. |
| Harvest giant | Pip | From the giant crop's harvest signal. |
| Deadline | Rosa's orders, daily jobs | A `deadline_days` field on any request: it expires, no penalty but lost reward. |

---

## 6. Crops

Today: 8 crops, two mechanics (single, regrowing). Proposal: about 25, with **eight new crop
rules**, each a small field on `CropDef`. Existing crops keep working unchanged.

### 6.1 New crop rules

| Rule | Field (sketch) | What it does | Why it's interesting |
|---|---|---|---|
| **Bunches** | `harvest_min/max` | Gives 1–3 per harvest | Spiky luck, good for orders |
| **Trellis** | `solid = true` | Can't walk through it | Layout matters: leave paths |
| **Perennial** | `perennial = true` | Doesn't die at the turn; sleeps out of season and comes back next year | Planting for next year |
| **Overwintering** | `plant_seasons` | Planted in one season, grows through others (garlic: plant autumn, harvest spring) | Long-term planning across the turn |
| **Hardy** | `needs_water = false` | Grows without water | Cheap filler for the far field |
| **Water-loving** | `near_water = true` | Only plantable next to the pond or stream | Uses the pond field |
| **Weather-loving** | `weather_bonus` | An extra growth step on heatwave (or rain) days | Weather becomes good news sometimes |
| **Giant** | `giant_sprite` | A 3 × 3 block of ripe crops may merge into one giant one | A goal and a festival winner |
| **Seed-returning** | `seed_return` | Harvest gives a seed back sometimes | Self-sustaining crops |
| **Flower** | (`ItemDef` tag) | Feeds bees, counts for the flower show | Ties to bees and festivals |

### 6.2 The proposed crop list

Numbers are **first guesses** for the balance pass, roughly in line with today's
(parsnip 20g → 35g in 4 days). ★ = exists. 🎨 = needs Pixellab art (growth strip, produce
icon, seed packet: about 2–3 generations each; trees and giants more).

**Spring**

| Crop | Seed | Days | Sells | Rule | Where | Art |
|---|---|---|---|---|---|---|
| Parsnip ★ | 20 | 4 | 35 | — | Hollis | done |
| Radish ★ | 10 | 3 | 20 | — | Hollis | done |
| Potato ★ | 30 | 6 | 60 | — (spring, summer) | Hollis | done |
| Strawberry ★ | 100 | 8, then 3 | 40 | regrow | Fennel | done |
| Spring onion | 15 | 3 | 12 ×1–3 | bunches | Hollis | 🎨 |
| Pea | 60 | 7, then 2 | 20 | trellis, regrow | Hollis (unlock) | 🎨 |
| Rhubarb | 150 | 14, then 4 | 70 | perennial, regrow | Hollis line reward, then Hollis | 🎨 |
| Tulip | 25 | 6 | 45 | flower | Hollis | 🎨 |
| Garlic | 40 | 18 (autumn → spring) | 110 | overwinters | Hollis (autumn) | 🎨 |

**Summer**

| Crop | Seed | Days | Sells | Rule | Where | Art |
|---|---|---|---|---|---|---|
| Green bean ★ | 50 | 8, then 3 | 15 → **25** | regrow, **trellis** | Hollis | done (beans are weak today; suggest 25g) |
| Melon ★ | 120 | 12 | 250 | **giant** | Fennel | done + 🎨 giant |
| Tomato | 60 | 10, then 3 | 35 | regrow | Hollis | 🎨 |
| Corn | 120 | 12, then 4 | 50 | regrow, summer + autumn, solid | Hollis (unlock) | 🎨 |
| Sunflower | 40 | 8 | 70 | hardy, seed-returning, flower | Hollis | 🎨 |
| Chilli | 70 | 9, then 3 | 30 | regrow, heatwave-loving | Hollis line reward | 🎨 |
| Blueberry | 120 | 12, then 4 | 20 ×2–4 | regrow, bunches | Fennel | 🎨 |
| Watercress | 30 | 4 | 60 | water-loving | Hollis | 🎨 |

**Autumn**

| Crop | Seed | Days | Sells | Rule | Where | Art |
|---|---|---|---|---|---|---|
| Pumpkin ★ | 140 | 12 | 280 | **giant** | Fennel | done + 🎨 giant |
| Cabbage ★ | 60 | 9 | 120 | — (autumn, winter) | Hollis | done |
| Beetroot | 25 | 5 | 50 | — | Hollis | 🎨 |
| Cranberry | 150 | 10, then 3 | 25 ×1–3 | regrow, water-loving | Fennel | 🎨 |
| Leek | 50 | 8 | 90 | — (autumn, winter) | Hollis | 🎨 |
| Apple tree | 600 sapling | 28 to establish, then every 3 | 60 ×3 | perennial, hardy once grown, a tree (2 × 2) | Fennel | 🎨 4 seasons |

**Winter**

| Crop | Seed | Days | Sells | Rule | Where | Art |
|---|---|---|---|---|---|---|
| Parsnip ★ | — | — | — | (already grows in winter; suggest spring/autumn only, winter is for hardy crops) | | |
| Kale | 40 | 6 | 60 | — | Hollis | 🎨 |
| Brussels sprouts | 80 | 15 | 200 | — (autumn, winter) | Hollis | 🎨 |
| Snowdrop | 20 | 5 | 40 | flower | Hollis | 🎨 |

That's **18 new crops** (≈45 Pixellab generations) plus 2 giant sprites. If that's too much
art in one go, the first wave is the ones whose *rule* is new: spring onion, pea, rhubarb,
garlic, sunflower, watercress, corn, kale (8 crops, ≈20 generations). The rest are data once
the rules exist.

---

## 7. Hazards

Each hazard is a small overnight rule, tuned in `game_rules.tres`, scaled by a new
**`hazard_multiplier`** on `DifficultyDef` (Relaxed 0 or 0.5, Standard 1, Hard 1.5), and
each has a counter.

| Hazard | When it starts | What it does | Counter | Art |
|---|---|---|---|---|
| **Thirst** | Day 1 | A crop unwatered for **2 nights wilts** (shown), a 3rd night and it dies. Rain counts as watering. | Watering, sprinklers, rain | wilted look by tint, no Pixellab |
| **Weeds** | Spring day 6 | Each night a few weeds sprout on tilled soil and grass near crops. A weed on a crop's tile stops it growing. Empty tilled soil slowly reverts to grass. | Pull with E (1 energy) or the hoe; the sickle clears an area. Weeds give **fibre** (Brann wants it) | 🎨 weeds, 4 seasonal looks |
| **Crows** | Spring day 15 | If you have more than ~16 unprotected crops, a crow takes one or two overnight. You see the crow and a pecked patch in the morning. | **Scarecrow** protects a radius (8 tiles). This gives DECISIONS 039's scarecrow a real job | 🎨 crow (small animated) |
| **Pests** | Autumn day 1 | One crop gets aphids; each night they spread to a neighbour and stop growth there. | Pest spray (Marlow), or pull the plant. Flowers nearby slow the spread | 🎨 aphid overlay |
| **Storm** | Summer onwards (weather) | Tall unfenced crops (corn, sunflower, trellis) may be flattened. Crows stay away. | Fences next to them | none (rain overlay by script) |
| **Heatwave** | Summer (weather) | Unwatered crops wilt after 1 night instead of 2. | Sprinklers; chilli loves it | none (warm tint) |
| **Frost** | Autumn day 27 | Tender crops die a night early (warned on day 25). | Harvest early; hardy crops survive | none |

**Weather** itself (Stage 11): each day is sunny, rainy, stormy, hot or snowy, chosen at
night from the season's odds in `SeasonTheme` (data). Tomorrow's weather is on the notice
board and the morning summary. Rain waters the whole farm (a free day); snow is just look.
Rain and storm are a falling-drops overlay like the snowfall that exists.

---

## 8. Tools, upgrades and farm buildings

| Item | What it does | How you get it | Art |
|---|---|---|---|
| **Sickle** (new tool, 3 tiers) | Harvests and clears weeds in an area, like the hoe's tiers | Brann's line | 🎨 icon |
| **Axe** (new tool) | Clears thicket by hand, tile by tile, for **timber**. Fields can still be bought outright; chopping is the cheap, slow alternative and the timber source | Marlow, spring week 2 | 🎨 icon, timber icon |
| Fishing rod (2 tiers) | Fishing | Wren's line | 🎨 icon, bobber |
| Brass sprinkler | 24 tiles | Brann's last request | 🎨 |
| **Fertiliser** (2 kinds) | Growth: one stage faster. Mulch: soil stays wet an extra night | Marlow; Ivy's line | 🎨 2 icons |
| Pest spray | Kills aphids on a tile | Marlow (autumn) | 🎨 icon |
| **Bee hive** | Placeable; makes honey every few days, more with flowers within 4 tiles | Ivy or Marlow, summer | 🎨 hive, honey icon |
| **Greenhouse** | A building on the farm with a 6 × 8 plot inside; ignores seasons and weather | Ivy's line | 🎨 exterior (+winter), interior |
| **Kitchen** | Cook recipes at the farmhouse table | Mabel's line | 🎨 stove |
| Bag upgrades | Only worth it if the bag gets a size limit; to check when Stage 12 adds many more items | — | — |
| Watering-can capacity | *Considered, not recommended*: refilling at the pond is a chore that doesn't add choices | — | — |

---

## 9. Other activities

Each was ruled out in `DESIGN.md`'s "Explicitly out of scope". Bringing any back is Dave's
call, and each reverses a recorded decision. My recommendation for each:

| Activity | Recommend | What it adds | Cost | Reverses |
|---|---|---|---|---|
| **Foraging** (the Woods) | **Yes** | A reason to leave the farm; early income without energy (costs time instead, which the clock now makes meaningful); quest items; timber. Daily spawns per season. | New location map (Pixellab tileset), ~16 forage icons, a spawn script | DESIGN "no foraging areas" |
| **Fishing** with Wren | **Yes** | Fills afternoons and winter; a light skill element (a timing bar, not twitchy); fish for quests and cooking; Wren's story. | A minigame (one new scene), ~15 fish icons, rod, bobber; fish data per place/season/time/weather | DESIGN "no fishing" |
| **Cooking** | **Yes, energy food only** | Food restores energy: a new lever on the game's main brake. Recipes are rewards. No machines, no sell-for-profit chains. | Recipe resources, an eat action, ~12 dish icons | DECISIONS 006 (no processing), narrowly |
| **Bees** | Yes, small | Passive income that rewards flowers in the layout. Animal-lite: no feeding, no animation beyond a few bees. | Hive object, honey item | — |
| **Festivals** | **Yes** | Four set-piece days a year; each a small activity on existing systems (judging is "highest value item handed in"; the fishing contest is "biggest fish by 2 PM"). | CalendarEvents exist; decorations and a judge's dialogue | — |
| **Collections** (almanac) | Yes, late | Completion goal: every crop shipped, fish caught, forage found, recipe cooked. A book with greyed-out entries. | One UI screen | — |
| **Townsfolk walking about** | Yes, late | Life in town (they currently stand still). Simple schedules: a spot per time slot. | Walk cycles for 7 characters (🎨 animation) | — |
| **Friendship / gifts** | **No** | Overlaps with questlines; adds a numbers system for little play. The questlines *are* the relationships. | — | — |
| **Animals** (coop, barn) | **No, for now** | Big: buildings, feeding, produce, animation. Bees cover the "something alive on the farm" itch. Revisit after release. | Large | DECISIONS 007 |
| Mining / combat | **No** | Different game. | — | — |
| Quality tiers | **No** | DECISIONS 006 still holds. | — | — |

---

## 10. The stages to build it

Stage 9's session 1 (feel) is done and stays. Its unfinished half (title screen, settings,
save slots, the balance pass, export) moves to the **last** stage. Each stage below is sized
like the existing ones: one or two sessions of code, then an art session from the cloud
environment where Pixellab is involved. Art can lag code (placeholder first, as every stage
so far has done).

| Stage | Name | Sessions | Model | Save | Pixellab art |
|---|---|---|---|---|---|
| **10** | **Pacing and unlocks** | 2 | Opus | v10 (unlocks) | none |
| **11** | **Hazards and weather** | 2 | Opus, then Sonnet | v11 (wilt days, weeds, weather) | weeds ×4 seasons, crow, aphids |
| **12** | **Crops with rules** | 2 + art | Opus, then Sonnet | v12 (perennials, giants) | first wave 8 crops, then 10 more + 2 giants |
| **13** | **Questlines** | 2 | Sonnet (Haiku for bulk text) | maybe none | Ivy |
| **14** | **The Woods and foraging** | 2 + art | Opus, then Sonnet | v13 (forage spots, axe/timber) | woods tileset, bridge, ~16 forage icons, axe, timber |
| **15** | **Fishing with Wren** | 1–2 + art | Opus | v14 (fish log) | ~15 fish icons, rods, bobber, ice hole |
| **16** | **Kitchen and cooking** | 1 + art | Sonnet | v15 (recipes known) | stove, ~12 dish icons |
| **17** | **Greenhouse, bees, late tools** | 2 + art | Sonnet | v16 (greenhouse plot) | greenhouse in/out, hive, honey, brass sprinkler, sickle, fertiliser |
| **18** | **Festivals** | 1–2 | Sonnet | none (worked out from the date) | festival decorations, trophy |
| **19** | **Almanac, year review, life in town** | 1–2 | Sonnet | v17 (collections) | walk cycles (optional) |
| **20** | **Balance and release** (old Stage 9 s2) | 2 | Opus for balance | — | title screen art |

About 18–22 sessions plus art sessions. **Playtest checkpoints:** Dave plays one spring after
Stage 10 (pacing), and one full year after Stage 13 (the core game). Stages 14–19 are
independent enough to reorder or drop.

### What each stage contains

**Stage 10 — Pacing and unlocks.** The unlock system (section 4). `requires_unlock` on items,
upgrades, requests, locations, characters, events; `reward_unlocks` on requests. Shops
show only unlocked stock. The forge opens on day 8. Rewrite the first week as in section 3
(mayor's "first pull" opener, staggered `first_day` for everyone else, Hollis's stock
gated). The morning summary announces unlocks. Old saves get the unlocks their progress
implies. *Verification:* a scripted run through spring days 1–15 checking exactly what's
offered each morning. *Why first:* it's the cheapest fix for the biggest complaint, and
every later stage's content plugs into it.

**Stage 11 — Hazards and weather.** Session 1: thirst/wilting, weeds (+ fibre), crows and
the working scarecrow, `hazard_multiplier` on difficulty. Session 2: weather (rain, storm,
heatwave, snow days) with odds per season, tomorrow's forecast, rain overlay and sounds,
frost; pests if time allows (else into Stage 12). *Why second:* new crops' rules (hardy,
heat-loving, solid) only mean something once there's weather and thirst.

**Stage 12 — Crops with rules.** Session 1: the new `CropDef` fields and the first wave of
eight crops on placeholder art; Hollis's catalogue by season and unlock. Session 2:
perennials (and the apple tree), giant crops, the remaining crops. Art sessions in between.

**Stage 13 — Questlines.** The new goal kinds (donate, any of, variety, deadline, giant,
forage/catch stubs), then every line in section 5 written as data, with Ivy as a new
character. Rosa's market orders and the notice board's daily jobs (both templates).
Mostly writing, so a cheaper model.

**Stage 14 — The Woods and foraging.** The bridge (a gate unlocked by the mayor), a new
location, forage spots that refill per season, the axe and timber (chopping thicket and
fallen logs). The woods' stream is ready for fishing.
Suggested size (2026-11-16): about 48 × 32 tiles, bigger than the town (40 × 24) so it
feels like exploring; the bridge at the top of the town's pond path, which already runs
north past Brann's. The farm (30 × 20) and town stay as they are.

**Stage 15 — Fishing.** The rod, a cast-and-timing minigame, fish as data (place, season,
time of day, weather, size), Wren's line wired up, the summer contest hook.

**Stage 16 — Kitchen and cooking.** Recipes as resources (ingredients → dish, energy
restored), cook at the farmhouse, eat from the hotbar, Mabel's lessons and recipe rewards.

**Stage 17 — Greenhouse, bees and late tools.** The greenhouse as a building with an indoor
plot that ignores seasons (reuses the farmhouse pattern), bee hives, fertilisers, the
sickle's tiers, the brass sprinkler.

**Stage 18 — Festivals.** Spring flower show, summer fishing contest, autumn harvest fair,
winter lantern night, as `CalendarEvent`s with a judge and a prize each.

**Stage 19 — Almanac, year review, life in town.** The collections book, the mayor's year
review and title, year-2 content switches, and (optional) townsfolk walking between spots
on a schedule.

**Stage 20 — Balance and release.** The original Stage 9 session 2 list: title screen,
settings with volume, save slots, the full balance pass across a simulated year (now worth
doing, because the content exists), Windows export, itch.io page. Dave noticed the clock
seems slow (2026-11-15; set to 5 on 2026-11-16, DECISIONS 051): the pass checks the clock's pace (`seconds_per_ten_minutes`)
against how long a day's work really takes once hazards and activities exist, and that it
keeps a steady pace through the day.

---

## 11. Pixellab art summary

Rough generation counts, assuming the methods that worked so far (one pixflux generation per
growth strip or icon strip of four; DECISIONS 041). The Pixellab subscription is out and
there's about $10 of credit, so the art will need a top-up, Dave's own generations, or
fewer crops.

| Stage | Art | ≈ Generations |
|---|---|---|
| 11 | weeds (4 seasons), crow (animated, small), aphids | 8–10 |
| 12 | 18 crops × (strip + icon + packet), 2 giants | 45–50 |
| 13 | Ivy | 2–3 |
| 14 | woods tileset (4 seasons by image-to-image), bridge, forage icons ×16, axe, timber | 20–25 |
| 15 | fish ×15, rods, bobber, ice hole | 6–8 |
| 16 | stove, dishes ×12 | 4–5 |
| 17 | greenhouse (outside, winter, inside), hive, honey, sickle, fertiliser, brass sprinkler | 10–12 |
| 18 | festival decorations, trophy | 5–8 |
| 19 | walk cycles ×7 (optional, Dave's animation workflow) | 7–14 |
| 20 | title screen | 2–3 |

---

## 12. Decisions for Dave

**Answered 2026-11-15: Dave agreed every recommendation below.**

1. **The arc:** is section 3's year roughly the game you want? (Recommended: yes.)
2. **Hazards:** all of thirst, weeds, crows, pests, storms, heatwaves, frost? Or a lighter
   set (thirst, weeds, crows)? (Recommended: all, with Relaxed switching most off.)
3. **Crop death by thirst:** after 2 dry nights wilt, 3 dies? (Recommended: yes on Standard,
   never on Relaxed.)
4. **Foraging and fishing:** reopen DESIGN.md's out-of-scope list for these two?
   (Recommended: yes, both.)
5. **Cooking as energy food only?** (Recommended: yes; no selling chains.)
6. **Animals:** stay out? (Recommended: yes, bees instead; revisit after release.)
7. **Crop count:** all 18 new crops, or the first wave of 8? (Recommended: first wave in
   Stage 12, the rest as art budget allows.)
8. **New character Ivy** for the greenhouse, or give that line to an existing person
   (Marlow or Hollis) to save art? (Recommended: Ivy, the town needs one more face.)
9. **Stage order:** 10 → 20 as in section 10. (Recommended: yes; 14–19 can be reordered.)

`STAGES.md` and `DESIGN.md` were updated to match on 2026-11-15. Next: Stage 10.
