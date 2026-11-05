# 0016: Egg Garden: Petal Catch and the prize wheel (odds, caps, `wheelToday`, remotes)

Date: 2026-11-05
Status: **Proposed** for SHANNON (checkpoint `docs/checkpoints/GARDEN-WHEEL.md`). Proposed by A09 (CLAUDE.md rule 8) on the Studio Director's design of 2026-11-05, for SHANNON's request: "another small mini game that earns you a random egg from a wheel spin that people can play by themselves". Implements `docs/game-design/game4-wheel.md`; signatures in `docs/architecture/garden-wheel.md`. Extends 0012 (the `prizeEggs` store and the Level 10 planting rule apply unchanged). The schema bump to v3 is shared with the v0.4 decision (trading, charms, followers, milestones, naming); see "Saved profile".

## Decision

### Round (not economy values except the thresholds and the cap)

| Value | Number |
|---|---|
| Round length | 45 s |
| Drops | 40: 26 pink (+1), 4 golden (+3), 10 pinecones (−2, floored at 0), shuffled by seed; one per 1.0 s from `startAt + 2` |
| Fall | from 16 studs at 4 studs/s; catch band `y` 1 to 7 (1.5 s); catch radius 3.5 studs from the server's 5 Hz root sample |
| **Spin threshold / lucky threshold** | **12 / 24** (economy values: they set the spin rate) |
| **Spins per player per UTC day** | **3**; unlimited practice rounds after, with no wheel |
| Eligible | a saving session and under the cap, taken at the start of the round |

### Wheel (economy values; basis points, each column sums to 10,000)

| Wedge | Standard | Lucky | Prize |
|---|---|---|---|
| `meadow` | 3,600 | 2,000 | 1 Meadow Egg into `prizeEggs` |
| `forest` | 2,800 | 2,500 | 1 Forest Egg |
| `sunset` | 1,750 | 2,600 | 1 Sunset Egg |
| `moon` | 1,200 | 1,800 | 1 Moon Egg |
| `star` | 400 | 700 | 1 Star Egg |
| `celestial` | 20 | 25 | 1 Celestial Egg |
| `aurora` | 5 | 15 | 1 Aurora Egg |
| `coins` | 225 | 360 | `GardenProgress.scaled(p, 100, 10)`: 10 minutes of income, at least 100 |

- Rolled once on the server with `Rng`; the client animates to the server's wedge.
- Prize eggs plant from the egg's own unlock level with no price or stock check (0012). They are not tradable (G3; the v0.4 trading rules exclude `prizeEggs`).

**Changed from the Director's odds: star and above are lower** (Director: standard star 500, celestial 60, aurora 15; lucky star 1,000, celestial 150, aurora 50). See Pacing check. Meadow, Forest, Sunset and Coins moved by at most 100 bp to keep the columns at 10,000.

### Saved profile (schema v3, with v0.4)

```
wheelToday = { day, spins }   -- UTC day of the counter, spins applied that day; default { day = -1, spins = 0 }
```

- `GardenProgress.defaults` adds it; `sanitize` (after `dash`): `day` by `MetaRules.dayNumber`, `spins` by `MetaRules.count` up to `WHEEL.spinsPerDay`. A v2 record has no field and gets the default; no conversion job, as in 0012 and 0014.
- **`schemaVersion` becomes 3 in the same release as v0.4**, which adds its own fields; one bump, one checkpoint item, one restart-every-server publish. If v0.4 slips, this field ships alone and still bumps to 3 (the pattern is the same). The newer-`schemaVersion` guard that 0012 deferred to "the next schema bump" is due with v3; the v0.4 decision owns it, and this record relies on it.
- **Rollback:** a build older than this record drops `wheelToday` from a record it reads and writes that back: the player's spins that day reset to 3, nothing else. Prize eggs are in `prizeEggs`, which old builds already keep. Low risk; the restart rule of 0012 still applies.

### Spin op and idempotence

Every spin is one `Profiles.apply(player, "wheelSpin", op)`, `op = WheelRules.award(p, today, n, wedge)`, pure, capturing `today`, `n` (the spin's number that day, 1 to 3) and `wedge`. It applies only when the record's count for `today` is `n − 1` (or the record is on an older day and `n == 1`); otherwise it returns the record unchanged. Re-applying on the stored copy inside `UpdateAsync` is a no-op once the spin is in. `spinId = today × 10 + n` is the id in the `Fx` payload and the server log.

### Remote contract

- **`Request`:** one new action under the common checks.

  | Action | `arg` | Accepted when |
  |---|---|---|
  | `wheelStart` | nil | a session with a plot, no round running for this player, not racing, root within 12 studs of the stand (server position) |

- **Stand prompt:** one server `ProximityPrompt` "Play", through `admit`, the shared 0.35 s limit and the `wheelStart` handler.
- **Leaving:** `home` and `PlayerRemoving` drop the round; nothing is granted.
- **`Fx`** to the one player, display only: `wheelStart { seed, startAt, endAt, practice, spinsLeft }`, `wheelCatch { i, kind, score }`, `wheelOver { score, tier, spinsLeft }`, `wheelSpin { wedge, lucky, spinId, coins, spinsLeft }`.
- **`GardenStatus`:** no new field (rounds are per player). **Player attributes:** none new; `wheelToday` reaches the client in the existing `Profile` attribute.
- **Nothing else from the client.** It never sends a catch, a position, a score, a time or a wedge.

### Child safety

- G4 unchanged: no purchase, no paid odds, no luck boosts, odds published for both wheels, no near-miss animation or text, no failure sounds, no countdown to the next spin ("N spins left today" only), nothing exclusive.
- The round's timer is a game's own timer under the 0012 amendment of G4.7.
- Rounds are private; prizes cannot be passed on; the cap limits everything.

## Pacing check (Fact, computed; `docs/game-design/game4-wheel.md` W5)

Egg value = average hatch income at the U6 rates (Meadow 3, Forest 12, Sunset 75, Moon 299, Star 735, Celestial 20,488, Aurora 6,362 coins/s). Budget: 3 spins a day under one Moon Egg × 2 = 598 coins/s, so 199.3 per spin.

| Wheel | Director's odds, per spin | Final, per spin | Final × 3 |
|---|---|---|---|
| Standard | 222.3 | 127.0 | 381 |
| Lucky | 486.6 | 189.1 | **567** |

The Director's lucky Celestial alone (150 bp) was 307 coins/s. By level band the realised value is lower (only plantable eggs count; the worst band, Level 32 and up, is the table above). By egg price the expectation is 4.5M to 10.0M coins per spin, nearly all of it the 1 in 400 to 1 in 2,000 Celestial and Aurora wedges; the Director's brief measures income, a prize egg cannot be sold, and a Celestial win is the same step a bought Celestial is, a few days early. Hypothesis: a server story, not a lever; the two rows are the lever if live data disagrees.

## Why

- Reusing `prizeEggs`, `plantPrize` and the Dash award pattern means the wheel adds one saved field, one action and four display payloads; no new store, no new planting rule, nothing a client could ask for.
- A fixed drop composition makes every round able to reach lucky and makes the thresholds the only tuning lever.
- Rolling on the server and animating on the client keeps the wheel honest and the theatre cheap; the petal seed and the roll seed are separate so a datamined seed spoils nothing.
- Counting a spin only when a prize applies, with an `(today, n)` guard, gives idempotence without a new list or a new `Profiles` path.

## Consequences

- Odds, thresholds, the cap, the coins minutes and `wheelToday` follow the 0008 rule: changing them needs a decision record. Fall speed, band, radius, ring, patch position and props are feel values, tuned at the greybox gate with `WheelRules.spec` kept green.
- `GardenProgress.spec`, `GardenConfig.spec` and the schema version pin change; `Purity.spec` covers `WheelRules`.
- A player with 3 Dash prizes and 3 lucky spins a day has at most 897 + 567 coins/s of expected prize income a day; the Dash budget was set alone in 0012 and this record does not reopen it.
- GARDEN-006 finding N2 (a flush retrying past 10 s after leave can drop ops) applies to a spin as it does to a Dash prize; accepted the same way.

## Facts, assumptions, hypotheses

- **Fact:** the numbers above are computed from the odds in this record and the U6 rates (the one-line script is in the design doc's W5 derivation; re-derive if either changes).
- **Assumption:** the root's replication delay is well inside the 1.5 s band; widen the band at the feel gate if phones miss clear catches.
- **Hypothesis:** 12 and 24 give a spin to a first-timer and a lucky spin to a practised player; three short rounds a day read as a ritual, not a chore.
