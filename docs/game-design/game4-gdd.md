# Egg Garden: game design spec (v0.1)

Status: draft for SHANNON. Concept D in `game4-concepts.md`. Needs decision record 0008 (economy, remotes, save schema; CLAUDE.md rule 8) and a task file before build. v0.2 adds sections S (Celestial Egg) and T (Splash Dash) with decision 0012; earlier sections are updated where those change them.

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

Target pacing (hypothesis): Forest Eggs in the first 3 minutes, Sunset Eggs in the first 20, Moon Eggs on day 2, Star Eggs by day 5, the first Celestial Egg around day 12 (section S3).

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
- Index bonus: `indexMult = 1 + 0.02 × indexCount` (0 to 38 entries, so up to ×1.76).
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
| `celestial` | Celestial Egg | 1,000,000,000 | 8 h | Level 25 | 5% chance, 1 (section S) |

- **Restock:** window `s = floor(unix / 300)` (every 5 minutes, the same for every server). For egg index `i` (forest 2, sunset 3, moon 4, star 5, celestial 6), `state = Rng.seed(s, 9001, i)`; `r = Rng.int(state, 1, 10000)`; in stock if `r ≤ chance × 100`; then quantity `Rng.int(next state, min, max)`. Stock is **per player**: each player can buy that many of each egg in that window, so nobody competes for stock.
- `buyEgg(id)` is accepted when the player is within 25 studs of the egg cart (server position), the egg is unlocked by level, the player's buys this window are below the stock, coins ≥ price, and a bed is empty. The egg is planted in the lowest-numbered empty bed: `planted = now`, `ready = now + growTime`.

### D2. Watering

- `Water` prompt on a growing bed (any player whose gate rules allow, section G). Accepted when the bed is growing, at least 60 s have passed since the last water on that bed (by anyone), and the caps below are not reached. The waterer's root must be within 12 studs of the bed.
- Each water: `ready = max(now, ready − floor(0.05 × growTime))`. Meadow −1 s, Forest −9 s, Sunset −45 s, Moon −180 s, Star −720 s, Celestial −1,440 s.
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
| `celestial` | Sunflower Lion 8500, Moonblossom Dragon 1500 | Moonblossom Dragon by 10 |

**Lucky Meter (pity):** `pity[egg]` counts hatches of that egg since its top species last hatched. If `pity[egg] ≥ meter − 1`, the species is the top species without a roll. After the hatch, `pity[egg] = 0` if the species is the top species, else `+1`. The meter is shown on each egg ("Lucky Meter 37 / 100").

Expected income per hatch at base rates (for balancing, not shown): Meadow 1.77, Forest 6.45, Sunset 33.2, Moon 162, Star 374, Celestial 650 coins/s before its ×20 (section S2).

### E3. Mutations (rolled by the weather at hatch time, basis points)

The Celestial mutation (×20) is not in this table: only the Celestial Egg gives it, always, in any weather (section S).

| Weather | Normal ×1 | Golden ×3 | Moonlit ×5 | Rainbow ×10 |
|---|---|---|---|---|
| Clear | 9790 | 200 | 0 | 10 |
| Sunbeam | 7450 | 2500 | 0 | 50 |
| Moonfall | 7750 | 200 | 2000 | 50 |
| Rainbow Shower | 8500 | 500 | 0 | 1000 |

### E4. Sizes

Normal ×1.0 (8000), Big ×1.5 (1700), Huge ×2.5 (300). Model scale 1.0, 1.4 and 2.0.

### E5. Garden Index

- 38 entries: 9 species × 4 weather mutations, plus `lion:celestial` and `dragon:celestial`; key `"<species>:<mutation>"`. An entry is discovered at its first hatch and kept forever (also after release).
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
7. No "limited offer" pop-ups, no countdowns on anything except the restock and weather boards and a Splash Dash round's own start and finish timers (decision 0012).

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
- **Egg cart panel** (opens from the cart's prompt): six eggs with price, grow time, stock left this window, unlock level, Lucky Meter, ODDS button, BUY.
- **Garden sign** (world): owner name, income, likes, Index n / 38.
- **First session** (`hatches = 0` at join): the starter egg ripens 8 s after the profile is created. Prompts in order, each disappearing when done: "Your egg is ready! Hatch it" (arrow to bed 1), "Walk over the pad to collect coins", "Visit the Egg Cart" (beam to the cart), "Buy a Meadow Egg", "Water your egg", "Hatch it when it's ripe!". Starting coins 100, so two Meadow Eggs can be bought at once.

### H3. Progression

- **XP:** hatch Starter or Meadow 10, Forest 25, Sunset 60, Moon 150, Star 400, Celestial 1,000; new Index entry +50; own water 3; helper water 15 (D2).
- **Levels** (shared curve). Unlocks: Forest Egg 2 (40 XP), Sunset Egg 5 (640), Moon Egg 10 (3,240), Star Egg 18 (11,560), Celestial Egg 25 (23,040), plus cosmetics.
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
- **Stats panel:** level, XP, coins, income, hatches, Index n / 38, best creature, likes, "saving offline" notice when DataStores are unavailable (reused).
- **Settings** (client-only, not saved): music, sound effects, Fast Hatch, hatch announcements on/off, How to Play card, Odds card.
- **Music:** two bright acoustic or ukulele tracks from the Roblox audio library (APM) for normal play, one dreamy track for Moonfall, short stingers when Sunbeam, Moonfall and Rainbow Shower start. To pick and register before use.
- **SFX** (Roblox library, registered before use): egg wobble, crack, pop, rarity fanfares (soft chimes rising with rarity, no slot sounds), coin collect, water splash, like heart, cart buy.

### H7. Saved profile (schema v2, store `GardenProfile<suffix>`)

```
{ schemaVersion, xp, coins, lastSeen, unbanked, nextId, bedCount, penSlots,
  beds = { { egg, planted, ready, waters, helps, lastWater } },   -- one per bed; empty bed: egg = ""
  creatures = { { id, s, m, z, placed, fav } },                    -- species, mutation, size
  pity = { meadow, forest, sunset, moon, star, celestial },
  index = { "<species>:<mutation>", ... },
  stock = { w, bought = { forest, sunset, moon, star, celestial } },
  prizeEggs = { [eggId] = count }, dash = { day, prizes, coins },    -- v2, section T5
  hatches, waters, likes, gate, fence, can, owned,
  helped = { day, count }, liked = { day, ids },
  daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }
```

Sanitising (`GardenProgress.sanitize`): numbers floored and clamped (XP 1,000,000; coins and `unbanked` 1e15; counts 1,000,000); `bedCount` 3–12 and `penSlots` 6–20; `beds` trimmed or padded to `bedCount`, a bed with an unknown egg emptied, `ready` clamped to `[planted, planted + growTime]`; creatures with unknown species, mutation or size dropped, at most `penSlots + 60` kept, at most `penSlots` placed (extras unplaced, then oldest dropped past storage); unique `id`s, `nextId` above all of them; unknown `index` keys dropped; `gate` falls back to `open`; `fence` to `picket` and `can` to `tin` if unknown or locked; `owned` keeps only priced cosmetic ids; `lastSeen` in the future becomes now; `pity` clamped 0 to its meter; a creature or `index` key whose mutation that species cannot have is dropped (`bunny:celestial`); `prizeEggs` keeps sold eggs with a count of at least 1, clamped to 1,000,000; `dash` counters clamped to their daily caps. A v1 record has neither field and gets the defaults `{}` and `{ day = -1, prizes = 0, coins = 0 }` (decision 0012).

Writes use the `UpdateAsync` re-apply pattern (decision 0006). Random outcomes are rolled once on the in-memory profile; the stored-record operation applies that fixed outcome, so re-applying never re-rolls. Operations are coalesced: at most one write per player per 7 s, plus the 60 s autosave (`lastSeen`, `unbanked`, banked coins) and a final write on leave and in `BindToClose`.

## I. World and art plan

### I1. Layout ("Hatchling Valley", all ground level)

Centre (0, 0, 0). North is −Z.

| Feature | Where | Build |
|---|---|---|
| Plaza | centre, radius 45 | Cobblestone with a Brick ring, 8 lamp posts at radius 42 (parts, warm `PointLight` range 16, lit during Moonfall), benches around the tree |
| Great Egg Tree | (0, 0, 0) | Generated mesh (#1); 6 giant pastel eggs hanging from it (stretched Ball parts, SmoothPlastic, a soft `PointLight` each at night) |
| Egg Cart | (0, 0, 30), facing south | Wooden cart 18 × 8 (WoodPlanks), red and white striped Fabric awning, wheels (cylinders), six pedestals with display eggs (below), a chalkboard sign "EGGS", ProximityPrompt "Shop" |
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
| Splash Dash ready pad | (−26, 0, −22) | `dash_ready_pad` with its "Ready" prompt (section T3) |
| Splash Island | centre about (0, 140, 350), high above the south meadow | Floating course, section T2; reached only by teleport |
| Far scenery | beyond 180 studs | Terrain hills (Grass, Rock outcrops), a tree line of part trees (cone and ball), `Clouds` |

### I2. Garden plot (60 × 60, local front edge faces the plaza)

- **Fence:** perimeter 4 studs high in the owner's fence style (H4); 10-stud gate opening at the front centre.
- **Sign:** at the gate, 10 × 6 board on two posts, SurfaceGui (name, income, likes heart, Index).
- **Beds:** 12 positions in 3 rows of 4 across the front half; each 7 × 7 soil block (Ground material, colour (110, 75, 50), raised 0.8) inside a WoodPlanks border. Locked beds: rope border and a small price sign. Growing eggs sit in the soil and grow from 40% to 100% scale as they ripen; ripe eggs glow (soft `PointLight`) and wobble; a BillboardGui shows time left.
- **Path:** Cobblestone strip 6 wide from the gate to the pen.
- **Pen:** back half, LeafyGrass; 20 pad positions in 4 rows of 5; each pad a 5-diameter cylinder 0.4 high in a pastel colour, with a coin pile (three gold cylinders, more as it fills) and a BillboardGui of the pending coins; locked pads grey and half transparent with a padlock icon.
- **Decor:** small red shed (parts) at the back-left corner, a water trough, a mailbox, flower borders along the fence.
- **Eggs (parts):** stretched Ball 2.2 × 3 × 2.2: Meadow pale green with white spots, Forest moss green with brown spots, Sunset orange-to-pink (two halves), Moon navy with Neon star dots, Star white-gold with Neon sparkle particles, Starter cream with a ribbon, Celestial pearl white with gold Neon star particles. The `egg_*` Blender models replace these when uploaded; the parts stay as the fallback (architecture section 9).

### I3. Creatures

- One MeshPart per creature, anchored on its pad; the client makes it bob, hop and turn idly (tweens, no animation rigs). Scale by size class (E4).
- **Mutation looks:** Normal: the generated texture. Golden: texture removed, Colour (255, 200, 60), Foil material, sparkles. Moonlit: blue `Highlight` (fill (120, 140, 255), transparency 0.6) and moth particles. Rainbow: `Highlight` fill cycled through the spectrum on the client and rainbow sparkles. Celestial: section S5.

### I4. Look

- **Lighting (Clear):** `ClockTime` 14.5, `Brightness` 3, `Ambient` (120, 120, 130), `OutdoorAmbient` (140, 140, 150); `Atmosphere` density 0.28, colour (200, 220, 255), decay (110, 140, 190), haze 1; `Bloom` intensity 0.35, threshold 1.6; `ColorCorrection` saturation 0.25, contrast 0.08; `SunRays` 0.06; `Clouds` cover 0.55.
- **Sunbeam:** tint (255, 236, 200), `SunRays` 0.25, golden sparkle particles over the map.
- **Moonfall:** `ClockTime` tweened to 0.5 over 4 s, `OutdoorAmbient` (80, 90, 150), lamp posts and hanging eggs light up, fireflies.
- **Rainbow Shower:** light rain particles, `Clouds` cover 0.8, a rainbow `Beam` (7-colour `ColorSequence`, width 40, curved into an arc about 300 studs across the sky), rainbow sparkles on ripe eggs.
- **Life:** butterflies near flowers, windmill turning, petals drifting, creatures bobbing, coin pops.
- **Budgets:** world under 6,000 parts; each plot under 300 parts plus creatures; at most 120 creature MeshParts (6 × 20).
- **First screenshot test:** the start-menu orbit frame must show the Great Egg Tree, the egg cart with its six coloured eggs, at least two gardens with creatures on pads and eggs in beds, flower meadows, and a blue sky with clouds (acceptance, section O).

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
| `dashReady` | nil | toggles Splash Dash ready (section T3); refused for a racer in a running round |
| `plantPrize` | egg id | a prize egg of that kind is stored, level ≥ the egg's unlock, an empty bed exists |

- **Bed prompts** (ProximityPrompt in each bed, handled by the server's `Triggered`): `Hatch` (D3) and `Water` (D2), same pure-rule checks plus root distance ≤ 12 studs. Prompts are only enabled when the action can succeed for that viewer (client-side visibility; the server checks anyway).
- `ReplicatedStorage.GardenRemotes.Fx` (RemoteEvent, server to clients, display only): `hatch {owner, bed, s, m, z}`, `collect {owner, pad, amount}`, `water {owner, bed, by}`, `announce {name, s, m, z}`, `like {owner}`, plus the Splash Dash events (decision 0012). The server ignores `Fx.OnServerEvent`.
- `ReplicatedStorage.GardenStatus` (StringValue, JSON, server-written each second): `{ weather, weatherLeft, forecast = { kind, kind }, stockLeft, stockWindow, dash }` (`dash`: decision 0012). Each client computes its own stock left from its profile.
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

## S. Celestial Egg (v0.2, decision 0012)

Status: draft for SHANNON. The owner asked for "an even higher tier of egg that guarantees a special variant of the highest two rarities".

### S1. Rules

| Id | Name | Price | Grow time | Unlock | Stock per restock window | XP on hatch | Lucky Meter |
|---|---|---|---|---|---|---|---|
| `celestial` | Celestial Egg | 1,000,000,000 coins | 8 h (28,800 s) | Level 25 | 5% chance, 1 | 1,000 | Moonblossom Dragon by 10 |

- Sold at the Egg Cart for coins only. No Robux, no paid odds (decision 0002). Bought like every other egg (D1): cart distance, level, per-player stock, coins, empty bed.
- **Species:** Sunflower Lion 8500, Moonblossom Dragon 1500 (basis points). Legendary or Mythic only.
- **Mutation:** always `celestial` (Celestial, ×20). No mutation draw; the weather has no effect. The mutation is in no weather table, so nothing else can roll it.
- **Size:** the normal size roll (E4). Draw order: species (skipped when the Lucky Meter forces it), then size.
- **Stock:** egg index 6 in the D1 formula. It goes last in `EGGS`, so the stock of every existing egg stays exactly the same.
- **Water:** the normal rules (D2). Each water cuts 1,440 s; 8 waters ripen it in 17,280 s (4 h 48 min).
- **Lucky Meter applies, meter 10.** Reasons: G4.4 and decision 0008 promise a guaranteed top creature within a published number of hatches on every egg; and `HatchRules.rollSpecies` treats an egg without a meter as the starter (it takes the first species with no draw), so without a meter every Celestial would be a lion. With the meter the long-run dragon share is 18.7% instead of 15%.
- **Index:** exactly 2 new entries, `lion:celestial` and `dragon:celestial`, so 38 in all and at most ×1.76 income (C3).

### S2. Check values

| Check | Value |
|---|---|
| Normal Celestial Sunflower Lion | 10,000 coins/s, release 60,000 |
| Normal Celestial Moonblossom Dragon | 30,000 coins/s, release 180,000 |
| Huge Celestial Moonblossom Dragon | 75,000 coins/s, release 450,000 |
| Average per hatch | 15,521 coins/s before the Index bonus (species with the meter × 20 × size average 1.13) |
| Buy, hatch, release | about 93,000 coins expected, 0.01% of the price in every weather (limit 60%; the highest in the game stays Meadow in Rainbow Shower, 52.3%) |
| Lucky Meter | `pity = 9` forces a dragon with no species draw |
| Index | 38 entries, `indexMult` 1.76 at 38 |

### S3. Pacing result (`docs/game-design/game4-pacing-check.py`, decision 0012)

- **Fact (computed):** with the existing eggs, a 1 hour a day player gets Moon on day 2 and Star on day 5, matching the section B targets.
- **Fact (computed):** the suggested 2,500,000 is under 5 minutes of income at Level 25 (about 8,700 coins/s) and cheaper than the last bed. Prices up to 200,000,000 do not move the first purchase at 1 hour a day: only level and stock do.
- **Result:** 1,000,000,000 is 4 to 7 days of earnings at Level 25 (150M to 280M coins a day), the same price as the Rainbow fence, the existing long-term coin goal. First Celestial: day 12 at 1 hour a day, day 17 at 30 minutes, day 6 at 3 hours. Nothing before Level 25 changes.
- Payback rises at every tier: 19 s, 44 s, 63 s, 107 s, 373 s, then 64,429 s (about 18 hours of income).
- **Known effect:** income climbs past the old ceiling. At day 45, a 1 hour a day player earns about 496,000 coins/s against 42,752 without the egg. It is the last tier, so no later purchase gets skipped; only the cosmetics at 1B and 10B come sooner, and those were within reach by day 45 anyway.

### S4. Everything that assumed 4 mutations or 36 entries

| Place | Assumption | Change |
|---|---|---|
| `GardenConfig.INDEX_SIZE` | 36 | 38; a test counts `GardenConfig.indexable` pairs so it cannot drift |
| `GardenConfig.MUTATIONS` | every mutation comes from weather | `celestial` added last; `Egg.mutation` names the egg that fixes it |
| Weather tables | 10,000 in `MUTATIONS` order | stay 4 rows and 10,000. The order rule now skips egg-only mutations, so there is no `Celestial 0.00%` row and `pick`'s last-row fallback can never return `celestial` |
| `tests/GardenConfig.spec` weather order, the D1 pinned string, the mutation string | exact lists | updated |
| `tests/GardenRules.spec` 60% test | mutation comes from the weather; 20 checks | uses the egg's fixed mutation; 24 checks. Unchanged, it would pass wrongly |
| `HatchRules.roll` | always draws a mutation | skips the draw when the egg fixes it |
| `GardenProgress.sanitize` | any species with any known mutation is valid | `bunny:celestial` is impossible: dropped from `index` and `creatures` by `GardenConfig.indexable` |
| Menu Index grid | every species has 4 cells at 25% width | a cell only where `indexable`; lion and dragon get 5, width `1 / cells` |
| Menu `weathersFor` | a mutation lists its weathers | returns "Celestial Egg" for an egg-only mutation (it would be an empty string) |
| Menu ODDS card | shows the current weather's table for every egg | Celestial shows `Celestial x20  100.00%` and "any weather" instead |
| Menu `MUTATION_COLOURS` | 4 colours | adds `celestial` |
| `CreatureFx.applyLook` | anything not golden or moonlit is rainbow | adds a Celestial look (S5) |
| `ClientState.EGG_COLOURS`, `Plots.EGG_LOOKS` | five eggs | adds `celestial` (they fall back to Meadow silently) |
| `World.luau` cart | 5 pedestals at 3.5 spacing | 6 at 2.8 spacing, or the sixth hangs off the cart |
| Cosmetics by Index count | `golden` at 20 entries | no change: it is a count, not a share |
| `WorldRules.stockFor`, `GardenStatus.stock` | loop over `EGGS` | no code change; `stock.celestial` appears |
| `sanitize` of `pity` and `stock.bought` | loop over `EGGS` | no code change; old saves read 0 |

### S5. UI

- **Egg cart panel:** a sixth row, "1B coins - grows in 8:00:00 - level 25". Sold out most of the time; the row says so with the normal text and no extra pressure.
- **ODDS card:** species table to two decimals, then "Celestial x20 100.00%, any weather", the Lucky Meter, sizes. Text: "Every Celestial Egg hatches Legendary or Mythic with the Celestial mutation."
- **Index:** lion and dragon rows get a fifth cell, labelled "Celestial Egg" until found.
- **Mutation look:** white-gold body (Foil, like Golden but pale), slow gold and white star particles, a pale Highlight when the budget allows (same fallback as Moonlit).
- **Reveal:** the same reveal with the `egg_celestial` model and the top rarity chime. No near-miss, no extra drama timer. Every hatch is announced (already true for Legendary and Mythic).

### S6. Edge cases

- **Bought during a weather event:** nothing changes; the weather does not touch the egg, and the odds card says so.
- **Hatched with the garden full:** refused as usual; the egg stays ripe.
- **Released by mistake:** the normal confirmation shows the release value; favourites cannot be released.
- **Rollback:** a build older than 0012 would drop Celestial eggs and creatures on load (decision 0012, Consequences). Never roll back past 0012 without SHANNON.

## T. Splash Dash (v0.2, decision 0012)

Status: draft for SHANNON. The owner asked for an obstacle mini-game that needs three of the six lobby members to start, with a high tier egg for the winner. "Splash Dash" is a working name; player-facing text never names the TV show this kind of game comes from (it is a trademark).

### T1. Rules at a glance

- A colourful obstacle race on **Splash Island**, a floating island high above the south meadow, away from the plots. No path leads there; players arrive by teleport, so it stays empty between rounds.
- Falling or being knocked into the water sends you to your last checkpoint. No combat: players pass through each other and cannot touch each other.
- Optional. Nothing in the Index, the quests or the rewards needs it, so pillar 3 (complete alone) holds. A player in a server of 1 or 2 sees "Needs 3 players".

### T2. Course

```
 north (towards the plaza)
 START  ->  Sweeper Green  ->  CP1  ->  Ball Alley  ->  CP2
                                                         |
                                                 Pendulum Bridge
                                                         |
 FINISH <-  Last Sprint   <-  CP4  <-   Lily Hop    <-  CP3
```

| Stage | Zone centre (world) | Length | Obstacles (models) | Width |
|---|---|---|---|---|
| Start deck | (−120, 140, 300) | – | closed arch (`dash_arch`), 6 start spots | 40 |
| 1. Sweeper Green | (−20, 140, 300) | 100 | 2 spinning sweepers (`dash_sweeper`) | 44 |
| 2. Ball Alley | (100, 140, 300) | 120 | 4 big bouncing balls crossing the alley (`dash_ball`) | 24 |
| 3. Pendulum Bridge | (100, 140, 400) | 100 | 3 swinging pendulums (`dash_pendulum`) | 10 |
| 4. Lily Hop | (−20, 140, 400) | 120 | 4 moving platforms (`dash_platform`) | 12 each |
| 5. Last Sprint and finish | (−120, 140, 400) | 100 | 1 sweeper, finish arch (`dash_arch`) | 24 |

- Total 540 studs: 33.75 s at walking speed 16, about 40 s for a flawless run with the platform waits. **Hypothesis:** a typical run takes 70 to 90 s. To be checked at the greybox feel gate.
- The pool (`dash_island` base and a blue water plane) sits at y 118. A root below y 125 counts as a fall.
- Walk and jump only, so phone and gamepad play the same as PC.
- Moonfall dims the world: obstacles keep Neon accents and each arch has a `PointLight`, so the course stays readable.

### T3. Starting a round

- **Ready:** the `dash_ready_pad` in the plaza at (−26, 0, −22), with a "Ready" ProximityPrompt, or the READY button in the DASH panel. Both toggle the same server state, so a player can ready up from their garden and keep gardening.
- **Needs 3 ready players** of the 6 in the server. When the third readies, a 15 s countdown starts. More can join during it (up to all 6). If ready players drop below 3, it cancels, and a new third player starts a full new 15 s.
- **Start:** at 0, every ready player with a character is teleported to the start deck. 5 s later the arch opens: GO. The timer runs 120 s from GO.
- While a round runs, others may ready up for the next one. Racers are not re-readied automatically.
- Non-players keep gardening. Pads keep accruing as usual for racers (they bank when the racer gets home), and eggs keep growing.

### T4. Winning

- The **winner** is the first player to reach the finish through every checkpoint in order.
- After the first finish, the others have 20 s more to finish. The round ends then, at 120 s, or when no racer is still running, whichever comes first.
- If nobody finishes, nobody gets a prize.
- At the end everyone is teleported back to their plot gate and the results card shows.

### T5. Prizes

| Prize | Who | Cap | Amount |
|---|---|---|---|
| Moon Egg, into `prizeEggs` | the first finisher who is **eligible** | 3 per player per UTC day | 1 egg |
| Coins | every other finisher | 6 per player per UTC day | `scaled(100, 1)`: 1 minute of income, at least 100 |

- **Eligible:** under the daily prize cap, and the session is saving (`ProfileOnline` true), checked at the start of the round. If the first finisher is not eligible they are still the winner on the card, and the egg goes to the next eligible finisher within the 20 s. This stops a capped player from ending the prize for everyone.
- `prizeEggs` is a saved store, a count per egg. Its limit is 1,000,000, so a prize is never lost to full beds.
- **Planting:** PLANT in the DASH panel puts the egg in the lowest empty bed, from anywhere, with no price and no stock check. It then grows, waters and hatches as a normal Moon Egg (with its Lucky Meter and 150 XP).
- **Level gate: planting needs the Moon Egg's own unlock, Level 10.** The prize is awarded and saved at any level. Reason in T6.

### T6. Does a free egg break early pacing?

Yes without a gate, no with one (`game4-pacing-check.py`, worst case: all 3 prizes at the start of day 1).

| Day 1 income at online minute | 20 | 40 | 60 | 90 | 120 |
|---|---|---|---|---|---|
| No prizes | 166 | 404 | 553 | 946 | 1,326 |
| Planted from Level 1 | 99 | 245 | 1,174 | 1,608 | 1,881 |
| Planted from Level 5 | 134 | 271 | 515 | 1,605 | 2,302 |
| Planted from Level 10 | 166 | 404 | 553 | 878 | 1,737 |

- From Level 1 it hurts twice: a one-hour egg sits in one of only 3 beds during the first 40 minutes (income nearly halved, Sunset at 25 instead of 14 minutes), then income doubles at minute 60.
- From Level 10 the first hour is identical to no prizes. It is also not a new number: it is the egg's own rule.
- After that, even the worst case stays inside the curve: Star stays on day 5 and Level 25 on day 7, because levels gate them. Income is about 1.7 to 2 times higher on days 2 and 3 and 1.5 times on day 7. A real player wins far less than every prize.
- The prize is small as coins: releasing the hatch pays 1,250 to 2,300 coins an egg on average.
- **Win-trading:** 3 friends taking turns get at most 3 eggs each a day and need about 9 rounds of 2 minutes or more. The cap is the limit. The egg cannot be given to anyone.

### T7. Server authority and exploit limits

- **The server owns the round:** ready list, phases, timers, ordered checkpoints, finish, prizes. All of it is pure rules in `DashRules`; the client sends only `dashReady`.
- **Checkpoints** come from the server's own 5 Hz samples of each root: a checkpoint counts when the root is inside its zone (radius 16, height 14) and it is the next one. Each zone spans the course, and at walking speed a sample lands every 3.2 studs, so honest players cannot slip through.
- **Falls:** the server sees y below 125 and moves the player to their last checkpoint. For 1 s after any server teleport the samples are ignored, because the client's old position can still arrive; a fall never counts as a strike.
- **Minimum finish time, 28 s.** That is 540 studs at 19.3 studs/s, below any honest run (33.75 s flat out, and a bounce saves about 2 s). A finish earlier than that is refused: one strike, back to the last checkpoint.
- **Speed check:** horizontal distance from the last *changed* sample must be at most `95 × dt + 12` studs (walk 16, largest knockback 70, margin). Measuring from the last change means a phone that freezes for 2 s and catches up is not punished. A breach is one strike, and the player goes back to their last checkpoint.
- **Strikes:** 3 in a round and the player is out of that round, with no accusation: "You are out of this round." The server logs the UserId. No kick, no save change.
- **Obstacles run on each client** from `workspace:GetServerTimeNow()`, because anchored parts moved by CFrame do not push characters. `DashRules.pose` gives every obstacle's position as a pure function of server time, so every client sees the same motion. Each client tests its own root with `DashRules.knock` and sets its own velocity (at most 70 studs/s). Moving platforms carry the player by adding the platform's frame movement to the root.
- **Fairness:** the schedule is the same for everyone and for every round. Hits are decided by what you see on your own screen, so a slow connection does not hit you with something you cannot see. Players do not collide with each other (collision group), so another player's lag never matters.
- **What an exploiter can do:** ignore knockback, or walk a little faster than the checks catch. **What they cannot do:** skip checkpoints, finish under 28 s, teleport, get more than 3 eggs a day, start a round alone, or affect anything another player owns. They can beat honest players to one Moon Egg. Accepted: the client is trusted for its own physics, as it already is for pads (decision 0008), and the prize is capped.
- The client never reports a hit, a checkpoint or a time.

### T8. UI

- **DASH button** on the HUD (7th quick button) opens the **DASH panel**: what it is, ready count (`2 / 3 ready`), READY / NOT READY, prizes today (`1 / 3`), and the prize eggs with PLANT. Gold dot when a prize egg can be planted now.
- **Ready players** see "Splash Dash starts in 12" on the HUD wherever they are, so the teleport never comes as a surprise.
- **Pad:** a floating label with the count and the state ("2 / 3 ready", "Starting in 12", "Race running").
- **During a round:** top-centre timer, checkpoint pips (`3 / 5`), "3, 2, 1, GO!", a splash and a short "Back to checkpoint 2" on a fall. HOME still works and leaves the round.
- **Results card:** places, names, times, who got the egg; large text, no input needed, closes on tap or after 6 s. Never "so close" or "you nearly won" (G4.3).
- **Winner below Level 10:** "You won a Moon Egg! It is saved for you. Plant it at Level 10."
- **Phone and gamepad:** the prompt (tap, gamepad X) and the normal jump button are the only inputs in the race. HUD text stays clear of the jump button and the top bar. The 7-button column must fit a 360-pixel-tall phone (`autoScale`).
- Display names only. No text input.

### T9. Edge cases

| Case | What happens |
|---|---|
| Ready player leaves during the countdown | Removed from ready; below 3 cancels the countdown and the pad says so. The others stay ready. |
| Ready player has no character at the start | Left out. Fewer than 3 left: back to idle, the others stay ready. |
| Fewer than 3 in the server | The button stays, greyed: "Needs 3 players". |
| Racer leaves or disconnects | Out of the round for good; a rejoin is a new session. Anything they already won stays. |
| 2 players left mid-round (3 started) | The round goes on. It continues down to 1 player, who still has to finish properly and can still win. The 3-player rule applies at the start only. This is no easier than two friends standing still. |
| Everyone left | The round ends at once, no prize. |
| Winner leaves before the prize saves | The egg is applied the moment the server accepts the finish, before anything can yield. It sits in the write queue and the leave write saves it. A server crash in the next 7 s can lose it, like any other change. |
| Profile offline or locked | Can race and win the card, but is not eligible, so the egg goes to the next eligible finisher. The panel says "Saving is off on this server, so prizes are off this visit." Coins are paid in memory, like anything else in that session. |
| Session goes offline mid-round | The egg is applied in memory and the player gets the normal offline notice. Rare. |
| Beds full | PLANT is greyed: "BEDS FULL". The egg waits in `prizeEggs`. Winning never needs a free bed. |
| Below Level 10 | The egg is saved and shown; PLANT reads `LEVEL 10`. |
| Already at the daily cap | Can still ready and race. Panel: "3 / 3 prizes today. You can still race for fun and coins." On finishing first: "You won! You have today's 3 Moon Eggs, so this one goes to the next finisher." |
| Coin cap reached too | "Finished!" with the time, no coins, no complaint. |
| Round during a weather event | No effect on the round, the prize or any odds. Prize eggs hatch later, under the weather at that moment. HOME is always there if a player wants to get back and hatch. |
| Round crosses midnight UTC | Eligibility is taken at the start; the grant uses the day of the finish. A capped player's new day does not reopen that round. |
| Character resets or dies in a round | The new character goes to the last checkpoint, not the plot. |
| HOME during a round | Leaves the round and teleports home. |
| Player is waiting for a plot | No session, so cannot ready. |
| Server shutdown | The round stops with no prize. Prizes already applied save in `BindToClose`. Racers need no teleport. |
| Server crash | No round state is saved, so nothing is stuck. |

### T10. Check values

| Check | Value |
|---|---|
| Ready 1, 2, 3 at t = 100 | countdown ends at 115 |
| Fourth readies at 110 | still 115 |
| Drops to 2 at 112, third again at 113 | cancelled at 112, new end 128 |
| Countdown ends at 115 | GO at 120, time limit at 240 |
| First finish at GO + 45 | round ends at GO + 65 at the latest |
| Finish at GO + 27.9 / GO + 28.0 | refused with a strike / accepted |
| Samples 0.2 s apart | 31 studs allowed, 32 is a strike |
| Frozen 2 s, then 100 studs | allowed (`95 × 2.2 + 12 = 221`) |
| Coins at 60.5 coins/s income | 3,630 |
| Coins at 0 income | 100 |
| Prizes today 2, then a win | 3, not eligible again until the next UTC day |
| `plantPrize` at Level 9 / Level 10 with a free bed | refused / planted, `ready = now + 3,600`, coins and stock unchanged |

### T11. Facts, assumptions, hypotheses

- **Fact:** anchored parts moved by CFrame do not push characters (Studio Director ruling, and the reason for client-side knockback).
- **Fact:** characters are client-simulated in Roblox, so root positions are client-owned (decision 0008).
- **Assumption:** the place keeps StreamingEnabled off. If it is on, teleports need `RequestStreamAroundAsync`. To check at staging.
- **Assumption:** `workspace:GetServerTimeNow()` agrees across clients to within a frame or two, close enough for the same obstacle motion.
- **Assumption:** a client can set its own root velocity reliably while the humanoid walks. Knockback feel is tuned at the greybox gate; obstacle data is not an economy value.
- **Hypothesis:** the prize brings friends into a shared activity with no way to lose anything.
- **Hypothesis:** a typical run takes 70 to 90 s, so 120 s is enough for most players to finish.

**Cut on purpose:** spectators, saved times or leaderboards, voting, more courses, power-ups, XP or quests for the Dash, rewards that scale with place beyond first.

**Cut order if the cycle runs long:** the Last Sprint sweeper; moving platforms become fixed stepping stones; the pad's floating label (the panel still shows it).
