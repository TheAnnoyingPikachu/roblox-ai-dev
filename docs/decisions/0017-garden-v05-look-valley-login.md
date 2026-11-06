# 0017: Egg Garden v0.5: UI kit, valley and spawn, login reward tracks with exclusive eggs

Date: 2026-11-05
Status: **Proposed** for SHANNON (checkpoint `docs/checkpoints/GARDEN-V05.md`). Proposed by A11 (CLAUDE.md rule 8) on SHANNON's brief of 2026-11-05 (UI overhaul, cooler valley, spawn fix, large cherry blossoms and hills, weekly and monthly login rewards with exclusive eggs: GDD section X quotes it). Implements GDD section X; signatures in `docs/architecture/garden.md` 3.11, 4.7, 6.4, 9.3. Amends 0008 (H5 rewards, remote table, schema), 0012 item 3 (prize-egg plant gate, for the two login eggs only), 0014 and 0015 (roster 26, Index 108): where they disagree, this record wins. Hard rules unchanged: no stealing, G4 (no countdown pressure, no purchases), trading only as V1.

## Decision

### UI (GDD X1; no economy value)

One client module `src/garden-client/UiKit.luau` builds every widget (panel with ribbon and close X, tabs, 3D button, icon button with badge, coin pill, level ring, card, toast, chip, start menu); `Menu`, `Hud`, `TradeFx`, `DashFx` compose it. Every existing panel keeps its function and its requests (the X1.4 mapping). 16 icon decals drawn with Pillow in `tools/icons/`, ids in `src/shared/GardenIcons.luau`, glyph fallback until uploaded.

### Valley and spawn (GDD X2; no economy value)

- A `SpawnLocation` on the plaza at (18, 0.3, 32) facing the Great Egg Tree under the `spawn_pad` model; the character is moved to its gate only on the new `play` request (and `home`), once the profile is loaded. Today's join-time `toGate` goes.
- 12 large sakura (`sakura_large_a/b/c`, 34 to 45 studs), one petal emitter each (client, 60 studs); hills in three bands: terrain near, `hill_a/b/c` meshes mid and far (snow caps baked); a pond at (−50, 0, −92); 24 path lanterns lit at Moonfall; flowers 900. Plots, cart, boards, Splash Island and the Petal Patch do not move. World budget 7,500 parts (was 6,000).

### Login rewards (GDD X3; economy values)

1. The H5 daily streak and weekly bonus are replaced. `claimDaily` and `claimWeekly` leave the remote table; the `daily` and `week` save fields stay (untouched, so a rollback loses nothing).
2. **Weekly track** (Monday-based UTC week, `MetaRules.weekOf`): distinct days signed in, not consecutive. Slots at sign-ins 1 to 7: 100 c / 3 min, 150 / 5, 200 / 8, 300 / 12, **the Weekly Egg**, 400 / 15 + Blossom Can, 500 / 20 + Lantern Fence. Coins are `GardenProgress.scaled(base, minutes)`.
3. **Monthly track** (UTC calendar month): slots at sign-ins 3, 7, 12, 18, 22, 26, 30 (or the month's length): 200 / 10, 300 / 20, 500 / 30, **the Monthly Egg**, 600 / 40 + Lily Pads, 800 / 50 + Sakura Fence, 1,000 / 60 + Peacock Pitcher.
4. ~~Unclaimed slots expire at the rollover~~ (amended below: earned slots still unclaimed are paid at the rollover); claims are in order and pay the next unclaimed earned slot (`claimLogin week|month`), pure and idempotent on re-apply.
5. **Exclusive eggs:** `weekly` (grow 1 h, `puffin` 6000 / `otter` 3200 / `capybara` 800, meter 12 on `capybara`, XP 150) and `monthly` (grow 4 h, `redpanda` 7000 / `peacock` 2500 / `snowleopard` 500, meter 8 on `snowleopard`, XP 400). No price, no stock, never sold; stored in `prizeEggs`, planted with `plantPrize` at **level 1** (0012 item 3 amended for these two: GDD X3.3 gives the pacing reason; the Moon and Aurora vouchers keep their gates). Weather mutations and charms roll normally.
6. **Six species**, in rarity-then-rate order: Pebble Puffin (uncommon 10), River Otter (rare 50), Spa Capybara (epic 220), Maple Red Panda (legendary 650), Jewel Peacock (mythic 2000), Frost Leopard (divine 6000). Only their egg hatches them. **`INDEX_SIZE` 108.** Milestones stay 20 / 40 / 60 / 80. Tradable under V1.
7. Five login cosmetics (`grant = "login"`): owned only through a claim, never buyable; `MetaRules.isUnlocked` treats `grant` like `price` (owned-only).

### Remotes (adds to 0008's table; removes two)

| Action | `arg` | Accepted when |
|---|---|---|
| `claimLogin` | `week` or `month` | `LoginRules.canClaim` on the current profile: the next slot's sign-in count reached this period |
| `play` | nil | profile loaded; moves the character to its gate (the same move as `home`, plus the first-session flag for the client) |
| ~~`claimDaily`~~, ~~`claimWeekly`~~ | | removed; refused as unknown actions |

No new `Fx`. `LastReward` carries the login toasts as today.

### Saved profile: schema v3 gains `login` (rule 7: for SHANNON at the checkpoint)

```
login = { week, weekDays, weekLast, weekClaimed, month, monthDays, monthLast, monthClaimed }
-- week = MetaRules.weekOf(day); month = year * 12 + month - 1 (UTC); *Days 0..31 distinct days this period;
-- *Last = the UTC day last counted (-1 none); *Claimed 0..7 slots paid in order. Default: every key -1 or 0.
prizeEggs may hold "weekly" and "monthly" (eggs with `exclusive`, not only priced ones)
pity.weekly, pity.monthly (from the EGGS loop, as every metered egg)
owned may hold the five login cosmetic ids
```

**Why the shape:** two counts and one day per track are the least state that (a) survives a rollover (the key changes, the earned unclaimed slots are paid, the track resets), (b) never double-counts a day (`*Last`, counted only when the day is later), and (c) never double-pays (claims advance one counter in order and each queued claim carries the slot number its request saw, so a re-applied claim, also one re-run on a record that already holds it, returns the profile unchanged). A per-slot boolean list would allow gaps and needs a list sanitiser for nothing.

**Migration (no conversion job, as 0012 and 0015):** `sanitize` starts from `defaults`, so any record without `login` gets the default and counts today at its next login tick; `schemaVersion` stays 3 (0015 and 0016 both introduce v3 on their branches; this record adds a field to it, as 0015 did to v2's successor; if SHANNON prefers a bump to 4 when all three land, it is one constant and one spec line). **Rollback:** a pre-0017 build drops `login`, `pity.weekly`, `pity.monthly`, the two prize-egg counts and the five cosmetic ids at its next write; exclusive creatures already hatched are dropped by that build's `sanitize` as unknown species (they come back only if the save was not rewritten). No rollback past 0017 after publishing without SHANNON, as before.

## Why

- The brief asks for a look, not new mechanics: one kit module is the smallest change that makes every panel look the same, and it leaves every rule and request where it is.
- A `SpawnLocation` is what Roblox already does on join; the bug was moving the character only after a yielding load. Spawning on the plaza facing the tree also gives the start menu's PLAY a fly-to-gate moment.
- Counting distinct days (not a streak) and paying earned slots at the rollover keep G4: nothing is lost by missing a day except that day, nothing earned is lost by not opening REWARDS, and there is nothing to count down.
- The eggs are gated by sign-ins, not level, because they cannot arrive before day 5 or day 18, when the script's player already buys Moon or Celestial Eggs (GDD X4).
- Exclusive species in the Index (108) give a reason to keep signing in that is not coins; the milestone ladder is left alone so the Aurora voucher at 80 stays the last prize.

## Consequences

- Specs that pin the roster (26), eggs (10, `aurora` last sold), Index (108), `isUnlocked`, `prizeEggs` keep-rule and the login shape change (GDD X5). New `tests/LoginRules.spec.luau`.
- `MetaRules` changes by one condition (`grant`), shared with Relay and Night; their rows have no `grant`, so their specs are unchanged.
- The world grows to about 7,500 parts and 60,000 static tris; checked at the greybox gate with the part count attribute.
- Pacing (GDD X4): 16 minutes of income a day in coins (Wheel 30, Dash 6) and 89 coins/s per day in creatures (Dash cap 904); first buys unchanged, first Aurora day 18 → 20 at 1 h/day, income at day 90 up 4% to 8%.

## Amendment (GARDEN-058, 2026-11-06; QA M1, m5, m6)

**Earned rewards are paid at rollover; nothing earned is lost.** When `LoginRules.tick` sees a later week or month, it first pays every earned, unclaimed slot of the ending period, in slot order, exactly as a claim would (coins `scaled` at the current income and capped, the egg into `prizeEggs`, a cosmetic granted once), then starts the new period. It is part of the tick, so it is pure and idempotent on flush re-apply (a re-run sees the new key). The player is told with the reward toast, "Weekly Egg! + 750 coins (saved for you)", at join or at once when online. A save that skipped several periods pays its stored period only: the save keeps one period per track, and the periods between had no sign-in, so they earned nothing. The tick only moves forward (a server clock behind the stored period changes nothing, so a track never resets twice in one UTC day), and a queued claim pays only the slot its request saw. No schema change; the reward values are unchanged (a player who never claims gets what a player who claims gets).

## Facts, assumptions, hypotheses

- **Fact:** every number above is computed by `docs/game-design/game4-v05-pacing-check.py` from the values in this record; the script asserts the two budget comparisons.
- **Fact:** `SpawnLocation` with `Neutral` places every character; `Players.CharacterAutoLoads` stays on.
- **Assumption:** the spawn pad and pond positions are clear of paths, lamps and plot corners by the margins in X2; the engineer may move either by the stated allowance.
- **Hypothesis:** the kit look lifts first-session retention; the showcase row sells the exclusives before the first sign-in slot is claimed.
