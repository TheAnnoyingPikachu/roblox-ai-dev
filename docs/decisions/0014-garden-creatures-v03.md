# 0014: Egg Garden v0.3: 19 species, 8 rarities, widened Celestial Egg, Aurora Egg

Date: 2026-11-01
Status: **Proposed** for SHANNON (checkpoint `docs/checkpoints/GARDEN-V03.md`). Proposed by A11 (CLAUDE.md rule 8) on the Studio Director's roster of 2026-11-01, for SHANNON's request: "expand the amount of creatures and rarities, give them blender models and everything, also fix the effects of celestial rarity and make more rarities. finally make each creature make the sound of what animal it is, try keep it cute". Implements `docs/game-design/game4-gdd.md` section U; signatures in `docs/architecture/garden.md` 3.2, 6 and 9. Amends decisions 0008 and 0012: where they disagree with this record, this record wins.

## Decision

### Species and rarities (economy values)

- `GardenConfig.SPECIES` grows from 9 to 19 (GDD U1 is the one table). The nine existing species keep their ids, names, rarities and rates. New: `duck` 3, `lamb` 8, `hedgehog` 45, `deer` 250, `panda` 350, `unicorn` 800, `phoenix` 2500, `whale` 5000, `kirin` 7500, `axolotl` 25000 coins/s. Release value stays rate × 6.
- `GardenConfig.RARITIES` grows from 6 to 8 by appending `divine` (Divine, aqua 90, 230, 230) and `secret` (Secret, midnight 60, 55, 85). Existing `rarityIndex` values do not change; `HatchRules` LEGENDARY = 5 and `GardenConfig.RARE = 3` stay valid, so Divine and Secret are announced and count as rare hatches with no code change.
- `Species.cry: { id: number, pitch: number }?` is new display data in `GardenConfig` (architecture 3.2): nil until the clip's row is in `docs/assets/register.md`. Not an economy value; changing a cry needs no decision.

### Egg odds (economy values; basis points, GDD U2)

| Egg | Odds | Top, meter |
|---|---|---|
| `meadow` | bunny 5800, frog 2400, duck 1100, pup 500, lamb 100, cat 100 | cat, 50 |
| `forest` | frog 3000, pup 3000, lamb 1500, cat 1700, owl 500, hedgehog 300 | hedgehog, 30 |
| `sunset` | cat 3500, owl 2500, hedgehog 1500, fox 1700, turtle 300, deer 300, panda 200 | panda, 40 |
| `moon` | fox 4000, turtle 2500, deer 1500, panda 1000, lion 600, unicorn 350, dragon 50 | dragon, 100 |
| `star` | turtle 3000, panda 2500, lion 2500, unicorn 1500, dragon 400, phoenix 100 | phoenix, 25 |
| `celestial` | lion 6000, unicorn 2500, dragon 1200, phoenix 300 | phoenix, 10 |
| `aurora` | dragon 3500, phoenix 3000, whale 2000, kirin 1200, axolotl 300 | axolotl, 20 |

Prices, grow times, levels, stock and XP of the existing eggs are unchanged. `top` is the rarest species of each egg.

**Changed from the Director's table: Meadow** was bunny 5000, frog 2500, duck 1500, pup 800, lamb 100, cat 100. `tests/GardenRules.spec.luau` enforces the 0008 amendment (buy, hatch, release at most 60% of the price) with the Lucky Meter bounded from above; the Director's row gives 62.1% in Rainbow Shower by that bound and would fail the spec. The row above gives 56.4% (exact 54.2%).

### Celestial Egg, widened (amends 0012)

0012 fixed the Celestial Egg's species as "lion 8500, dragon 1500". **The rule is now "every Legendary and Mythic species"**: lion 6000, unicorn 2500, dragon 1200, phoenix 300, top phoenix, meter 10. Price 1,000,000,000, grow 28,800 s, Level 25, stock 5%, XP 1,000 and the fixed `celestial` mutation are unchanged. The published text "Every Celestial Egg hatches Legendary or Mythic with the Celestial mutation" stays true. A later Legendary or Mythic species joins this egg's odds by this rule, with a decision record for the numbers.

### Aurora Egg (new)

| Id | Price | Grow (s) | Unlock level | Stock per 300 s window | XP on hatch | Mutation | Top species | Lucky Meter |
|---|---|---|---|---|---|---|---|---|
| `aurora` | 5,000,000,000 coins | 43,200 | 32 | 3%, 1 | 3,000 | weather roll, none fixed | `axolotl` | 20 |

- Last in `EGGS` (position 8, stock index 7), so no existing egg's stock roll changes.
- The only source of `whale`, `kirin` and `axolotl`. It fixes no mutation, so `GardenConfig.indexable` and `fixedBy` are unchanged and no new Index pairs come from it beyond the species' four weather mutations.
- Lucky Meter applies (G4.4 and 0008 promise it on every egg): long-run axolotl share 6.6%.
- 60% rule: expected release about 38,000 coins, 0.0008% of the price.

**Changed from the Director's number: price 5,000,000,000, not 25,000,000,000.** See Pacing check. Level 32, grow 12 h, stock 3%, XP 3,000, odds and meter are the Director's.

### Index

80 entries: 19 species × 4 weather mutations + 4 Celestial pairs (`lion`, `unicorn`, `dragon`, `phoenix`). `INDEX_SIZE` 80, bonus 2% per entry, so at most ×2.6 (was 38 and ×1.76). The `golden` fence at 20 entries does not change.

### Saved profile: schema v2, unchanged

No new field, no `schemaVersion` bump, **no migration** (rule 7: nothing to approve beyond this design). New species, rarities and the egg are new ids in the existing fields: `creatures[].s`, `index[]`, `pity.aurora`, `stock.bought.aurora`. `GardenProgress.sanitize` already loops over `EGGS` and accepts any `GardenConfig.indexable` pair, so a save from before v0.3 loads exactly as it is and reads `pity.aurora = 0`. `tests/GardenProgress.spec.luau` must load a literal pre-0014 record and compare every field, and a record holding a new species through `sanitize` unchanged.

**Rollback (same as 0012):** a build older than 0014 sanitises unknown species and eggs away, so it would drop new creatures, their Index keys and an Aurora Egg in a bed, then write that back. Publishing v0.3 restarts every server; no rollback past 0014 without SHANNON.

### Remotes

No new `Request` action, `Fx` kind, `GardenStatus` field or attribute. `stock.aurora` appears in `GardenStatus.stock` through the existing loop; `adminGrant` (0013) accepts the new ids through `indexable` with no change.

### Display only (not economy; recorded so the contract is in one place)

- **Sounds** (GDD U7): one licensed cry per species, client only, through `ClientState.sound`, obeying the `sfx` setting; at the reveal (0.5 owner, 0.25 others), at banking (0.2, owner), idle within 60 studs every 12 to 30 s with one cry per 2 s across the garden (0.2), and on a tap in the admin catalogue. Ids only from ProSoundEffects and APMOfficial, registered before use. Cat, owl and duck have no clip yet.
- **Celestial and Golden looks** (GDD U8): the texture stays; no mutation changes `TextureID`, `Color` or `Material`. Celestial is a pulsing white-gold Highlight with halo, stars, light and rim; Golden a gold Highlight (fill 0.5) with Sparkles, taking a Highlight only while 8 are free.
- **Models** (architecture 9): `creature_<id>` Blender models for all 19, loaded through `Models.night` when ready, else the old generated mesh or the part fallback.

## Pacing check

`python docs/game-design/game4-v03-pacing-check.py`, the 0012 script with the roster added and the player model unchanged; median of 15 seeded runs over 90 days. Copied from the script's output on 2026-11-01.

**Fact (computed), exact:** return on buy, hatch and release, the spec's bounded worst case, and payback.

| Egg | Clear | Rainbow Shower | Spec bound | Avg coins/s | Payback s |
|---|---|---|---|---|---|
| `meadow` | 28.4% | 54.2% | 56.4% | 3 | 19 |
| `forest` | 15.9% | 30.3% | 32.8% | 12 | 33 |
| `sunset` | 13.1% | 24.9% | 26.7% | 75 | 40 |
| `moon` | 6.3% | 12.0% | 12.3% | 299 | 84 |
| `star` | 1.9% | 3.7% | 3.9% | 735 | 272 |
| `celestial` | 0.01% | 0.01% | 0.0% | 20,488 | 48,808 |
| `aurora` | 0.0008% | 0.0008% | 0.0% | 6,362 | 785,864 |

**Result (simulated):** first buys and income (coins/s at the end of the day).

| Player | Moon | Star | Level 25 | First Celestial | Level 32 | First Aurora | Day 45 | Day 90 |
|---|---|---|---|---|---|---|---|---|
| 30 min/day | day 3 | day 8 | day 13 | day 15 | day 20 | day 26 | 307,392 | 853,200 |
| 60 min/day | day 2 | day 5 | day 7 | day 10 | day 11 | day 18 | 926,120 | 1,658,800 |
| 180 min/day | 70 min | day 2 | day 3 | day 5 | day 4 | day 11 | 1,766,700 | 2,684,700 |

The 60 min row reproduces the GDD targets (Moon day 2, Star day 5). The first Celestial comes two days earlier than in 0012 (day 10, not 12) because every mid-game egg now carries a rarer species; nothing about the Celestial Egg moved it.

**Price:** the Director asked for the first Aurora 4 to 10 days after the first Celestial at 1 h/day, so day 14 to 20. Level 32 is reached on day 11 in every run, before any price is, so the level is not the gate and only the price moves the date.

| Price | First Aurora, 60 min/day | Days after the first Celestial |
|---|---|---|
| 2,500,000,000 | day 16 | 6 |
| **5,000,000,000** | **day 18** | **8** |
| 7,500,000,000 | day 20 | 10 |
| 10,000,000,000 | day 20 | 10 |
| 25,000,000,000 (Director) | day 26 | 16 |

5,000,000,000 was chosen: the middle of the window, five Celestials' worth, and still 11 days after at 30 min/day and 6 at 3 h/day. The late spread is set by stock (3% a window, about one in stock per 3 days at 1 h/day), not by price.

## Why

- Appending rarities and the egg, and keeping every old id, means no save changes, no stock reseeding and no change to the two rarity thresholds; the whole change is data plus display.
- Widening the Celestial Egg to a rule ("every Legendary and Mythic") instead of a list keeps its published promise true as the roster grows.
- The Aurora fixes no mutation because the roster already supplies the ceiling (Huge Rainbow Stardust Axolotl, 625,000 coins/s) and a second fixed mutation would double the Index cells for five species; a weather roll keeps the forecast board meaningful at the top.
- Cries live in `GardenConfig` so `HatchFx`, `CreatureFx` and the admin panel read one table and a spec can check it; they are numbers, so the module stays pure.

## Consequences

- **Income ceiling:** day 45 at 1 h/day is about 926,000 coins/s (0012 said 496,000; the roster alone gives 741,000), day 90 about 1.66M. `MAX_COINS` 1e15 holds for decades at these incomes and about a year at the theoretical cap of 32.5M coins/s. The 1B fence and 10B can come about a week sooner.
- **Leaderboard:** the Top Gardens board will be led by Aurora owners; 0013 grants can produce any of the 80 pairs for SHANNON.
- **Index cosmetics unlock earlier:** the `golden` fence (20 entries) is reached earlier in play since there are 80 entries, roughly Level 10 instead of about 14 at 1 h/day (assumption from the script; not pinned).
- **The Aurora is a collection egg:** its average hatch (6,362 coins/s) earns less than a Celestial's (20,488) at five times the price; what it sells is 12 Index entries (+24% income) and the Secret. Hypothesis: that is enough. If it sits unsold, the lever is a fixed `aurora` mutation under a new decision.
- Specs that pin the species list, rarity list, egg count, index count and the return table change (GDD U10); `tests/GardenRules.spec` checks 28 egg-weather pairs.
- The Secret colour is dark on purpose; the client must stroke or pill its text on tags and banners (GDD U1).
- Nothing in Splash Dash, weather tables, cosmetics prices or quests changes.

## Facts, assumptions, hypotheses

- **Fact:** the numbers above are computed by the committed script from the values in this record. **Assumption:** the script's player is close to a real one; it matches the two GDD targets it can be checked against; nothing has been measured on real players.
- **Assumption:** a 12 h grow with 3% stock gives the Aurora a "saw one, missed it" rhythm that is felt as rare rather than as absent; live data decides.
- **Hypothesis:** eight rarities read as more to collect, not as noise; the Index grid at 80 cells stays scannable with the rarity colour band.
