# 0008: Egg Garden profiles, coins, odds, remotes and child safety

Date: 2026-10-25
Status: Proposed by A09 for SHANNON (CLAUDE.md rule 8). Implements `docs/game-design/game4-gdd.md` (the GDD; section letters below refer to it) sections C to H and J; module map in `docs/architecture/garden.md`. Review before the first production release.

## Decision

### Saved profile (schema v1)

- **Stores:** `GardenProfile_studio` in Studio, `GardenProfile_staging` on live servers until `PRODUCTION_UNIVERSE_ID` is set in `src/garden/Profiles.luau`, then `GardenProfile`. An ordered store `GardenIncome<suffix>` holds each player's `floor(income)` for the "Top Gardens" board (the GDD H6 leaderboard ranks by income, not coins). Same suffix rule as decisions 0006 and 0007; separate from every other game's stores.
- **Key:** `player_<UserId>` in both stores.
- **Record:**

  ```
  { schemaVersion = 1, xp, coins, lastSeen, unbanked, nextId, bedCount, penSlots,
    beds = { { egg, planted, ready, waters, helps, lastWater } },  -- exactly bedCount entries; empty bed: egg = "", numbers 0
    creatures = { { id, s, m, z, placed, fav } },                   -- placed: pad number 1..penSlots, 0 = storage
    pity = { meadow, forest, sunset, moon, star },
    index = { "<species>:<mutation>", ... },
    stock = { w, bought = { forest, sunset, moon, star } },
    hatches, waters, likes, gate, fence, can, owned,
    helped = { day, count }, liked = { day, ids = { UserId, ... } },
    daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }
  ```

  Times (`lastSeen`, `planted`, `ready`, `lastWater`) are server `os.time()` seconds (UTC). `owned` is a map `{ [cosmeticId] = true }` as in MetaRules. No names, chat, positions or analytics. There is no `wins` field (see MetaRules below).
- **Sanitising** (`GardenProgress.sanitize(record, now?)`), exactly GDD H7, with these precise forms: numbers floored and clamped (XP 1,000,000; `coins` and `unbanked` 1e15; `hatches`, `waters`, `likes`, `nextId`, quest progress 1,000,000); `bedCount` 3 to 12, `penSlots` 6 to 20; `beds` trimmed or padded with empty beds to `bedCount`; a bed with an unknown egg is emptied; `ready` clamped to `[planted, planted + growTime]`; `waters` 0 to 5, `helps` 0 to 3; creatures with an unknown species, mutation or size are dropped; duplicate `id`s keep the first; `placed` outside `1..penSlots` or on a pad already taken becomes 0; then storage beyond 60 drops the lowest ids (oldest) first, so at most `penSlots + 60` are kept; `nextId` is above every kept id; unknown `index` keys and duplicates dropped; `pity[egg]` clamped 0 to that egg's meter; `stock.bought` counts clamped 0 to that egg's maximum stock; `gate` falls back to `open`; `fence` to `picket` and `can` to `tin` if unknown or locked; `owned` keeps only priced cosmetic ids; `liked.ids` keeps at most 30 numbers. When `now` is given, a `lastSeen` later than `now` becomes `now`. A missing or non-table record gives `GardenProgress.defaults(now or 0)`.
- **Defaults** (new profile): coins 100, xp 0, 3 beds, 6 pads, bed 1 holds the Starter Egg with `planted = now`, `ready = now + 8`; `lastSeen = now`, `unbanked = 0`, `nextId = 1`, all `pity` 0, gate `open`, fence `picket`, can `tin`, `stock = { w = -1, bought = {} }`.
- **Load:** `GetAsync` with three attempts (2 s, 4 s backoff). On failure, or without DataStore access, the session runs offline on an in-memory profile, writes nothing, and the Stats panel says saving is offline. No kick. The first operation on every load is `login` (offline and unbanked payout, below).
- **Writes (re-apply, as 0006):** every change is a pure function in `GardenRules`, `HatchRules` or `GardenProgress`. It runs on the in-memory profile at once and is queued; a flush runs the queued functions, in order, inside one `UpdateAsync` on the re-read, sanitised stored record. Random outcomes (hatch species, mutation, size) are rolled once on the in-memory profile; the queued function applies that fixed outcome (`HatchRules.apply`), so re-applying never re-rolls. Every queued function captures its own `now` and `today`, so the stored application is deterministic. If a queued function refuses on the stored record (coins already spent in another server), it returns the record unchanged and the in-memory profile is replaced by the stored result plus any functions queued after the flush started.
- **Write coalescing:** at most one `UpdateAsync` per player per 7 s. A flush happens when (a) ops are queued and 7 s have passed since the last write, (b) 60 s have passed since the last write (autosave, even with nothing queued), (c) the player leaves, or (d) `BindToClose` runs (all sessions in parallel, within its 30 s). Every flush ends with a `snapshot` op that sets `unbanked = floor(sum of pad pending)` and `lastSeen = now`, so every stored record is self-consistent (`coins + unbanked` = everything earned). The leave flush first banks every pad into coins, then sets `unbanked = 0`, `lastSeen = now`. The 0.35 s request limit already bounds queue growth; banking is merged into the queue like any op.
- **Leaderboard:** each player's `floor(income)` is written to `GardenIncome<suffix>` with `SetAsync`, at most every 120 s and only when it changed since the last write (best effort, no retry). The board reads `GetSortedAsync(false, 10)` every 60 s.

### DataStore limits check (the GDD Q assumption)

- **Fact** (Roblox Creator Docs, "Error codes and limits", read 2026-10-25): per-server budgets per minute are standard write (`SetAsync`, `UpdateAsync`, `IncrementAsync`) `60 + 40 × players`, standard read `60 + 40 × players`, ordered write `30 + 5 × players`, ordered list (`GetSortedAsync`) `5 + 2 × players`. Per-key throughput is 4 MB per minute written and 25 MB per minute read, measured over the last 60 s across all servers. The page lists no per-key minimum interval between writes.
- **Fact** (Roblox DevForum announcement "Removal of 6s Cool Down for Data Stores", 2023, devforum.roblox.com/t/2436230): the 6 s same-key write cooldown was removed for standard and ordered stores; the 2023 update documented the 4 MB / 25 MB per-key limits, with each request rounded up to the next 1 KB. That post quoted a lower write budget of `60 + 10 × players`.
- **Result:** the GDD's premise (a platform cooldown of about 6 s per key) is outdated; there is no per-key cooldown to stay under. The 7 s coalescing is **kept as a budget choice**, not a platform requirement. Worst case with 6 players: each player writes at most 60 / 7 + 1 ≈ 9.6 times a minute, 58 a minute for the server, against a budget of 300 (or 120 under the older, lower figure): under half even if every write retries once. The record is at most about 12 KB (80 creatures, 12 beds, 36 Index keys), so one key takes at most about 115 KB a minute against 4 MB. Ordered writes are at most 3 a minute against 60; the board reads 1 list a minute against 17. **Assumption:** the 12 KB size estimate; GARDEN-004 logs the encoded size of a full test profile to confirm it.

### Online income, offline income and payout on load

- `rate(creature) = baseRate(species) × mutationMult × sizeMult`; `indexMult = 1 + 0.02 × #index`; `income = (sum of rate over placed creatures) × indexMult`.
- Pads: each pad holds a pending float in server memory only (`GardenRules.Pads`). Every 0.2 s the pad of each placed creature gains `rate × indexMult × 0.2`. Pending belongs to the **pad**, not the creature: storing, releasing or replacing a creature leaves the coins on the pad, so nothing is lost. Banking (owner's root within 4.5 studs horizontally and 6 vertically of the pad centre) adds `floor(pending + 1e-9)` to coins and keeps the fraction; only the owner's root banks their pads.
- On load, `GardenProgress.login(p, now, today)` pays, in this order: `unbanked` from the stored record; then `offline = floor(income × 0.5 × min(away, 28,800) + 1e-9)` with `away = max(0, now − lastSeen)` and `income` from the loaded record; then sets `unbanked = 0`, `lastSeen = now`, and runs `MetaRules.login`. The `OfflineCoins` attribute shows `offline` only (unbanked was earned online and is added silently).
- Check values (GDD C3): a Big Golden Berry Cat and a Normal Sprout Bunny with 5 Index entries: income 60.5 coins/s; away 1 h pays 108,900; away 10 h pays 871,200.
- A crash loses nothing earned; at most the last 7 s of banking (and up to 60 s since the last write) is paid at the offline rate instead of the online rate.

### Economy and odds

All values live as data in `src/shared/GardenConfig.luau`; tests read the same numbers.

**Eggs**

| Id | Price | Grow (s) | Unlock level | Stock per 300 s window | XP on hatch | Top species | Lucky Meter |
|---|---|---|---|---|---|---|---|
| `starter` | not sold (new profile only) | 8 | – | – | 10 | – | – |
| `meadow` | 50 | 30 | 1 | unlimited | 10 | `cat` | 50 |
| `forest` | 400 | 180 | 2 | 100%, 2–4 | 25 | `owl` | 30 |
| `sunset` | 3,000 | 900 | 5 | 60%, 1–2 | 60 | `turtle` | 40 |
| `moon` | 25,000 | 3,600 | 10 | 30%, 1 | 150 | `dragon` | 100 |
| `star` | 200,000 | 14,400 | 18 | 10%, 1 | 400 | `dragon` | 25 |

Restock window `s = floor(unix / 300)`; for egg position `i` (forest 2, sunset 3, moon 4, star 5): `state = Rng.seed(s, 9001, i)`, `r, state = Rng.int(state, 1, 10000)`, in stock if `r ≤ chance × 100`, then `qty = Rng.int(state, min, max)`. Stock is per player: `stock.bought[egg]` counts that player's buys in window `stock.w`, reset when the window changes.

**Species** (GDD E1): `bunny` Common 1/s, `frog` Common 2, `pup` Uncommon 5, `cat` Uncommon 12, `owl` Rare 30, `fox` Rare 70, `turtle` Epic 180, `lion` Legendary 500, `dragon` Mythic 1,500. Release pays `floor(rate × 30 + 1e-9)` (rate without the Index bonus); a Big Golden Berry Cat pays 1,620.

**Species odds, basis points** (walk in this order; first cumulative total ≥ `r`, `r = Rng.int(1, 10000)`)

| Egg | Odds |
|---|---|
| `starter` | `pup` 10000, always Normal mutation and Normal size, no draws |
| `meadow` | `bunny` 6000, `frog` 3000, `pup` 900, `cat` 100 |
| `forest` | `frog` 4000, `pup` 3500, `cat` 2000, `owl` 500 |
| `sunset` | `cat` 4500, `owl` 3500, `fox` 1700, `turtle` 300 |
| `moon` | `fox` 5000, `turtle` 4000, `lion` 950, `dragon` 50 |
| `star` | `turtle` 5500, `lion` 4000, `dragon` 500 |

**Lucky Meter (pity):** if `pity[egg] ≥ meter − 1` the species is the top species and no species draw is taken; after the hatch `pity[egg] = 0` for the top species, else `+1`. So the top species is certain by hatch `meter`.

**Mutations by weather at the moment the server accepts the hatch, basis points**

| Weather id | Normal ×1 | Golden ×3 | Moonlit ×5 | Rainbow ×10 |
|---|---|---|---|---|
| `clear` | 9790 | 200 | 0 | 10 |
| `sunbeam` | 7450 | 2500 | 0 | 50 |
| `moonfall` | 7750 | 200 | 2000 | 50 |
| `shower` (Rainbow Shower) | 8500 | 500 | 0 | 1000 |

**Sizes:** `normal` ×1.0 8000, `big` ×1.5 1700, `huge` ×2.5 300 (model scale 1.0, 1.4, 2.0).

Draw order for one hatch, all from one state seeded by the server from `Random.new():NextInteger(1, 2^31 − 1)`: species (skipped when the meter forces it), mutation, size.

**Weather:** window `w = floor(unix / 600)`; an event is active for the first 300 s, else `clear`. `r = Rng.int(Rng.seed(w, 4242), 1, 10000)`. Weekday `(floor(w × 600 / 86400) + 3) mod 7`, Monday 0.

| Days (UTC) | `clear` | `sunbeam` | `moonfall` | `shower` |
|---|---|---|---|---|
| Monday–Friday | 5500 | 2500 | 1500 | 500 |
| Saturday, Sunday | 3500 | 3500 | 2000 | 1000 |

**Garden**

| Item | Cost |
|---|---|
| Bed 4 to 12 | 500; 2,000; 8,000; 25,000; 75,000; 200,000; 500,000; 1,200,000; 3,000,000 |
| Pen slot 7 to 20 | `300 × 2^k`, `k = penSlots − 6` (300 up to 2,457,600) |
| Storage | 60 creatures, free, does not earn |

**Watering:** cut `floor(0.05 × growTime)` (Meadow 1, Forest 9, Sunset 45, Moon 180, Star 720 s); `ready = max(now, ready − cut)`; 60 s cooldown per bed (anyone); 5 owner waters and 3 helper waters per egg; since `8 × floor(0.05 g) ≤ 0.4 g`, the GDD's 40% cap always holds and needs no separate counter.

**XP:** hatch per the egg table; new Index entry +50; own water +3; helper water +15 to the helper for their first 20 helper waters per UTC day, 0 after. Levels `floor(sqrt(xp / 40)) + 1`, cap 50 (decision 0006). Egg unlocks: Forest level 2 (40 XP), Sunset 5 (640), Moon 10 (3,240), Star 18 (11,560).

**Rewards** scale with the garden: `scaled(base, minutes) = max(base, floor(income × 60 × minutes + 1e-9))`, `income` at claim time.

| Reward | Base | Minutes |
|---|---|---|
| Daily streak days 1–7 (day 7 repeats while the streak holds) | 50, 75, 100, 125, 150, 200, 400 | 2, 3, 4, 5, 6, 8, 15 |
| Weekly (5 different UTC days, Monday–Sunday) | 500 | 30 |
| `hatch5` hatches 5 / `hatch15` hatches 15 | 100 / 150 | 3 / 6 |
| `water10` waters 10 / `water25` waters 25 | 100 / 150 | 3 / 6 |
| `collect50` collects 50 (pads banked with ≥ 1 coin) | 100 | 3 |
| `rare1` rareHatches 1 (Rare or better) | 150 | 5 |
| `mutant1` mutants 1 (any mutation but Normal) | 200 | 8 |
| `release3` releases 3 | 100 | 3 |

Check: daily day 3 pays 14,520 at 60.5 coins/s, 120 at 0.5, 100 at 0. Quest selection is `MetaRules.questsFor` over this 8-quest pool. Only `hatches`, `waters` and `likes` are stored totals; `collects`, `rareHatches`, `mutants`, `releases` exist only as quest progress.

**Cosmetics (Locker, coins only):** fences `picket` (default, level 1), `bamboo` level 3, `stone` 6, `hedge` 10, `crystal` 16, `golden` 20 Index entries, `candy` price 1,000,000, `rainbow` price 1,000,000,000; cans `tin` (default, level 1), `ducky` 4, `flower` 8, `moon` 14, `star` price 10,000,000, `galaxy` price 10,000,000,000. The GDD's "N coins" unlocks are prices (bought with `buyCosmetic`), matching its remote table and its "owned keeps only priced ids" rule.

**Likes:** once per owner per UTC day, at most 30 given per day; +1 to the owner's `likes`. No dislike.

### MetaRules changes (all optional; Relay and Night unchanged)

- `Cosmetic.index: number?`: unlocked when `#profile.index ≥ index` (a profile without `index` counts as 0).
- `Meta.wins` becomes `number?` and `Meta.index: { string }?` is added; `sanitizeMeta` writes `wins` only when the target profile has the field (Relay and Night defaults always do), and `isUnlocked` treats a missing `wins` as 0.
- `Config.maxCoins: number?` (default `MAX_COINS` = 10,000,000); used by `sanitizeMeta` and every claim. Garden sets 1e15.
- `Quest.minutes: number?`, `Config.dailyMinutes: { number }?`, `Config.weekly.minutes: number?`, `Config.scale: ((profile, base, minutes) -> number)?`. New `MetaRules.reward(config, profile, base, minutes?)` returns `config.scale(profile, base, minutes or 0)` when `scale` is set, else `base`; `claimDaily`, `claimWeekly` and `claimQuest` pay `reward(...)` (computed on the profile before the claim). Without `scale`, amounts are the base, so `tests/ProgressRules.spec.luau` and Night's specs pass unchanged.

### Remote contract

All under `ReplicatedStorage.GardenRemotes`, created by the server.

- **`Request`** (RemoteFunction): `Request(action: string, arg: string?) -> boolean`.
  - Common checks, in order: the player has a loaded session and a plot; `action` is a string; `arg` is nil or a string of at most 32 characters; at most one request per 0.35 s per player (shared with the bed prompts; refused requests inside the cooldown do not reset it); `action` is in the table; a non-nil `arg` to an action that takes none is refused; an id `arg` must match `^%d+$`. Anything else returns false and changes nothing.

  | Action | `arg` | Accepted when (server checks, then the pure rule on the server's profile) |
  |---|---|---|
  | `buyEgg` | egg id (not `starter`) | root within 25 studs (horizontal) of the cart; `level ≥ unlock`; buys this window < stock; coins ≥ price; an empty bed exists. Planted in the lowest empty bed, `planted = now`, `ready = now + growTime` |
  | `buyBed` | nil | `bedCount < 12`; coins ≥ next bed cost |
  | `buyPenSlot` | nil | `penSlots < 20`; coins ≥ next slot cost |
  | `place` | creature id | owned, in storage, a pad is free (goes to the lowest free pad) |
  | `store` | creature id | owned, placed, storage has fewer than 60 |
  | `release` | creature id | owned, not a favourite; pays the release value |
  | `favourite` | creature id | owned; toggles `fav` |
  | `like` | target UserId | target is in this server with a loaded profile; not self; target's gate allows the liker; liker has not liked them today; liker has given < 30 today |
  | `setGate` | `open`, `friends`, `closed` | always |
  | `home` | nil | has a character with a root; the server moves it to the player's plot gate |
  | `claimDaily`, `claimWeekly` | nil | MetaRules rules, scaled amounts |
  | `claimQuest` | quest id | today's quest, progress ≥ goal, not claimed |
  | `buyCosmetic` | cosmetic id | priced, not owned, coins ≥ price |
  | `equipCosmetic` | cosmetic id | unlocked; equips into its slot (`fence` or `can`) |

- **Bed prompts** (server `ProximityPrompt.Triggered` on each bed's soil part; same session and rate-limit checks):
  - `Hatch`: the triggering player owns the plot; root within 12 studs of the bed; bed ripe; garden not full (pen and storage both full refuses with a `notice`). Weather read with `WorldRules.weatherAt(os.time())` at acceptance.
  - `Water`: root within 12 studs; bed growing; 60 s since `lastWater`; owner: `waters < 5`; others: owner's gate allows them (`friends` uses `Player:IsFriendsWith`, cached per pair per session) and `helps < 3`. The bed change is applied to the owner's profile; the helper XP to the helper's.
- **`Fx`** (RemoteEvent, server to clients, display only): `Fx:FireAllClients(kind, data)` for `hatch { owner, bed, id, s, m, z }`, `collect { owner, pad, amount }`, `water { owner, bed, by }`, `announce { name, s, m, z }`, `like { owner, by }`, `release { owner, id }`; `Fx:FireClient(player, "notice", { text })` for refusals that need words ("Your garden is full: release or store a creature"). The server ignores `Fx.OnServerEvent`. `owner` and `by` are UserIds; `name` is a display name.
- **`ReplicatedStorage.GardenStatus`** (StringValue, JSON, server-written each second when changed): `{ weather, weatherLeft, forecast = { kind, kind }, stockLeft, stockWindow, stock = { forest, sunset, moon, star } }`. `weatherLeft` seconds until the current weather changes; `forecast` the next two windows' event kinds; `stockLeft` seconds until the next restock; `stock` this window's quantities (0 = out of stock; Meadow is always unlimited and absent). Each client computes its own stock left from its profile's `stock`.
- **Player attributes** (server-written; clients read only): `Profile` (JSON), `ProfileOnline`, `Coins`, `Income`, `Level`, `XP`, `Plot` (1 to 6), `LastReward` (text), `OfflineCoins` (set once on join). Leaderstats: `Income` (StringValue, short format), `Index` (IntValue).
- **Plot attributes:** each plot model `Owner` (UserId, 0 when free) and `Gate`; each pad part `Pending` (floored, 1 Hz); bed and creature attributes in `docs/architecture/garden.md`.
- The client never sends amounts, prices, outcomes, positions or targets beyond the ids above.

### Child safety (players under 18)

- **No stealing, trading or gifting.** No action moves, lowers or removes anything from another player's profile. The only cross-player effects are a helper's water (shortens the owner's grow time) and a like (+1). Trading needs a separate decision record with two-sided confirmation, value checks, `PolicyService` and moderation support.
- **No Robux, paid items, paid odds or luck boosts** (decision 0002). `MarketplaceService` is not used anywhere in `src/garden` or `src/garden-client`.
- **Published odds:** every cart egg has a labelled ODDS button showing species percentages to two decimals (summing to 100.00%), the Lucky Meter (`pity / meter`), size odds and the current weather's mutation table; the forecast board and Index show every weather's table. The client reads these from `GardenConfig`, the same data the server rolls from. Odds change only through the published weather and weekend tables.
- **Pity:** the Lucky Meter guarantees each egg's top species within its published number of hatches.
- **No pressure:** no near-miss reveals (the reveal never flashes other creatures), no slot sounds, no "so close" text, no limited-offer pop-ups, countdowns only on the restock and weather boards. Every species and mutation is hatchable on any day. Offline coins and ripe eggs never expire.
- **No text input or custom chat;** names shown are Roblox display names; Roblox's filtered chat stays on. The `closed` gate blocks all water and likes from others; a disallowed player inside the plot for more than 1 s is moved outside the gate.
- **Anti-exploit:** every world action is server-validated against the server's profile and the server's view of the root position (cart 25, beds 12, pads 4.5 / 6); helper XP is capped at 20 waters a day and likes at 30 a day and 1 per owner, so alt accounts gain almost nothing.

## Why

- Offline and online income are the core of the genre; keeping pending coins on the server and saving `unbanked` in every write means a crash costs nothing and an exploiter can at most bank their own coins faster.
- Rolling once and re-applying a fixed outcome keeps the 0006 re-apply pattern safe for random rewards.
- Extending MetaRules with optional fields keeps one tested implementation of daily, weekly, quests and cosmetics for three games, with no behaviour change for Relay or Night.
- Coins reach 1e15 within the economy (Galaxy can costs 1e10), hence the per-config coin cap.

## Consequences

- Changing prices, odds, meters, grow times, reward amounts, the level curve, record fields or the remote contract needs a new decision record; new fields need a `schemaVersion` bump and a step in `GardenProgress.sanitize`.
- Any `MetaRules` change is a Relay and Night change too; their specs must stay green.
- Root positions are client-owned physics; distance checks use the server's replicated root, so a teleporting exploiter can reach the cart or their own pads faster but cannot touch another player's profile.
- `PRODUCTION_UNIVERSE_ID` must be set, with SHANNON's approval, before a production release; the `garden-staging` publish environment needs its variables and secret set by a human.
