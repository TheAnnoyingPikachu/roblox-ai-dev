# 0009: Neon Spire economy, saved profile and remote contract

Date: 2026-10-26
Status: Accepted (2026-10-26: SHANNON said "begin making the cyberpunk tycoon"; the recommended answers in the production plan, section 9, are adopted) by A06 and A09 for SHANNON (CLAUDE.md rule 8). Implements `docs/game-design/game5-gdd.md` (the GDD; section letters refer to it). Exact signatures: `docs/architecture/spire.md` section 3. Any change to a value below needs an amendment here.

## Amendments

- **2026-10-26 (SPIRE-003, A09): finalised.** Every value and remote is now listed here. Changes from the accepted draft, none of which changes a price, income, odds row or limit the GDD set:
  1. Saved field names: credits are stored as `coins`, cosmetic slots at the top level, the session lock as `lock = { session, at }` (the shared `MetaRules` and the copied Garden `Profiles` use these names); new field `bestFloors`.
  2. Writes: the flush snapshot carries only `lastSeen`; online income is a merged `earn` op re-applied like every other op, and earn ops alone wait for the 60 s autosave instead of the 7 s coalesce. (The draft's absolute credit snapshot would have dropped income credited while a write was in flight.)
  3. `setCompany` takes 5 indices (adds the brand colour `trim`); the Fx `hot` field `until` is `ends` (a Luau keyword).
  4. New values the GDD left open: decor items, cosmetics, contracts, daily and weekly rewards, refusal codes.
  5. DataStore limits re-checked against the Creator Docs on 2026-10-26 (below).

## Decision

### Economy

- **Currency:** credits (¢), saved as `coins`, clamped to 1e15. `lifetimeEarned` and `runEarned` clamped to 1e18. Start: 100 ¢ and 2 floors (lobby + an empty Data Farm floor).
- **Floor costs** (GDD C2, stored as data): 3: 129 · 4: 277 · 5: 596 · 6: 1,280 · 7: 2,760 · 8: 5,930 · 9: 12,700 · 10: 27,400 · 11: 58,900 · 12: 127,000 · 13: 272,000 · 14: 585,000 · 15: 1,260,000 · 16: 2,710,000 · 17: 5,820,000 · 18: 12,500,000 · 19: 26,900,000 · 20: 57,800,000 · 21: 124,000,000 · 22: 267,000,000 · 23: 575,000,000 · 24: 1,240,000,000 · 25: 2,660,000,000 · 26: 5,710,000,000 · 27: 12,300,000,000 · 28: 26,400,000,000 · 29: 56,800,000,000 · 30: 122,000,000,000. Max 30 floors; floor 1 is the lobby and is never built on.
- **Departments** (GDD C3), 4 slots per floor; a department may go on floor `n` when `2 ≤ n` and `n ≥` its lowest floor:

| Id | Module | Income L1 (¢/s) | Draw | Cost L1 | Lowest floor | XP tier |
|---|---|---|---|---|---|---|
| `data` | Server Rack | 1 | 1 | 15 | 1 | 1 |
| `fusion` | Fusion Cell | 0 | 0 | 150 | 3 | 1 |
| `ad` | Holo Projector | 6 | 2 | 600 | 5 | 2 |
| `synth` | Bio-Printer | 40 | 4 | 8,000 | 8 | 3 |
| `drone` | Courier Drone | 250 | 6 | 150,000 | 12 | 4 |
| `quantum` | Q-Mind | 1,600 | 10 | 3,000,000 | 17 | 5 |
| `orbital` | Uplink Dish | 10,000 | 16 | 60,000,000 | 23 | 6 |

- **Levels:** `LV = {1, 2, 4, 8, 16}`; upgrading from L to L+1 costs `cost × UP[L]`, `UP = {2, 5, 12, 30}`; max level 5. Fusion supply by level `{8, 18, 32, 50, 75}`; base supply 6. Power only blocks new modules (refused when `draw + d > supply`); it never reduces income. Selling a Fusion Cell that would leave draw > supply is refused.
- **Ad stacking:** an `ad` floor with ≥ 1 module adds +25% (+50% during Neon Night) to each income floor directly above and below (not ad, fusion or the lobby).
- **Plaza** (GDD D): grid 12 × 8 cells of 4 studs, walkway columns 5 and 6, at most 60 items of which at most 20 decor. `hype = min(Σ item hype, 10 × floors, 200)`, `hypeMult = 1 + hype / 100`, crowd `min(40, 2 + floor(hype / 5))`.

| Hype item | Cost | Hype | Size (w × d) | Max | Unlock (floors ≥) |
|---|---|---|---|---|---|
| `bench` | 100 | 1 | 1 × 1 | 12 | 2 |
| `palm` | 800 | 2 | 1 × 1 | 10 | 3 |
| `vending` | 6,000 | 3 | 1 × 1 | 8 | 5 |
| `noodle` | 40,000 | 5 | 2 × 1 | 6 | 7 |
| `arcade` | 300,000 | 8 | 2 × 2 | 4 | 10 |
| `fountain` | 2,500,000 | 12 | 2 × 2 | 2 | 13 |
| `maglev` | 20,000,000 | 20 | 3 × 2 | 1 | 17 |
| `billboard` | 150,000,000 | 25 | 2 × 1 | 2 | 21 |
| `idol` | 1,500,000,000 | 40 | 3 × 3 | 1 | 25 |

| Decor item (new; 0 Hype, no XP) | Cost | Size | Unlock (level ≥) |
|---|---|---|---|
| `lamp` Street Lamp | 150 | 1 × 1 | 1 |
| `bollard` Bollard | 50 | 1 × 1 | 1 |
| `planter` Planter | 300 | 1 × 1 | 2 |
| `arrow` Neon Arrow | 500 | 1 × 1 | 3 |
| `puddle` Puddle Tile | 100 | 1 × 1 | 4 |
| `trashbot` Trash-Bot | 1,000 | 1 × 1 | 6 |
| `arch` Cable Arch | 2,000 | 2 × 1 | 8 |
| `koi` Holo Koi | 2,000 | 2 × 2 | 10 |

- **Income** (GDD E1): `moduleIncome = income × LV[level] × eventMult` (2 for `data` and `quantum` during Data Boom); `floorIncome = Σ moduleIncome × floorMult`; `income = Σ floorIncome × hypeMult × shareMult`, `shareMult = 1 + 0.10 × shares`. Credited every second directly to the balance, fractions carried in server memory: **no unbanked pool** (avoids the GARDEN-006 M1 double-pay class).
- **Hot Data:** every 60 to 120 s (server `Random`, uniform), lasts 45 s, owner only, `Grab` prompt within 12 studs, pays `floor(30 × income)` and 5 XP; one at a time, on a filled non-fusion slot.
- **Offline:** `floor(income(no event) × 0.5 × min(away, 28,800))`, `away = max(0, now − lastSeen)`.
- **Refunds:** modules `floor(0.5 × spent)` (`spent` includes every upgrade at the price actually paid), plaza items `floor(0.5 × paid)`. Property: no sequence of buys and sells raises credits plus refund value.
- **Market Pulse:** window `floor(unix / 600)`, event active for its first 300 s, `Rng.int(Rng.seed(w, 7077), 1, 10000)`; weekday of the window start, `(floor(unix / 86400) + 3) mod 7`, Monday 0. Ids `normal`, `boom` (Data Boom), `neon` (Neon Night), `sale` (Flash Sale):

| Day (UTC) | normal | boom | neon | sale |
|---|---|---|---|---|
| Monday–Friday | 5500 | 2000 | 1500 | 1000 |
| Saturday, Sunday | 3500 | 2500 | 2000 | 2000 |

  Flash Sale: module purchases and upgrades cost `floor(price × 0.75)`; floors and plaza items unchanged.
- **IPO (M4; feature flag off until SPIRE-009):** floors ≥ 20; `gained = floor(sqrt(runEarned / 1e7))` ≥ 1; `shares = min(500, shares + gained)`; resets credits to 100, floors to 2, all modules and `runEarned` to 0; keeps everything else (GDD H).
- **XP:** module bought 2; upgrade 2 × new level; floor bought 10 × tier; plaza hype item placed 5; Hot Data 5; endorsement given 3 (first 10 a day). Level `floor(sqrt(xp / 40)) + 1`, cap 50 (MetaRules).
- **Rewards** (MetaRules, `scale(base, minutes) = max(base, floor(income(no event) × 60 × minutes))`): daily streak base `{100, 150, 200, 250, 300, 400, 800}` with minutes `{2, 3, 4, 5, 6, 8, 15}`; weekly bonus after 5 login days, base 1,000, 30 minutes. Contracts (3 a day from this pool, `MetaRules.questsFor`):

| Id | Label | Stat | Goal | Base | Minutes |
|---|---|---|---|---|---|
| `modules10` | Buy 10 modules | `modules` | 10 | 300 | 5 |
| `upgrades15` | Upgrade 15 modules | `upgrades` | 15 | 400 | 5 |
| `maxed1` | Reach level 5 on a module | `maxed` | 1 | 500 | 10 |
| `hot5` | Catch 5 Hot Data | `hot` | 5 | 500 | 10 |
| `plaza3` | Place 3 plaza items | `placed` | 3 | 300 | 5 |
| `floor1` | Buy a floor | `floors` | 1 | 300 | 5 |
| `earn1h` | Earn 1 hour of income | `earnSeconds` | 3,600 | 1,000 | 15 |
| `endorse2` | Endorse 2 companies | `endorse` | 2 | 200 | 5 |

  `earnSeconds` counts 1 per online second with income and 30 per Hot Data, so "1 hour of income" has a fixed goal.
- **Cosmetics** (`colours` chosen by SPIRE-004 from the art bible palette; ids unique across slots):

| Slot | Default | Unlock by level | Unlock by Shares | Price (¢) |
|---|---|---|---|---|
| `skin` | `glass` | – | `chrome` 1, `carbon` 10, `jade` 30, `prism` 75 | – |
| `crown` | `antenna` | `halo` 5, `needle` 12 | `satellite` 10 | `holoLogo` 2,000,000 |
| `lobby` | `marble` | `neonTile` 3, `carbonFloor` 10 | – | `goldLobby` 50,000,000 |
| `tiles` | `grid` | `hex` 4, `circuit` 15 | – | `chromeTiles` 500,000 |
| `trail` | `none` | `cyanTrail` 2, `magentaTrail` 8 | `goldTrail` 1 | – |

- **Company:** prefix 1..24 and suffix 1..16 (GDD G lists, in order), glyph 1..12, logo colour and trim 1..8 (the six art bible accents in table order, then Coral, Ice). A new profile takes 5 draws from `Rng.seed(seed, 4077)` with a server-random seed chosen once. Rename is free.
- **Social:** endorse once per company per UTC day, at most 30 given per day; gates `open`, `friends`, `closed` (default `open`).
- **Pacing targets:** GDD B, enforced by `tests/SpireBalance.spec.luau` within ±30% for floors 5, 10, 15 and 20.

### Saved profile (schema v1)

- Store `SpireProfile<suffix>`, key `player_<UserId>`; ordered store `SpireBoard<suffix>`, value `min(floor(lifetimeEarned), 2^53)`, written at most every 120 s when changed. Suffix `_studio` in Studio, `_staging` outside production, none only in `PRODUCTION_UNIVERSE_ID` (nil until SHANNON approves a production release), so staging and production never share data.
- Record:

```
{ schemaVersion, xp, coins, lifetimeEarned, runEarned, lastSeen,
  floors = { { d, m = { l1, l2, l3, l4 }, s = { s1, s2, s3, s4 } } },   -- floors[1] = lobby
  plaza = { nextUid, items = { { u, id, x, y, r, paid } } },
  shares, ipos, hotCaught, endorsements, bestFloors, gate,
  company = { p, s, glyph, colour, trim },
  skin, crown, lobby, tiles, trail, owned,
  endorsed = { day, ids }, daily = { streak, last }, week = { key, days, lastDay, claimed },
  quests = { day, progress, claimed },
  lock = { session, at } }                                              -- stored record only
```

- **Sanitising** (`SpireProgress.sanitize`): non-numbers → 0; numbers floored and clamped (coins 1e15, earned 1e18, xp 1e6, counts 1e6, shares 0..500); `lastSeen` in the future → now; `floors` length 2..30, floor 1 always the lobby with empty slots, a missing floor 2 becomes an empty Data Farm; a department that is unknown or not allowed at its floor number → empty `data` floor; slot levels 0..5, `spent` clamped to 0..the undiscounted total for that level and 0 when empty; if draw > supply, remove the highest-draw modules (highest floor first) refunding their full `spent` until it fits; plaza items with unknown ids, `r` outside 0..3, out-of-bounds, walkway or overlapping cells, a duplicate `u`, beyond an item's max or beyond 20 decor are dropped in list order (later items lose), count capped at 60, `paid` clamped to 0..cost, `nextUid` raised above every kept `u`; items are never dropped for unlock floors (an IPO keeps them); `company` indices out of range → the seeded default; unknown or locked cosmetics (level, Shares or not owned) → slot defaults; `gate` not in the list → `open`; `endorsed.ids` integers, at most 30; MetaRules fields by `MetaRules.sanitizeMeta`; `lock` dropped.
- **Size:** a maxed record (30 floors with 10-digit `spent` values, 60 items, every cosmetic owned, 30 endorsed ids, 8 quest stats) encodes to about 8 KB, under 0.2% of the 4,194,304-character value limit. SPIRE-005 logs the real size of a maxed test profile, which must stay under 12 KB.
- **Session lock** `lock = { session, at }`, stale after 120 s, claimed by the load's `UpdateAsync` (3 tries, 2 s and 4 s apart). Only the holder writes; every write refreshes `at`; the final write removes it. A session without the lock or the store runs offline (playable, unsaved, told) and never writes; a failed load never writes defaults.
- **Writes:** one `UpdateAsync` per flush re-reads and sanitises the record, re-applies the queued ops in order with their fixed inputs (`now`, `event`, amounts, the Hot Data bonus), ends with `snapshot` (`lastSeen = now`) and stores the result with the lock. A flush is due when a non-earn op is queued and 7 s have passed since the last write, or after 60 s (autosave); final write on leave and in `BindToClose` (all sessions in parallel within 25 s). Consecutive online-income credits merge into one `earn` op.
- No personal data beyond the profile keyed by UserId (decision 0003).

### DataStore limits check

- **Fact** (Roblox Creator Docs, "Error codes and limits", read 2026-10-26): per-server budgets per minute are standard read `60 + numPlayers × 40`, standard write `60 + numPlayers × 40`, ordered write `30 + numPlayers × 5`, ordered list (`GetSortedAsync`) `5 + numPlayers × 2`. Experience-wide per minute (game servers and Open Cloud together): standard read `300 + concurrentUsers × 40`, standard write `300 + concurrentUsers × 20`, ordered write `300 + concurrentUsers × 20`, ordered list `300 + concurrentUsers × 2`. Per key across all servers: 4 MB written and 25 MB read per minute. Value limit 4,194,304 characters; store and key names 50 characters. Storage: 500 MB + 1 MB per lifetime user.
- **Result for a 6-player server:** each player writes at most `60 / 7 + 1 ≈ 9.6` times a minute while building, once a minute when idle; `UpdateAsync` counts against both read and write: at most 58 a minute against 300 each. Experience-wide that is at most 9.6 writes per concurrent user against 20 per user plus 300. Per key: 9.6 × 12 KB ≈ 115 KB a minute against 4 MB. Ordered writes 3 a minute against 60; board reads 1 a minute against 17. Storage about 8 KB per user against 1 MB. There is no per-key cooldown; the 7 s coalescing is a budget choice. **Assumption:** the 8 KB size; SPIRE-005 measures it.

### Remote contract

- `ReplicatedStorage.SpireRemotes.Request: RemoteFunction`, `Request(action: string, arg: string?) -> (boolean, string?)`: accepted, or false and a refusal code.
- **Common checks, in order:** `busy` (no loaded session, or closing); `type` (`action` not a string, `arg` not nil or a string, `#arg > 40`); `rate` (token bucket per player: capacity 6, refill 4 per second; every request past the type check takes a token whatever its outcome; an empty bucket refuses without taking or returning one; prompts share the bucket); `action` (unknown); `arg` (a non-nil `arg` to a no-arg action, a missing `arg`, or no pattern match). Then world checks, then the rule. A refusal changes nothing.

| Action | `arg` pattern | Refused with (in order) |
|---|---|---|
| `buyFloor` | `^(%l+)$` dept | `max` (30 floors), `unknown`, `locked`, `credits` |
| `refitFloor` | `^(%d+):(%l+)$` floor, dept | `floor` (not an owned floor 2..), `unknown`, `same`, `locked`, `modules` |
| `buyModule` | `^(%d+):([1-4])$` floor, slot | `floor`, `occupied`, `credits`, `power` |
| `upgradeModule` | `^(%d+):([1-4])$` | `floor`, `empty`, `max`, `credits` |
| `sellModule` | `^(%d+):([1-4])$` | `floor`, `empty`, `needed` |
| `placeItem` | `^(%l+):(%d+):(%d+):([0-3])$` id, x, y, r | `unknown`, `locked`, `max`, `full`, `bounds`, `walkway`, `occupied`, `credits` |
| `moveItem` | `^(%d+):(%d+):(%d+):([0-3])$` uid, x, y, r | `unknown`, `same`, `bounds`, `walkway`, `occupied` (ignores its own cells) |
| `sellItem` | `^(%d+)$` uid | `unknown` |
| `lift` | `^(%w+)$` floor or `roof` | `zone` (server-side root not in an own lift zone), `arg` (not an owned floor or the roof, or the current one) |
| `home` | none | `zone` (no character) |
| `endorse` | `^(%d+)$` UserId | `target` (not in this server, or self), `gate`, `done` (already today), `max` (30 today) |
| `setGate` | `^(%l+)$` | `unknown`, `same` |
| `setCompany` | `^(%d+):(%d+):(%d+):(%d+):(%d+)$` prefix, suffix, glyph, colour, trim | `unknown` (out of range), `same` |
| `ipo` | none | `locked` (until M4), `ipo` (floors < 20 or gained < 1) |
| `claimDaily`, `claimWeekly` | none | `claimed` |
| `claimQuest` | `^([%w_]+)$` | `claimed` |
| `buyCosmetic` | `^([%w_]+)$` | `unknown`, `owned`, `locked`, `credits` |
| `equipCosmetic` | `^([%w_]+)$` | `unknown`, `locked`, `same` |

- **Prompts** (server `ProximityPrompt.Triggered`, distance on the server-side root): `Grab` (owner, spark active, slot still filled, ≤ 12 studs), `SkyDeck` (≤ 12 studs, owner or gate allows), `Build` (client only, no server effect).
- `SpireRemotes.Fx: RemoteEvent`, server to client, display only; the server ignores `OnServerEvent`. Payloads: `built { lot, kind, floor?, slot?, uid?, level? }`, `hot { lot, floor, slot, ends }`, `grabbed { lot, amount }`, `ticker { company, text }` (floors 10, 20, 30 and IPOs; company name only), `endorse { lot }`, `ipo { lot }`, `notice { text }` (one player).
- `ReplicatedStorage.SpireStatus: StringValue` (JSON) `{ event, eventLeft, forecast = { kind, kind }, window }`. `ReplicatedStorage.BuildInfo: StringValue` (commit SHA, or `dev` for local builds).
- Lot model attributes `Owner` (UserId, 0 when free) and `State` (public JSON from `SpireProgress.publicState`: floors with levels, plaza items without `paid`, company, cosmetics, gate, hype, endorsements, shares, level; at most 4 writes a second).
- Player attributes `Profile` (JSON), `ProfileOnline`, `Credits`, `Income`, `Floors`, `Level`, `XP`, `Lot`, `OfflineCredits`; leaderstats `Floors`, `Income`.
- The client never sends amounts, prices, levels, positions, outcomes or targets beyond the ids and cells above.

### Child safety (players under 18)

- No stealing, sabotage, trading, gifting, text input, custom chat, random loot, Robux prompts or paid items (decision 0002).
- Company names from fixed word lists only (GDD G). The ticker shows company names only.
- Endorse is the only cross-player effect; once per company per day, 30 per day.
- Light flicker ≤ 3 Hz everywhere; Reduce Flashing setting (GDD I4.6).

## Why

The values come from the pacing simulation in `docs/game-design/game5-pacing-sim.py` and match the first-session script in GDD K5. Direct crediting and the session lock reuse what the Egg Garden review taught. The string-arg Request contract and token bucket keep the remote surface as small as earlier games while allowing fast building clicks (hypothesis: Egg Garden's flat 0.35 s limit would feel slow when a player taps UPGRADE several times in a row). The new reward and decor values are small next to tower income and follow Egg Garden's scale pattern (hypothesis, checked at gates G1 and G3).

## Consequences

- `SpireConfig` holds every value; tests assert the tables above.
- Changing a price, income, odds or limit needs an amendment and must keep the balance spec green or update its targets with a reason.
- The token bucket is new to the studio; QA (SPIRE-008) checks that refused requests never refill it and that spam cannot exceed 4 per second sustained.
- The Garden `Profiles` pattern is reused with one behaviour change (earn ops wait for the autosave), which SPIRE-008 traces for races.
