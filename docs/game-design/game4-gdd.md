# Egg Garden: game design spec (v0.1)

Status: draft for SHANNON. Concept D in `game4-concepts.md`. Needs decision record 0008 (economy, remotes, save schema; CLAUDE.md rule 8) and a task file before build.

## A. Product

- **Pitch:** plant creature eggs in your garden. They grow in real time, even while you are offline. Hatch them when ripe; if a weather event is on, the creature may come out Golden, Moonlit or Rainbow. Your creatures live in your garden and fill coin pads every second; walk over the pads to collect, buy better eggs at the egg cart, and complete the Garden Index.
- **Audience:** players under 18. Roblox's built-in filtered text chat stays on. No custom chat, no text input, no personal data beyond the saved game profile.
- **Platforms:** PC, mobile, console. Walk, jump, and ProximityPrompts (`E`, gamepad X, tap) for every world action; menus for the rest.
- **Pillars:**
  1. A hatch reveal within 10 seconds of pressing PLAY.
  2. Always something to do now (collect, water, hatch) and something waiting later (a ripe Moon Egg tomorrow).
  3. Complete alone; other players only ever help you (watering, likes). Nothing anyone does can take what you own.
  4. Bright, detailed and alive in the first screenshot.
  5. Fair and open odds: every chance is on screen, the Lucky Meter guarantees the top creature, and nothing costs real money.
- **Non-goals:** stealing, trading, gifting, Robux or paid items (decision 0002), custom chat, rebirth, pets that follow you, combat, more than one map.
- **Server size:** 6 players, 6 garden plots.

## B. Core loop

1. **Collect:** each creature placed in your pen fills its own coin pad every second. Walk over a pad to bank it.
2. **Buy:** at the egg cart in the plaza, buy an egg. It is planted at once in your first empty bed.
3. **Grow:** the egg ripens in real time (section D), online or offline. Water it to speed it up.
4. **Hatch:** at a ripe egg, use the `Hatch` prompt. Species, mutation and size are rolled (section E) and the creature appears on a free pad (or in storage).
5. **Improve:** with more coins, buy beds, pen slots and higher egg tiers; release weaker creatures; fill the Index for a permanent income bonus.

Target pacing (hypothesis): Forest Eggs in the first 3 minutes, Sunset Eggs in the first 20, Moon Eggs on day 2, Star Eggs by day 5.

## C. Garden plot

Each player in the server is given the lowest-numbered free plot (1 to 6) on join and spawns at its gate. The saved garden is position-independent and is rebuilt on whichever plot the player gets. Rules live in `GardenRules`.

### C1. Beds

- Start with 3 beds, maximum 12. A bed is empty, **growing** or **ripe**.
- Bed `n` costs (coins): 4: 500; 5: 2,000; 6: 8,000; 7: 25,000; 8: 75,000; 9: 200,000; 10: 500,000; 11: 1,200,000; 12: 3,000,000. `buyBed` buys the next one in order.
- Ripe eggs never spoil and wait as long as needed.

### C2. Pen and storage

- **Pen:** start with 6 pads, maximum 20. Placed creatures earn; one creature per pad.
- Pen slot `6 + k + 1` (k = 0 to 13) costs `300 × 2^k` coins: slot 7 300, 8 600, 9 1,200, 10 2,400, 11 4,800, 12 9,600, 13 19,200, 14 38,400, 15 76,800, 16 153,600, 17 307,200, 18 614,400, 19 1,228,800, 20 2,457,600.
- **Storage:** 60 creatures, which do not earn. `place(id)` moves storage to pen if a pad is free; `store(id)` moves pen to storage if storage has room.
- **Favourite:** `favourite(id)` toggles a lock. Favourites cannot be released.

### C3. Income

- Creature rate: `rate = baseRate(species) × mutationMult × sizeMult` (tables in E).
- Index bonus: `indexMult = 1 + 0.02 × indexCount` (0 to 36 entries, so up to ×1.72).
- Garden income: `income = (sum of rate over placed creatures) × indexMult`. Shown on the HUD and on the garden sign.
- **Pads (online):** each placed creature's pad accrues `rate × indexMult` per second (fractions kept, no cap). The server checks each player's root at 5 Hz: a pad whose centre is within 4.5 studs horizontally and 6 studs vertically is **banked**: `floor(pending + 1e-9)` coins added, the fraction stays. Only the owner banks their own pads.
- **Nothing is lost:** on leave, all pads are banked. The autosave every 60 s also stores the unbanked total (`unbanked`) and `lastSeen`; on the next load `unbanked` is added to coins.
- **Offline:** on load, `offline = floor(income × 0.5 × min(away, 28,800) + 1e-9)` with `away = max(0, now − lastSeen)` seconds and `income` from the saved garden. Paid at once and shown in a "While you were away" card. Offline pays half rate for up to 8 hours, so being online is always better.
- **Check values:** a Big Golden Berry Cat (12 × 3 × 1.5 = 54) and a Normal Sprout Bunny (1) with 5 Index entries: income `55 × 1.10 = 60.5` coins/s. Away 1 hour: 108,900 coins. Away 10 hours: 871,200 (capped at 8 h).

### C4. Release

- `release(id)`: removes the creature and pays `floor(rate × 6 + 1e-9)` coins (rate without the Index bonus; was × 30, changed by the decision 0008 amendment of 2026-10-26 so buying, hatching and releasing returns at most 60% of an egg's price). Refused for favourites. The client asks for confirmation ("Release Berry Cat to the wild meadow? +324 coins"). The Index entry stays.
- Released creatures run off through the Wild Meadow gate in the plaza (cosmetic).

## D. Eggs, growing and watering

### D1. Egg table

| Id | Name | Price | Grow time | Unlock | Stock per restock window |
|---|---|---|---|---|---|
| `starter` | Starter Egg | – (free, once) | 8 s | new profile | – |
| `meadow` | Meadow Egg | 50 | 30 s | Level 1 | always in stock, unlimited |
| `forest` | Forest Egg | 400 | 3 min | Level 2 | 100% chance, 2–4 |
| `sunset` | Sunset Egg | 3,000 | 15 min | Level 5 | 60% chance, 1–2 |
| `moon` | Moon Egg | 25,000 | 1 h | Level 10 | 30% chance, 1 |
| `star` | Star Egg | 200,000 | 4 h | Level 18 | 10% chance, 1 |

- **Restock:** window `s = floor(unix / 300)` (every 5 minutes, the same for every server). For egg index `i` (forest 2, sunset 3, moon 4, star 5), `state = Rng.seed(s, 9001, i)`; `r = Rng.int(state, 1, 10000)`; in stock if `r ≤ chance × 100`; then quantity `Rng.int(next state, min, max)`. Stock is **per player**: each player can buy that many of each egg in that window, so nobody competes for stock.
- `buyEgg(id)` is accepted when the player is within 25 studs of the egg cart (server position), the egg is unlocked by level, the player's buys this window are below the stock, coins ≥ price, and a bed is empty. The egg is planted in the lowest-numbered empty bed: `planted = now`, `ready = now + growTime`.

### D2. Watering

- `Water` prompt on a growing bed (any player whose gate rules allow, section G). Accepted when the bed is growing, at least 60 s have passed since the last water on that bed (by anyone), and the caps below are not reached. The waterer's root must be within 12 studs of the bed.
- Each water: `ready = max(now, ready − floor(0.05 × growTime))`. Meadow −1 s, Forest −9 s, Sunset −45 s, Moon −180 s, Star −720 s.
- Caps per egg: 5 waters by the owner, 3 more by other players ("helpers"). At most 40% of the grow time can be watered away. Example: a Moon Egg watered 8 times ripens in 2,160 s instead of 3,600.
- Rewards: owner water 3 XP; helper water 15 XP to the helper (rewarded for the first 20 helper waters per UTC day; after that, watering still helps but pays nothing). The owner sees "Mia watered your Moon Egg!".

### D3. Hatching

- `Hatch` prompt on a ripe bed, owner only, root within 12 studs. Refused if pen and storage are both full (message: "Your garden is full: release or store a creature").
- The roll (section E) uses the weather active at the moment the server accepts the hatch. The bed becomes empty. The creature goes to the lowest free pad, else storage.
- Reveal (client): the egg wobbles for 1.5 s, cracks, the creature pops out with a burst in its rarity colour, name, rarity, mutation and size. Fast Hatch setting: 0.4 s. **No near-miss animation:** the reveal never flashes or spins through other creatures.

## E. Creatures, rarity and odds

All rolls use `Rng` (`src/shared/Rng.luau`) with state passed in, so tests are deterministic. The server seeds each roll from `Random.new()` so players cannot predict outcomes. Each roll is `r = Rng.int(state, 1, 10000)`, walking the table in the listed order and taking the first outcome whose cumulative basis points reach `r`.

### E1. Species

| Id | Name | Rarity | Base rate (coins/s) | Release value (Normal) |
|---|---|---|---|---|
| `bunny` | Sprout Bunny | Common | 1 | 6 |
| `frog` | Toadstool Frog | Common | 2 | 12 |
| `pup` | Bumble Pup | Uncommon | 5 | 30 |
| `cat` | Berry Cat | Uncommon | 12 | 72 |
| `owl` | Pumpkin Owl | Rare | 30 | 180 |
| `fox` | Cactus Fox | Rare | 70 | 420 |
| `turtle` | Lotus Turtle | Epic | 180 | 1,080 |
| `lion` | Sunflower Lion | Legendary | 500 | 3,000 |
| `dragon` | Moonblossom Dragon | Mythic | 1,500 | 9,000 |

Rarity colours: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic pink.

### E2. Species odds per egg (basis points, each row sums to 10,000)

| Egg | Outcomes | Lucky Meter (top species guaranteed by hatch n) |
|---|---|---|
| `starter` | Bumble Pup 10000 (fixed, Normal, Normal size) | – |
| `meadow` | Sprout Bunny 6000, Toadstool Frog 3000, Bumble Pup 900, Berry Cat 100 | Berry Cat by 50 |
| `forest` | Toadstool Frog 4000, Bumble Pup 3500, Berry Cat 2000, Pumpkin Owl 500 | Pumpkin Owl by 30 |
| `sunset` | Berry Cat 4500, Pumpkin Owl 3500, Cactus Fox 1700, Lotus Turtle 300 | Lotus Turtle by 40 |
| `moon` | Cactus Fox 5000, Lotus Turtle 4000, Sunflower Lion 950, Moonblossom Dragon 50 | Moonblossom Dragon by 100 |
| `star` | Lotus Turtle 5500, Sunflower Lion 4000, Moonblossom Dragon 500 | Moonblossom Dragon by 25 |

**Lucky Meter (pity):** `pity[egg]` counts hatches of that egg since its top species last hatched. If `pity[egg] ≥ meter − 1`, the species is the top species without a roll. After the hatch, `pity[egg] = 0` if the species is the top species, else `+1`. The meter is shown on each egg ("Lucky Meter 37 / 100").

Expected income per hatch at base rates (for balancing, not shown): Meadow 1.77, Forest 6.45, Sunset 33.2, Moon 162, Star 374 coins/s.

### E3. Mutations (rolled by the weather at hatch time, basis points)

| Weather | Normal ×1 | Golden ×3 | Moonlit ×5 | Rainbow ×10 |
|---|---|---|---|---|
| Clear | 9790 | 200 | 0 | 10 |
| Sunbeam | 7450 | 2500 | 0 | 50 |
| Moonfall | 7750 | 200 | 2000 | 50 |
| Rainbow Shower | 8500 | 500 | 0 | 1000 |

### E4. Sizes

Normal ×1.0 (8000), Big ×1.5 (1700), Huge ×2.5 (300). Model scale 1.0, 1.4 and 2.0.

### E5. Garden Index

- 36 entries: 9 species × 4 mutations, key `"<species>:<mutation>"`. An entry is discovered at its first hatch and kept forever (also after release).
- Each new entry: +50 XP and +2% income (C3). Undiscovered entries show as silhouettes with the eggs and weather that can produce them.

### E6. Published odds (in game)

- Every egg on the cart has an **ODDS** button (a labelled text button, not a bare icon) listing each species with its percentage (two decimals; totals 100%), the Lucky Meter, size odds, and the mutation table for the current weather.
- The forecast board and the Index show the mutation table for every weather.
- Odds never change except by the published weather table and the weekend table (section F). There are no luck boosts.

## F. Weather (server-wide, scheduled)

- Window `w = floor(unix / 600)` (10 minutes). A weather event is active for the first 300 s of the window; the rest is Clear. Every server shows the same weather at the same time.
- `state = Rng.seed(w, 4242)`, `r = Rng.int(state, 1, 10000)`:

| Day (UTC) | Clear | Sunbeam | Moonfall | Rainbow Shower |
|---|---|---|---|---|
| Monday–Friday | 5500 | 2500 | 1500 | 500 |
| Saturday, Sunday ("Weekend Bloom") | 3500 | 3500 | 2000 | 1000 |

- Weekday from the window start: `d = floor(unix / 86400)`, `weekday = (d + 3) mod 7` with Monday 0 (1 January 1970 was a Thursday); Saturday is 5, Sunday 6.
- **Forecast board:** shows the current window and the next two, with a countdown to each event. This turns the wait into a plan: hatch a ripe egg now, or wait 6 minutes for a Rainbow Shower.
- A Rainbow Shower happens on about 1 window in 20 on weekdays (roughly every 3.3 hours) and 1 in 10 at weekends.

## G. Player interaction and child safety

### G1. What other players can do

- **Visit:** walk into any open garden on the server and see its creatures, eggs and sign (owner's display name, income, likes, Index count).
- **Water** a growing egg (D2): helps the owner, pays the helper XP.
- **Like** a garden: `like(userId)`, once per owner per UTC day, at most 30 likes given per day. Adds 1 to the owner's `likes` (shown with a heart on their sign). There is no dislike.
- **Hatch announcements:** a banner to everyone in the server when someone hatches a Legendary or Mythic species, any Rainbow, or any Huge ("Mia hatched a RAINBOW Sunflower Lion!"). Display names only.

### G2. Garden gate (owner setting)

`setGate("open" | "friends" | "closed")`, default `open`. With `friends`, only the owner's Roblox friends (server `IsFriendsWith`, cached per session) can water or like; with `closed`, nobody can. A disallowed player standing inside the plot bounds for more than 1 s is moved to just outside the gate.

### G3. Cut on purpose

- **No stealing.** Children crying over lost Brainrots (concepts G2), exploit pressure (G2), and no fun in a server of one.
- **No trading or gifting.** Scams and off-platform trading are the main harm in the genre (G1, G7). Revisit only with a separate decision record, simultaneous two-sided confirmation, value checks, `PolicyService` checks and moderation support.
- Nothing another player does can remove, lower or move anything you own. The worst they can do is not water your egg.

### G4. Anti-pressure rules (under-18)

1. No Robux, no paid items, no paid odds, no luck boosts (decision 0002).
2. Odds published as in E6 even though Roblox only requires it for paid items (concepts G6).
3. No near-miss reveals, no slot-machine sounds, no "so close!" messages.
4. The Lucky Meter makes the top creature of every egg a certainty within a published number of hatches.
5. Nothing is ever exclusive forever: every species and mutation can be hatched any day; weather and Weekend Bloom repeat on a fixed schedule; the Meadow Egg is always in stock.
6. Offline coins and ripe eggs never expire. No reward is lost for missing a day except the streak count.
7. No "limited offer" pop-ups, no countdowns on anything except the restock and weather boards.

### G5. Anti-exploit

- Every world action is a server-side ProximityPrompt `Triggered` or a `Request` action validated by the pure rules against the server's own profile; the server also checks distance from the player's server-replicated root (cart 25 studs, beds 12 studs).
- Pads are banked by the server's own position check; only the owner's pads. A teleporting exploiter can at most collect their own coins faster.
- Helper XP is capped at 20 helper waters per day; likes are capped at 30 per day and one per owner per day, so alt accounts gain almost nothing.

## H. Meta game (reused and new)

### H1. What is reused, generalised or new

| Piece | Source | Plan |
|---|---|---|
| Daily streak, weekly bonus, daily quests, levels, unlock/buy/equip, sanitise, day/week maths | `MetaRules` (decision 0007; generalised from `src/shared/ProgressRules.luau`) | **Reused** with a garden config. Adds an `index` unlock kind (`indexCount ≥ n`) and an optional `scale(profile, base, minutes)` reward hook; games without it get the base amount, so Relay's and Night's specs are unchanged. If `MetaRules` has not landed when this build starts, this build creates it exactly as decision 0007 specifies. |
| Quest selection (`questsFor`) | `ProgressRules` / `MetaRules` | Reused with an 8-quest pool. |
| Level curve | 0006 | Reused: `floor(sqrt(xp / 40)) + 1`, cap 50. |
| Seeded generator | `src/shared/Rng.luau` | **Reused** for hatch, stock and weather rolls. |
| Profiles: 3-try load, offline mode, `UpdateAsync` re-apply, Request validation, 0.35 s rate limit | `src/relay/Profiles.luau` | **Reused** pattern with store names `GardenProfile<suffix>` and ordered `GardenIncome<suffix>`. |
| Start menu, panels, toasts, gold claim dot, music player, settings | `src/relay-client/Menu.client.luau` | **Forked** into `src/garden-client/Menu.client.luau`; new INDEX and EGGS panels. |
| Mesh loader | `src/relay/Models.luau` | **Reused.** |
| Sakura tree mesh | asset 139101786875815 (registered) | **Reused** as blossom trees. |
| Garden, eggs, hatching, weather, stock, pads | – | **New** pure modules (section N). |

### H2. Start menu and HUD

- **Start menu:** title "EGG GARDEN", tagline "Hatch it. Grow it. Collect them all.", over a slow camera orbit of the plaza and gardens. Buttons: PLAY, INDEX, LOCKER, REWARDS, STATS, SETTINGS. Gold dot on anything claimable (reused).
- **PLAY:** closes the menu; the camera flies to the player's own garden gate.
- **HUD:** coins (short format: 1.2K, 3.4M, 5.6B, 7.8T), income per second, level and XP bar (reused), weather chip (current weather, time left, next two), restock timer, HOME button (teleports to your gate via the `home` request), Index count, gold dot.
- **Egg cart panel** (opens from the cart's prompt): five eggs with price, grow time, stock left this window, unlock level, Lucky Meter, ODDS button, BUY.
- **Garden sign** (world): owner name, income, likes, Index n / 36.
- **First session** (`hatches = 0` at join): the starter egg ripens 8 s after the profile is created. Prompts in order, each disappearing when done: "Your egg is ready! Hatch it" (arrow to bed 1), "Walk over the pad to collect coins", "Visit the Egg Cart" (beam to the cart), "Buy a Meadow Egg", "Water your egg", "Hatch it when it's ripe!". Starting coins 100, so two Meadow Eggs can be bought at once.

### H3. Progression

- **XP:** hatch Starter or Meadow 10, Forest 25, Sunset 60, Moon 150, Star 400; new Index entry +50; own water 3; helper water 15 (D2).
- **Levels** (shared curve). Unlocks: Forest Egg 2 (40 XP), Sunset Egg 5 (640), Moon Egg 10 (3,240), Star Egg 18 (11,560), plus cosmetics.
- **Coins** (soft currency, stored as `coins`) buy eggs, beds, pen slots and cosmetics.

### H4. Cosmetics (Locker)

| Slot | Id | Name | Unlock |
|---|---|---|---|
| fence | `picket` | White Picket (default) | Level 1 |
| fence | `bamboo` | Bamboo | Level 3 |
| fence | `stone` | Cobble Wall | Level 6 |
| fence | `hedge` | Hedge | Level 10 |
| fence | `crystal` | Crystal | Level 16 |
| fence | `golden` | Golden | 20 Index entries |
| fence | `candy` | Candy Cane | 1,000,000 coins |
| fence | `rainbow` | Rainbow | 1,000,000,000 coins |
| can | `tin` | Tin Can (default) | Level 1 |
| can | `ducky` | Rubber Ducky | Level 4 |
| can | `flower` | Flower Pot | Level 8 |
| can | `moon` | Moon Jar | Level 14 |
| can | `star` | Star Pitcher | 10,000,000 coins |
| can | `galaxy` | Galaxy | 10,000,000,000 coins |

The fence style is built around the owner's plot (visible to visitors); the watering can is held while watering and plays its own splash colour.

### H5. Rewards

Reward amounts scale with the garden so they stay worth claiming: `scaled(base, minutes) = max(base, floor(income × 60 × minutes + 1e-9))`, with `income` from the profile at claim time.

- **Daily streak:** days 1–7: base 50, 75, 100, 125, 150, 200, 400; minutes 2, 3, 4, 5, 6, 8, 15; day 7 repeats while the streak holds; a missed day restarts at 1 (reused rule). Check: day 3 at 60.5 coins/s pays 14,520; at 0.5 coins/s pays 120; at 0 pays 100.
- **Weekly bonus:** online on 5 different UTC days, Monday to Sunday: base 500, 30 minutes (reused rule).
- **Daily quests:** 3 a day from this pool, the same for everyone on a UTC day, all completable solo.

| Id | Label | Stat | Goal | Base | Minutes |
|---|---|---|---|---|---|
| `hatch5` | Hatch 5 eggs | hatches | 5 | 100 | 3 |
| `hatch15` | Hatch 15 eggs | hatches | 15 | 150 | 6 |
| `water10` | Water 10 eggs | waters | 10 | 100 | 3 |
| `water25` | Water 25 eggs | waters | 25 | 150 | 6 |
| `collect50` | Collect 50 coin pads | collects | 50 | 100 | 3 |
| `rare1` | Hatch a Rare or better | rareHatches | 1 | 150 | 5 |
| `mutant1` | Hatch a mutated creature | mutants | 1 | 200 | 8 |
| `release3` | Release 3 creatures | releases | 3 | 100 | 3 |

`waters` counts own and helper waters. `collects` counts pad visits that bank at least 1 coin (a pad counts once each time the owner steps onto it; decision 0008 amendment, 2026-10-26).

### H6. Leaderboard, stats, settings, music

- **Leaderboard:** "Top Gardens" board in the plaza: global top 10 by income (`GardenIncome` ordered store, value `floor(income)`, written at most every 120 s when changed; names from `GetNameFromUserIdAsync`, refreshed every 60 s). Session leaderstats: Income (short format) and Index.
- **Stats panel:** level, XP, coins, income, hatches, Index n / 36, best creature, likes, "saving offline" notice when DataStores are unavailable (reused).
- **Settings** (client-only, not saved): music, sound effects, Fast Hatch, hatch announcements on/off, How to Play card, Odds card.
- **Music:** two bright acoustic or ukulele tracks from the Roblox audio library (APM) for normal play, one dreamy track for Moonfall, short stingers when Sunbeam, Moonfall and Rainbow Shower start. To pick and register before use.
- **SFX** (Roblox library, registered before use): egg wobble, crack, pop, rarity fanfares (soft chimes rising with rarity, no slot sounds), coin collect, water splash, like heart, cart buy.

### H7. Saved profile (schema v1, store `GardenProfile<suffix>`)

```
{ schemaVersion, xp, coins, lastSeen, unbanked, nextId, bedCount, penSlots,
  beds = { { egg, planted, ready, waters, helps, lastWater } },   -- one per bed; empty bed: egg = ""
  creatures = { { id, s, m, z, placed, fav } },                    -- species, mutation, size
  pity = { meadow, forest, sunset, moon, star },
  index = { "<species>:<mutation>", ... },
  stock = { w, bought = { forest, sunset, moon, star } },
  hatches, waters, likes, gate, fence, can, owned,
  helped = { day, count }, liked = { day, ids },
  daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }
```

Sanitising (`GardenProgress.sanitize`): numbers floored and clamped (XP 1,000,000; coins and `unbanked` 1e15; counts 1,000,000); `bedCount` 3–12 and `penSlots` 6–20; `beds` trimmed or padded to `bedCount`, a bed with an unknown egg emptied, `ready` clamped to `[planted, planted + growTime]`; creatures with unknown species, mutation or size dropped, at most `penSlots + 60` kept, at most `penSlots` placed (extras unplaced, then oldest dropped past storage); unique `id`s, `nextId` above all of them; unknown `index` keys dropped; `gate` falls back to `open`; `fence` to `picket` and `can` to `tin` if unknown or locked; `owned` keeps only priced cosmetic ids; `lastSeen` in the future becomes now; `pity` clamped 0 to its meter.

Writes use the `UpdateAsync` re-apply pattern (decision 0006). Random outcomes are rolled once on the in-memory profile; the stored-record operation applies that fixed outcome, so re-applying never re-rolls. Operations are coalesced: at most one write per player per 7 s, plus the 60 s autosave (`lastSeen`, `unbanked`, banked coins) and a final write on leave and in `BindToClose`.

## I. World and art plan

### I1. Layout ("Hatchling Valley", all ground level)

Centre (0, 0, 0). North is −Z.

| Feature | Where | Build |
|---|---|---|
| Plaza | centre, radius 45 | Cobblestone with a Brick ring, 8 lamp posts at radius 42 (parts, warm `PointLight` range 16, lit during Moonfall), benches around the tree |
| Great Egg Tree | (0, 0, 0) | Generated mesh (#1); 6 giant pastel eggs hanging from it (stretched Ball parts, SmoothPlastic, a soft `PointLight` each at night) |
| Egg Cart | (0, 0, 30), facing south | Wooden cart 18 × 8 (WoodPlanks), red and white striped Fabric awning, wheels (cylinders), five pedestals with display eggs (below), a chalkboard sign "EGGS", ProximityPrompt "Shop" |
| Forecast board | (30, 0, 15) | Wooden board 12 × 8 on posts, SurfaceGui with three weather icons and countdowns |
| Top Gardens board | (0, 0, −34) | Wooden board 14 × 10 with leaf garland (parts), SurfaceGui top 10 |
| Wild Meadow gate | (−30, 0, 15) | Wooden arch with vine and flower parts, leading to a fenced wildflower field where released creatures run off |
| Garden plots | 6 plots, centres at radius 100, angles 0°, 60° … 300° from north clockwise, front gate facing the plaza | Section I2 |
| Paths | plaza to each plot gate | Sand path 8 wide with Cobblestone edging |
| Wildflower meadows | between plots | Flower clusters (stem cylinder + Ball head, pastel colours), at most 600 flowers; bushes (Ball, LeafyGrass) |
| River | ring at radius 165, 14 wide | Terrain water, three wooden arched bridges |
| Blossom trees | 16 around radius 140 | Reused sakura mesh, colour-tinted petals particles |
| Windmill | (0, 0, −215) | Brick tower with WoodPlanks cap, four sail arms (parts, spun client-side) |
| Red barn and silo | (190, 0, 60) | Wood (red) with white trim, Metal silo with a dome |
| Far scenery | beyond 180 studs | Terrain hills (Grass, Rock outcrops), a tree line of part trees (cone and ball), `Clouds` |

### I2. Garden plot (60 × 60, local front edge faces the plaza)

- **Fence:** perimeter 4 studs high in the owner's fence style (H4); 10-stud gate opening at the front centre.
- **Sign:** at the gate, 10 × 6 board on two posts, SurfaceGui (name, income, likes heart, Index).
- **Beds:** 12 positions in 3 rows of 4 across the front half; each 7 × 7 soil block (Ground material, colour (110, 75, 50), raised 0.8) inside a WoodPlanks border. Locked beds: rope border and a small price sign. Growing eggs sit in the soil and grow from 40% to 100% scale as they ripen; ripe eggs glow (soft `PointLight`) and wobble; a BillboardGui shows time left.
- **Path:** Cobblestone strip 6 wide from the gate to the pen.
- **Pen:** back half, LeafyGrass; 20 pad positions in 4 rows of 5; each pad a 5-diameter cylinder 0.4 high in a pastel colour, with a coin pile (three gold cylinders, more as it fills) and a BillboardGui of the pending coins; locked pads grey and half transparent with a padlock icon.
- **Decor:** small red shed (parts) at the back-left corner, a water trough, a mailbox, flower borders along the fence.
- **Eggs (parts):** stretched Ball 2.2 × 3 × 2.2: Meadow pale green with white spots, Forest moss green with brown spots, Sunset orange-to-pink (two halves), Moon navy with Neon star dots, Star white-gold with Neon sparkle particles, Starter cream with a ribbon.

### I3. Creatures

- One MeshPart per creature, anchored on its pad; the client makes it bob, hop and turn idly (tweens, no animation rigs). Scale by size class (E4).
- **Mutation looks:** Normal: the generated texture. Golden: texture removed, Colour (255, 200, 60), Foil material, sparkles. Moonlit: blue `Highlight` (fill (120, 140, 255), transparency 0.6) and moth particles. Rainbow: `Highlight` fill cycled through the spectrum on the client and rainbow sparkles.

### I4. Look

- **Lighting (Clear):** `ClockTime` 14.5, `Brightness` 3, `Ambient` (120, 120, 130), `OutdoorAmbient` (140, 140, 150); `Atmosphere` density 0.28, colour (200, 220, 255), decay (110, 140, 190), haze 1; `Bloom` intensity 0.35, threshold 1.6; `ColorCorrection` saturation 0.25, contrast 0.08; `SunRays` 0.06; `Clouds` cover 0.55.
- **Sunbeam:** tint (255, 236, 200), `SunRays` 0.25, golden sparkle particles over the map.
- **Moonfall:** `ClockTime` tweened to 0.5 over 4 s, `OutdoorAmbient` (80, 90, 150), lamp posts and hanging eggs light up, fireflies.
- **Rainbow Shower:** light rain particles, `Clouds` cover 0.8, a rainbow `Beam` (7-colour `ColorSequence`, width 40, curved into an arc about 300 studs across the sky), rainbow sparkles on ripe eggs.
- **Life:** butterflies near flowers, windmill turning, petals drifting, creatures bobbing, coin pops.
- **Budgets:** world under 6,000 parts; each plot under 300 parts plus creatures; at most 120 creature MeshParts (6 × 20).
- **First screenshot test:** the start-menu orbit frame must show the Great Egg Tree, the egg cart with its five coloured eggs, at least two gardens with creatures on pads and eggs in beds, flower meadows, and a blue sky with clouds (acceptance, section O).

### I5. Generated meshes (10 new, 1 reused)

Roblox AI mesh generation; style suffix on every creature prompt: "cute chunky toy figure, big shiny eyes, smooth stylised cartoon, bright colours, standing pose".

| # | Mesh | Prompt | Size (Normal) |
|---|---|---|---|
| 1 | Great Egg Tree | "giant whimsical storybook oak tree with a thick curvy trunk and a round fluffy leaf crown, pastel speckled eggs nestled in the branches, bright cartoon style" | 45 studs tall |
| 2 | Sprout Bunny | "chubby cream bunny with two green leaf sprouts instead of ears" + suffix | 4 studs |
| 3 | Toadstool Frog | "round green frog wearing a red white-spotted mushroom cap as a hat" + suffix | 4 studs |
| 4 | Bumble Pup | "fluffy puppy with yellow and black bumblebee stripes and tiny clear wings" + suffix | 4.5 studs |
| 5 | Berry Cat | "kitten wearing a red strawberry hood with green leaves on top" + suffix | 4.5 studs |
| 6 | Pumpkin Owl | "round owl whose body is an orange pumpkin with leafy vine tufts" + suffix | 5 studs |
| 7 | Cactus Fox | "fox made of soft green cactus with little pink flowers and a fluffy tail" + suffix | 5 studs |
| 8 | Lotus Turtle | "teal turtle with a shell shaped like a pink lotus flower" + suffix | 5.5 studs |
| 9 | Sunflower Lion | "orange lion cub whose mane is a big yellow sunflower" + suffix | 6 studs |
| 10 | Moonblossom Dragon | "small lavender and white dragon with a glowing crescent moon on its chest and petal wings with cherry blossoms" + suffix | 7 studs |
| – | Sakura tree | (existing asset 139101786875815) | about 25 studs (reused) |

Each new mesh needs a row in `docs/assets/register.md` before use (CLAUDE.md rule 9). If a creature mesh comes out unreadable after three tries, fall back to a part-built creature (body ball, head ball, ears) in its colours.

## J. Remote contract (for decision 0008)

- `ReplicatedStorage.GardenRemotes.Request` (RemoteFunction): `Request(action: string, arg: string?) -> boolean`. Common checks as decision 0007: loaded session; `action` a string; `arg` nil or a string of at most 32 characters; one request per 0.35 s per player; known action. A non-nil `arg` to an action that takes none is refused.

| Action | `arg` | Accepted when |
|---|---|---|
| `buyEgg` | egg id | D1 (cart distance 25, level, stock, coins, empty bed) |
| `buyBed` | nil | `bedCount < 12`, coins ≥ next bed cost |
| `buyPenSlot` | nil | `penSlots < 20`, coins ≥ next slot cost |
| `place` | creature id | in storage, a pad is free |
| `store` | creature id | placed, storage has room |
| `release` | creature id | owned, not a favourite |
| `favourite` | creature id | owned (toggles) |
| `like` | target UserId | target in server, not self, target's gate allows, not liked today, under 30 today |
| `setGate` | `open`, `friends`, `closed` | always |
| `home` | nil | has a character (server moves it to the plot gate) |
| `claimDaily`, `claimWeekly` | nil | MetaRules rules |
| `claimQuest` | quest id | today's quest, progress ≥ goal, not claimed |
| `buyCosmetic` | cosmetic id | priced, not owned, coins ≥ price |
| `equipCosmetic` | cosmetic id | unlocked; equips into its slot (`fence` or `can`) |

- **Bed prompts** (ProximityPrompt in each bed, handled by the server's `Triggered`): `Hatch` (D3) and `Water` (D2), same pure-rule checks plus root distance ≤ 12 studs. Prompts are only enabled when the action can succeed for that viewer (client-side visibility; the server checks anyway).
- `ReplicatedStorage.GardenRemotes.Fx` (RemoteEvent, server to clients, display only): `hatch {owner, bed, s, m, z}`, `collect {owner, pad, amount}`, `water {owner, bed, by}`, `announce {name, s, m, z}`, `like {owner}`. The server ignores `Fx.OnServerEvent`.
- `ReplicatedStorage.GardenStatus` (StringValue, JSON, server-written each second): `{ weather, weatherLeft, forecast = { kind, kind }, stockLeft, stockWindow }`. Each client computes its own stock left from its profile.
- **Player attributes** (server-written): `Profile` (JSON), `ProfileOnline`, `Coins`, `Income`, `Level`, `XP`, `Plot`, `LastReward`, `OfflineCoins` (set once on join for the card).
- **Plot attributes:** each plot model `Owner` (UserId); each pad part `Pending` (floored, updated 1 Hz).
- The client never sends amounts, prices, outcomes, positions or targets beyond the ids above.

## K. Edge cases

- **Clock:** all times are server `os.time()` (UTC). If `now < planted` (clock skew between servers), the egg is treated as just planted; `ready` is never moved later than `planted + growTime`.
- **Two servers at once** (rejoin race): the stored record carries a session lock (decision 0008 amendment, 2026-10-26), so only one server applies and writes a profile at a time; a server that cannot take the lock runs that session offline and tells the player. Within the lock holder, the re-apply pattern applies each operation to the stored record.
- **Full garden:** hatch refused with a message; ripe eggs wait.
- **Leaving with ripe eggs:** they stay ripe; nothing auto-hatches offline.
- **Weather boundary:** the weather is read at the instant the server accepts the hatch; the client's chip may be up to 1 s behind.
- **Restock boundary:** buys are counted per window `s`; a buy accepted in window `s` never counts against `s + 1`.
- **Server full:** 6 players and 6 plots (Max Players must be 6). If no plot is free (a leaver's plot is freed before their final write, so this is rare), the player is told and gets the next plot that frees up.
- **Owner leaves while a helper waters:** the water is applied to the owner's in-memory profile and saved with their leave write; after the owner's profile is unloaded, prompts on that plot are removed.

## L. Disconnects

- On leave: bank all pads, free the plot and remove its models, then the final write (`lastSeen = now`, `unbanked = 0`, session lock released).
- On crash: the last autosave holds `unbanked` and `lastSeen`; at most 60 s of online income is paid at the offline rate instead.

## M. Scope for one build cycle

In: 6 eggs (starter plus five), 9 species, 4 mutations, 3 sizes, 4 weathers plus Weekend Bloom, beds, pen, storage, release, favourite, Index, watering, likes, gate, offline, all meta hallmarks, the world in section I.

**Cut order if the cycle runs long:** watering-can cosmetic slot; `friends` gate option (keep open and closed); Star Egg; likes; Weekend Bloom; Fast Hatch. The core (five eggs, nine species, weather mutations, pads, offline, Index, daily, weekly, quests, levels, leaderboard) stays.

## N. Module plan and unit tests

New pure modules in `src/shared/` (no Roblox APIs), each with `tests/<Module>.spec.luau` registered in `tests/run.luau`:

| Module | Contents | Tests |
|---|---|---|
| `GardenConfig` | Eggs, species, mutations, sizes, weather tables, bed and pen costs, cosmetics, quests (data only) | every odds row sums to 10,000; every species in an egg table exists; costs match C1 and C2 |
| `HatchRules` | `rollSpecies(egg, pity, rng)`, `rollMutation(weather, rng)`, `rollSize(rng)`, `hatch(profile, bed, now, weather, rng)`, starter rule, pity update, Index update | cumulative mapping at boundaries (r = 6000 is Bunny, 6001 Frog on Meadow); pity forces the top species at meter − 1 and resets; non-top increments; starter always Normal Normal Bumble Pup; new Index entry adds once and gives 50 XP; full garden refused; storage used when pen full; over 100,000 seeded rolls each species frequency within 0.5 percentage points of its odds |
| `GardenRules` | `rate`, `income`, `indexMult`, pad accrual and banking, offline, `buyEgg`, `water`, `buyBed`, `buyPenSlot`, `place`, `store`, `release`, `favourite`, `short` number format | C3 check values (60.5, 108,900, 871,200); banking floors and keeps the fraction; offline zero when `lastSeen` is in the future; buyEgg each refusal (level, stock, coins, no bed); planted in lowest empty bed; water reduction per egg, 60 s cooldown, 5 + 3 caps, `ready ≥ now`; Moon 8 waters gives 2,160 s; bed and slot cost tables and caps; release value 324 for a Big Golden Berry Cat; buy, hatch and release returns at most 60% of every egg's price in every weather and refusal for favourites; `short(1234) = "1.2K"`, `short(999) = "999"`, `short(1.5e12) = "1.5T"` |
| `WorldRules` | `weatherAt(unix)`, `forecast(unix, n)`, `isWeekend(unix)`, `stockFor(window)` | same unix gives the same weather; active only in the first 300 s of a window; weekday and weekend tables used on the right days (check Friday 23:59 and Saturday 00:00 UTC); over 20,000 windows each weather within 1 point of its odds; Meadow always unlimited; stock quantities within ranges |
| `GardenProgress` | Garden config for `MetaRules`, XP table, level unlocks, scaled rewards (H5), quests and stats, `like`, `setGate`, defaults (starter egg), `sanitize` (H7) | H5 check values (14,520, 120, 100); quest progress per stat; like once per owner per day and 30 cap; helper XP cap 20 per day; defaults have 100 coins, 3 beds, 6 pads and a starter egg ready 8 s after creation; every sanitise rule in H7 |
| `MetaRules` | (decision 0007) plus `index` unlock kind and optional `scale` hook | Relay's `ProgressRules` spec still passes unchanged; Night's specs unchanged; `index` unlock; `scale` absent gives base amounts |

Server scripts (`src/garden/`): `GardenServer` (requests, prompts, pad loop, weather status, announcements), `Plots` (build and refresh plot models), `World` (valley build), `Profiles` (reused pattern), `Models` (reused loader). Client (`src/garden-client/`): `Menu` (fork), `Hud`, `HatchFx` (reveal, coin pops, weather looks), `CreatureFx` (bob, hop, mutation looks). Project file `garden.project.json`, staging environment `garden-staging`.

## O. Acceptance criteria (v0.1)

- [ ] All unit tests in section N pass in CI.
- [ ] Hatch odds, pity, mutations and sizes follow section E (unit tests, including the 100,000-roll frequency test).
- [ ] Income, pads, offline and release follow section C (unit tests with the check values).
- [ ] Buying, stock, watering and hatching follow section D (unit tests).
- [ ] Weather and restock schedules follow sections D1 and F (unit tests).
- [ ] Rewards, quests, likes, gate and sanitising follow sections G and H (unit tests).
- [ ] Relay's existing `ProgressRules` tests still pass.
- [ ] A new player hatches the starter egg within 15 s of pressing PLAY and has bought their first Meadow Egg within 60 s (Studio playtest, timed).
- [ ] A new player reaches the Sunset Egg within 25 minutes of normal play (Studio playtest).
- [ ] Leaving and rejoining after 10 minutes pays the offline amount the rules predict and keeps every egg, creature and pad coin (Studio test with DataStores on).
- [ ] Two clients: one waters the other's egg and likes their garden; the `closed` gate blocks both (Studio multi-client test).
- [ ] Every egg's ODDS panel matches `GardenConfig` and totals 100% (manual check against the table).
- [ ] Server frame time under 8 ms with 6 full gardens (120 creatures, 72 beds) (MicroProfiler capture).
- [ ] Start-menu screenshot passes the I4 first-screenshot test, reviewed by SHANNON.
- [ ] Every mesh, track and SFX has a register row; no Robux prompts, no paid items, no trading.

## P. Kill criteria

- **Week-1 feel gate:** after hatching, pads, the cart, three egg tiers and one plot are built, SHANNON plays the first 15 minutes on a fresh profile and rates it below 4 out of 5 or calls it "not good enough". Then stop and switch to concept B (Lantern Pets), which reuses the eggs, odds, pity, creatures and meshes.
- **Live:** under 60% of new players hatch their third egg, or the median first session is under 8 minutes, over the first 500 visits.
- **Live:** fewer than 25% of players who reach level 5 come back the next day.

## Q. Facts, assumptions, hypotheses

- **Fact:** Grow a Garden's crops grow while players are offline, its seed stock rotates, and it set a 22.3M concurrency record; Steal a Brainrot's bought characters earn income over time on your base and it peaked at 25.4M (`game4-concepts.md` G1, G2).
- **Fact:** Roblox requires published odds only for paid random items, explicitly including egg hatching (G6). We publish free odds anyway.
- **Fact:** the genre's documented harms are stealing distress, cheating scripts and trading scams (G2, G7).
- **Fact:** `Rng`, `ProgressRules`, the Relay `Profiles` and `Menu` patterns and the sakura mesh are in this repo; `MetaRules` is specified by decision 0007 but not yet in `src/shared/` on the date of this spec.
- **Assumption:** Roblox's DataStore limits allow one write per key every few seconds (about 6 s); the 7 s coalescing in H7 is chosen from that. To verify against the current Creator Docs limits page before build.
- **Assumption:** Roblox's mesh generator makes readable, cute creatures at 4 to 7 studs; the part-built fallback covers failures.
- **Assumption:** a server-side 5 Hz distance check over up to 20 pads per player is cheap enough (120 checks per tick).
- **Assumption:** `Highlight` on up to 120 creatures is too many (Roblox caps active highlights at about 31); Moonlit and Rainbow looks fall back to particles and a tinted `SelectionBox` if the cap bites. To verify in Studio.
- **Hypothesis:** walking pads, watering and frequent early hatches carry the first session before the long timers matter.
- **Hypothesis:** the forecast board turns hatching into a timing choice that players talk about ("Rainbow Shower in 4 minutes!").
- **Hypothesis:** half-rate offline coins plus Moon and Star eggs bring players back the next day without punishing a missed day.
- **Hypothesis:** helper watering and likes give friends a reason to visit each other's gardens (co-play days) without the harm of stealing.

## R. Open questions

- Decision 0008 for the economy, remotes and save schema (rule 8), and a task file in `studio/tasks/` (rule 1), before build.
- Who builds `MetaRules` first (game 3 or game 4), so it is built once.
- ~~Music picks (SHANNON's taste) and SFX registration.~~ **Decided 2026-10-26:** SHANNON asked the studio to choose licensed Roblox audio. Picks are APM tracks registered in `docs/assets/register.md` (GARDEN-005): "Sail Boat (c)" and "Happy Daze (b)" for normal play, "Tiny Ripples in the River" for Moonfall, "Seven Leaf Clover - Hit2" for weather starts, "The Little Things - Tag1" for Legendary/Mythic reveals and level up.
- Whether a later update adds rebirth ("Garden Stars") for long-term players; not in v0.1.
