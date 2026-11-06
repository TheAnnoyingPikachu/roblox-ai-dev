# 0015: Egg Garden v0.4: safe trading, charms and event weather, followers, Index milestones, pet names, schema v3

Date: 2026-11-05
Status: **Proposed** for SHANNON (checkpoint `docs/checkpoints/GARDEN-V04.md`). Proposed by A11 (CLAUDE.md rule 8) on the Studio Director's feature list of 2026-11-05 and SHANNON's brief: **no stealing or taking mechanics of any kind; trading limited so children cannot be scammed or made sad**; plus SHANNON's two additions (pet naming, egg looks). Implements `docs/game-design/game4-gdd.md` section V; signatures in `docs/architecture/garden.md` 3.9, 3.10, 4.5, 4.6, 5.1, 6.3, 7, 9.2. Amends decisions 0008 (child safety: "no trading" becomes "trading only as V1"; remote table; schema), 0012 and 0014 (Index 84, 7 weathers): where they disagree, this record wins.

## Decision

### Trading (GDD V1): the rules that make it safe

1. Roblox friends only, `IsFriendsWith` both ways, same server, within 15 studs for the whole trade, both sessions saving.
2. One creature for one creature. Never coins, eggs, prize eggs, cosmetics or vouchers. Favourites cannot be traded.
3. Fair by the server: value = `GardenRules.rate(c)` (base × mutation × size × charm); refused when the lower value is under 50% of the higher, with "That trade would not be fair to <name>".
4. Both press TRADE, a 10 s hold with CANCEL for either, then both CONFIRM (20 s). Cancel at any step, no reason needed. Invite 30 s, picking 120 s.
5. At most 3 completed trades per player per UTC day (`tradesToday`, undone trades count).
6. Undo by either player within 10 minutes, once per trade, no agreement needed, both present; a released creature cannot come back.
7. No text: four fixed emotes (thumbs up, heart, wave, no), one a second. The pet name travels with the creature.
8. A traded creature adds no Index entry, no XP, no coins, no quest stat.
9. Every trade and undo is in the `GardenTrades<suffix>` ledger (per player key, 30 kept) and in both profiles' `trades` (30 kept), shown in STATS.
10. The write order is ledger (both keys) → re-check → two idempotent `Profiles.apply` changes in one step, with a heal at the next load (V1.4), so a crash between the two flushes can neither duplicate nor lose a creature.

### Charms and weather (GDD V2; economy values)

- Charms `frosted` ×1.5 (Snowfall, 2500 bp), `blooming` ×2 (Petal Storm, 1500 bp), `stormy` ×3 (Thunder, 1000 bp); `rate` gains the factor; no Index entries. **The multipliers are the Director's; the chances are this record's** and are set so each rare weather's expected mutation × charm (1.468, 1.898, 1.644) stays under Rainbow Shower's 2.000, which keeps the 0008 amendment's 60% rule (worst pair still Meadow in Rainbow Shower, 56.4% bound).
- New weather mutation tables (bp): Snowfall 8800/1000/150/50; Petal Storm 8500/1000/0/500; Thunder 8800/800/300/100.
- Weather odds: weekday `clear 5200, sunbeam 2500, moonfall 1500, shower 500, snowfall 100, petals 100, thunder 100`; weekend raw `2900/3500/2000/1000/200/200/200` with `WEATHER_EVENT_BONUS` 800 moved from Clear to the week's event weather (`Rng.seed(week, 7777)`, week Monday-based). Existing weathers keep their odds.
- `moth` Lantern Moth, Rare, 55 coins/s, release 330, after `hedgehog` in `SPECIES`. Hatches only in a rare weather from Forest (`frog 3000 → 2700, moth 300`) and Sunset (`cat 3500 → 3200, moth 300`); `Egg.event` data, `HatchRules.oddsFor`. `INDEX_SIZE` 84.

### Followers (GDD V3; no economy value)

`fa` (favourited-at) on creatures; `Follower` player attribute (creature id); client-only visual copy; a client setting. No new remote.

### Milestones (GDD V4; economy values)

Claim at 20, 40, 60, 80 Index entries, once each: 5,000 coins + title "Hatchling Keeper"; 50,000 + `clover` pad skin (new `pad` slot, unlock `index = 40`); 1,000,000 + `starlit` fence (`index = 60`); `prizeEggs.aurora + 1` + title "Garden Legend". New `Request` `claimMilestone <20|40|60|80>`.

### Pet names (GDD V5)

`Request` `name "<creatureId>:<name>"`; pure validation (20 chars, `[A-Za-z0-9 '-]`), then `TextService:FilterStringAsync(...):GetNonChatStringForBroadcastAsync()` on the server, then `Profiles.apply` with the filtered text into creature field `n`. 10 s naming cooldown, 3 renames per creature per day (server memory). **Fact (Roblox Creator Docs, "Text filtering"; Community Standards): any user-generated text displayed to others must go through `TextService` filtering**; this is the game's first text input, and the server is the only writer. Names never appear in announcements or on the board.

### Remotes (adds to 0008's table)

| Action | `arg` | Accepted when |
|---|---|---|
| `tradePropose` | target UserId | V1.1 checks |
| `tradeAccept`, `tradeCancel`, `tradeConfirm` | nil | the state machine's rules (V1.3), within 15 studs |
| `tradePick` | own creature id | in `picking`; owned, not favourite |
| `tradeEmote` | `1`..`4` | in a live trade, 1 per second |
| `tradeUndo` | 16-hex trade id | V1.5 |
| `claimMilestone` | `20` `40` `60` `80` | `#index >= n`, not claimed |
| `name` | `<id>:<name>` | V5 (the one yielding action) |

New `Fx` kinds `trade` (to the two players), `tradeEmote` (to one); `hatch` and `announce` gain `c`; `GardenStatus.event`; player attribute `Follower`; creature attributes `C`, `N`. New DataStore `GardenTrades<suffix>`.

### Saved profile: schema v3 and its migration (rule 7: for SHANNON at the checkpoint)

```
schemaVersion = 3
creatures[i].c  = charm id, "none"          creatures[i].fa = favourited at, 0        creatures[i].n = filtered name, ""
trades          = { { id, at, with, gave, got, gotId, undone } }   -- newest last, at most 30; default {}
tradesToday     = { day, count }                                    -- default { day = -1, count = 0 }
milestones      = { ["20"] = true, ... }                            -- default {}
pad             = "plain"                                           -- cosmetic slot
```

**Migration of existing saves (v2 to v3): no conversion job, as 0012.** `GardenProgress.sanitize` starts from `defaults`, so a v2 record loads with `trades = {}`, `tradesToday` at day −1, `milestones = {}`, `pad = "plain"`, and every creature gains `c = "none"`, `fa = 0`, `n = ""`; every v2 field keeps its value and `schemaVersion` becomes 3 at the first write. `tests/GardenProgress.spec.luau` loads a literal v2 record (and the pre-0014 one) and compares every field. **Rollback:** a build older than 0015 that reads a v3 save drops `trades`, `tradesToday`, `milestones`, `pad`, `wheelToday` and the three creature fields (`c`, `n`, `fa`) **for good** on its first write: charms, names and trade records are erased (the ledger keeps the trades), the milestone coins become claimable again and the day's wheel spins reset. **Newer-schema guard (GARDEN-033, the guard 0012 deferred and 0016 relies on):** from this build on, `Profiles.load` refuses to write a record whose `schemaVersion` is above `GardenProgress.SCHEMA_VERSION` (`GardenProgress.isNewer`): the player plays it read-only in an offline session with the offline notice, so a v4 save is never written back by a v3 server. Older builds lack the guard, so publishing v0.4 still restarts every server. Publishing v0.4 restarts every server; no rollback past 0015 without SHANNON (same rule as 0012 and 0014).

## Why

- Trading as asked (friends, one for one, value-checked, double confirm with a hold, capped, undoable, ledgered, no text) leaves no lever a scam needs: there is nothing to misrepresent (the panel shows the server's value), nothing to rush (no timer pushes towards yes), nothing to pressure with (no chat), and nothing final for ten minutes.
- The ledger-first, idempotent-apply, heal-at-load order is the smallest design that survives a crash between two DataStore keys without a transaction; it adds one read per load and two writes per trade.
- Charms as a rolled layer keep the forecast board meaningful (new weathers to wait for) and keep every published rule true (odds on screen, no exclusives, 60% bound) with the Director's multipliers untouched.
- Pet names are filtered on the server with the broadcast filter and stored filtered, which is the platform's requirement and keeps every client a display.

## Consequences

- Specs that pin the species list (20), weather list (7), Index count (84), weather odds and the return table change (GDD V8); `GardenRules.spec` checks 49 pairs.
- `Profiles.load` now reads the ledger after login (one `GetAsync`); a DataStore outage skips the heal and tries again next load.
- The Index grid grows to 84 cells and the ODDS card gains a Moth row and a charm line during rare weather.
- Income ceiling: theoretical top creature 1,875,000 coins/s; `MAX_COINS` 1e15 still holds for months at the cap and decades at simulated incomes (GDD V6). Simulated 90-day income moves under 5%.
- The first filtered text input exists; moderation of names is Roblox's filter plus the ledger-free pad tag (names reach only players who can see the plot or the follower).

## Facts, assumptions, hypotheses

- **Fact:** every number above is computed by `docs/game-design/game4-v04-pacing-check.py` from the values in this record; 49 egg-weather pairs are under 60%.
- **Fact:** Roblox requires `TextService` filtering of user-generated text shown to others.
- **Assumption:** the DataStore budget holds (2 ledger writes per trade, 1 read per load); the script's player is close to a real one for the milestone dates.
- **Hypothesis:** a 50% fairness band, a 10 s hold and a unilateral 10-minute undo make the worst trade outcome mild regret a child fixes alone. **Hypothesis:** 1 in 10 Thunder hatches being Stormy feels like a treat, not a lottery.
