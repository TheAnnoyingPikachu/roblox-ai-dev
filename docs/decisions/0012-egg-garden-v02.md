# 0012: Egg Garden v0.2: Celestial Egg, Splash Dash prizes, schema v2 and remotes

Date: 2026-10-31
Status: Proposed by A09 for SHANNON (CLAUDE.md rule 8), on the Studio Director's rulings of the same date. Implements `docs/game-design/game4-gdd.md` sections S and T; signatures in `docs/architecture/garden.md`. Amends decision 0008: where the two disagree, this record wins. The save schema step is a player-data migration, so it waits for SHANNON's approval at the GARDEN-011 checkpoint (rule 7).

## Decision

### Celestial Egg

| Id | Price | Grow (s) | Unlock level | Stock per 300 s window | XP on hatch | Top species | Lucky Meter |
|---|---|---|---|---|---|---|---|
| `celestial` | 1,000,000,000 coins | 28,800 | 25 | 5%, 1 | 1,000 | `dragon` | 10 |

- **Odds:** `lion` 8500, `dragon` 1500 (published on the ODDS card, with the guarantee).
- **Mutation:** new `celestial`, ×20, last in `MUTATIONS`. New field `Egg.mutation`: an egg that sets it hatches that mutation always, with no draw, and the weather has no effect. No weather table contains `celestial`, so nothing else can roll it. Weather tables stay 4 rows summing to 10,000, in `MUTATIONS` order with egg-only mutations skipped.
- **Lucky Meter applies.** G4.4 and decision 0008 promise it on every egg, and `HatchRules.rollSpecies` returns the first species with no draw for an egg without a meter, so without one every Celestial would be a lion. Meter 10 gives a long-run dragon share of 18.7%.
- **Index:** 38 entries (36 + `lion:celestial` + `dragon:celestial`), `INDEX_SIZE` 38, up to ×1.76. `GardenConfig.indexable(species, mutation)` is the single definition; `golden` fence at 20 entries does not change.
- **Stock:** position 7 in `EGGS`, stock index 6, so `Rng.seed(s, 9001, i)` for every existing egg is unchanged.
- **60% rule (0008 amendment):** expected release is about 93,000 coins, 0.01% of the price in every weather. The spec must use the fixed mutation for this egg, not the weather table.

**Changed from the Director's suggestion: price 1,000,000,000, not about 2,500,000.** The rest (level 25, grow 8 h, rare stock, lion 85 / dragon 15, mult 20) stands; stock is 5%. See Pacing check.

### Splash Dash economy

| Value | Number |
|---|---|
| Players to start | at least 3 ready, at most 6 |
| Countdown, start hold, time limit, finish grace | 15 s, 5 s, 120 s, 20 s |
| Prize | 1 Moon Egg to the first eligible finisher, stored in `prizeEggs` |
| Prize cap | 3 per player per UTC day |
| Coins | every other finisher: `GardenProgress.scaled(p, 100, 1)` (1 minute of income, at least 100) |
| Coin cap | 6 per player per UTC day |
| Plant gate | the egg's own unlock level (Level 10 for Moon); no price, no stock check |
| Minimum finish, speed limit, strikes | 28 s; `95 × dt + 12` studs; 3 |

- **Eligible** = under the prize cap and a saving session, taken at the start of the round. A first finisher who is not eligible stays the winner on the card; the egg goes to the next eligible finisher in the grace time.
- No XP, quests or Index entries come from the Dash, so a solo player misses nothing that cannot be got elsewhere.

**Changed from the Director's ruling: prize eggs are planted from Level 10, not at any level.** The ruling asked for this adjustment if the check called for it; it does. Stock is still skipped, and the prize is awarded and saved at any level.

### Saved profile (schema v2)

New fields next to the v1 fields of decision 0008:

```
schemaVersion = 2
prizeEggs = { [eggId] = count }          -- only sold eggs, count >= 1; default {}
dash = { day, prizes, coins }            -- UTC day of the counters; default { day = -1, prizes = 0, coins = 0 }
```

`pity.celestial` and `stock.bought.celestial` appear through the existing loops over `EGGS`. The envelope `lock` is unchanged.

**Sanitise step** (`GardenProgress.sanitize`, after `liked`):

- `prizeEggs`: for each egg with a price, `MetaRules.count(record.prizeEggs[id], 1_000_000)`, kept if at least 1. Anything else dropped. A prize egg is never cleared by the daily counters.
- `dash`: `day` by `MetaRules.dayNumber`, `prizes` and `coins` by `MetaRules.count` up to their caps.
- `creatures` and `index`: a pair that fails `GardenConfig.indexable` is dropped, like an unknown id.
- `sanitize` must keep both new fields or every flush loses them (`Profiles` replaces the session profile with the sanitised stored result).

**Migration of existing saves (v1 to v2):** there is no conversion job. `sanitize` starts from `defaults`, so a v1 record without the new fields loads with `prizeEggs = {}`, `dash` at day −1 and `pity.celestial = 0`, and every v1 field keeps its value. `schemaVersion` becomes 2 at the first write. `tests/GardenProgress.spec.luau` must load a literal v1 record and compare every field.

**Rollback and old servers (data-loss risk):** a pre-0012 build sanitises unknown eggs, mutations and fields away. If such a build reads a v2 record it empties a bed holding a Celestial Egg, drops Celestial creatures and their Index entries, and removes `prizeEggs` and `dash`, then writes that back. So:

- Publishing v0.2 must restart every server, so no old build is running beside it. `publish.yml` does this only when `ROBLOX_RESTART_SERVERS` is true; otherwise restart by hand in Creator Hub > Servers, on staging and production.
- No rollback past 0012 without SHANNON. Fix forward instead.
- A guard that refuses a record with a newer `schemaVersion` was cut for now: old builds do not have it, so it cannot help this release. Add it with the next schema bump.

**Size:** the record grows by under 100 bytes. Prize and coin writes use the normal queue, at most one op per finisher per round, which does not change the 0008 budget.

### Remote contract

- **`Request`:** two new actions, under the existing common checks.

  | Action | `arg` | Accepted when |
  |---|---|---|
  | `dashReady` | nil | toggles ready; refused for a racer still in a running round |
  | `plantPrize` | egg id | `prizeEggs[egg] >= 1`, `level >= egg.level`, an empty bed exists. Lowest empty bed, `planted = now`, `ready = now + grow`; coins and stock unchanged |

- **Ready pad:** one server `ProximityPrompt` "Ready", sharing the 0.35 s limit and the `dashReady` handler.
- **Leaving a round:** the existing `home` action also leaves the round.
- **`Fx`:** `dashCheckpoint { cp, total }` and `dashSplash { cp, reason }` to one racer (`reason` is `"fall"` or `"check"`); `dashFinish { by, name, place, time, egg, coins }` and `dashOver { winner, prize, reason }` to all clients. Display only.
- **`GardenStatus`:** new field `dash = { phase, ready, need, at, goAt, racers }`: `phase` is `idle`, `countdown`, `starting` or `racing`; `ready` and `racers` are UserId lists; `need` is 3; `at` and `goAt` are `workspace:GetServerTimeNow()` times, 0 when unused.
- **Player attributes:** none new. `prizeEggs` and `dash` reach the client in the existing `Profile` attribute.
- **Nothing else from the client.** It never sends a hit, a position, a checkpoint, a time or a result.

### Child safety

- G4.7 and the 0008 "no pressure" rule now also allow a Splash Dash round's own start and finish timers. A round is a game, not an offer: no timer ever counts down to a purchase or a daily reset.
- No near-miss text on results; odds published for the new egg as for every other.
- Rare stock stays per player and repeats about 14 times a day; nothing is exclusive forever.
- Players cannot touch each other in the race. Prizes cannot be passed to anyone. The daily cap limits friends taking turns.
- The player-facing name never uses the TV show's trademark.

## Pacing check

`python docs/game-design/game4-pacing-check.py`. A good-but-not-perfect player, median of 15 seeded runs, one hatch or planting per 10 s of walking and watching. Copied from the script's output on 2026-10-31.

**Fact (computed), exact:** return on buy, hatch and release, and payback.

| Egg | Clear | Rainbow Shower | Avg coins/s | Payback s |
|---|---|---|---|---|
| `meadow` | 27.4% | 52.3% | 3 | 19 |
| `forest` | 12.1% | 23.0% | 9 | 44 |
| `sunset` | 8.3% | 15.9% | 48 | 63 |
| `moon` | 4.9% | 9.3% | 233 | 107 |
| `star` | 1.4% | 2.7% | 537 | 373 |
| `celestial` | 0.01% | 0.01% | 15,521 | 64,429 |

**Result (simulated):** first buys. Existing tiers are the same with or without the new egg.

| Player | Moon | Star | Level 25 | First Celestial | Income day 45, without / with |
|---|---|---|---|---|---|
| 30 min/day | day 3 | day 8 | day 13 | day 17 | 24,211 / 185,351 |
| 60 min/day | day 2 | day 5 | day 7 | day 12 | 42,752 / 496,000 |
| 180 min/day | 70 min | day 2 | day 3 | day 6 | 73,386 / 915,600 |

The 60 min/day row reproduces the GDD targets (Moon day 2, Star day 5), which is the check that the model is usable.

**Price:** at Level 25 a player earns about 8,700 coins/s, or 150M to 280M coins a day with offline pay. 2,500,000 is under 5 minutes of that and cheaper than the 12th bed, so it is no goal.

| Price | First Celestial, 60 min/day | 180 min/day |
|---|---|---|
| 2,500,000 | day 10 | day 3 |
| 200,000,000 | day 10 | day 3 |
| 1,000,000,000 | day 12 | day 6 |
| 2,000,000,000 | day 15 | day 8 |

1,000,000,000 was chosen: it moves the heaviest players from day 3 to day 6, matches the Rainbow fence (the existing long-term coin goal) and keeps payback rising.

**Free eggs:** worst case, all 3 prizes every day from day 1, 60 min/day.

| Planted from | Sunset | Star | Level 25 | Income day 1 | Day 2 | Day 7 |
|---|---|---|---|---|---|---|
| no prizes | 14 min | day 5 | day 7 | 553 | 1,212 | 7,760 |
| Level 1 | 25 min | day 5 | day 7 | 1,174 | 2,749 | 13,096 |
| Level 5 | 14 min | day 5 | day 7 | 515 | 2,630 | 12,236 |
| Level 10 | 14 min | day 5 | day 7 | 553 | 2,454 | 11,317 |

Without a gate, a one-hour egg holds one of 3 beds through the first 40 minutes, then income doubles in hour one. Level 10 leaves the first hour unchanged and adds no new number. Level gates hold Star and Level 25 in place in every row.

## Why

- Level and stock already gate the top of the curve, so price is only a coin goal, and it must be sized against income at that level rather than against the Star's price.
- One new field on `Egg` keeps the rule in data: `HatchRules` needs one branch, and weather tables, the forecast board and the odds rows stay as they are.
- Leaving `celestial` out of weather tables makes "nothing else can roll it" structural, not a 0 in a table.
- Running obstacles on clients from server time avoids streaming physics from the server, and means the race needs no new remote traffic beyond the existing samples. The cost is that the client is trusted for its own physics, which is bounded by the checks and the cap.
- Awarding the egg at the finish, in memory and in the queue, reuses the re-apply pattern: the leave write and `BindToClose` carry it with nothing new.

## Consequences

- Prices, caps, meters and the new record fields follow the 0008 rule: changing them needs a decision record. Obstacle timings, zone sizes and course layout are not economy values and may be tuned at the greybox gate, in the same task, with `DashRules.spec` kept green.
- `GardenConfig.spec`, `GardenRules.spec`, `HatchRules.spec` and `GardenProgress.spec` change where they pin the egg list, mutation list, weather order and schema version.
- Income above about 40,000 coins/s now exists from about day 12. The Top Gardens board will be led by Celestial owners. Offline pay and `scaled` rewards scale with it; `MAX_COINS` 1e15 is not at risk (1,000,000 coins/s for a year is about 1e13 with offline limits).
- After Level 25 a Moon Egg prize is worth little. Kept for v0.2; a checkpoint item.
- GARDEN-006 finding N2 is still open: a flush still retrying more than 10 s after leave can have its ops dropped. A prize in such a flush would be lost during a DataStore outage. Accepted for v0.2; the fix belongs in `Profiles.finish`.
- The session lock (0008) is unchanged. An offline or locked session writes nothing, which is why it is not eligible for the egg.

## Facts, assumptions, hypotheses

- **Fact:** the numbers above are computed by the committed script from `GardenConfig` values copied into it. **Assumption:** the script's player is close to a real one; it matches the two GDD targets it can be checked against, and nothing has been measured on real players.
- **Assumption:** 90% of pad coins are collected online; hatching is not timed to weather; players spend on the dearest affordable egg.
- **Hypothesis:** 12 days is a satisfying wait for the top egg, not a discouraging one. Live data decides; lowering the price later is easy, raising it is not.
