# 0007: Hundred Demon Night profiles, souls, remotes and MetaRules

Date: 2026-10-25
Status: Proposed by A09 for SHANNON (CLAUDE.md rule 8). Implements `docs/game-design/game3-gdd.md` sections F, H and J; module map in `docs/architecture/night.md`. Review before the first production release.

## Decision

### Saved profile (schema v1)

- **Stores:** `NightProfile_studio` in Studio, `NightProfile_staging` on live servers until `PRODUCTION_UNIVERSE_ID` is set in `src/night/Profiles.luau`, then `NightProfile`. An ordered store `NightWins<suffix>` holds each player's nights won for the shrine leaderboard. Same suffix rule as decision 0006; separate from Relay Rounds' and Bake Rush's stores.
- **Key:** `player_<UserId>`.
- **Record:** `{ schemaVersion, xp, coins, wins, runs, waves, kills, bestTier, tierPick, weapon, blade, mask, owned, daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }`. `coins` holds souls. `wins` is nights won. No names, chat or analytics.
- **Writes:** every change is a pure function in `NightProgress` (wave clear, victory, login, claim, buy, equip, tier, weapon). It runs on the in-memory profile at once and again inside `UpdateAsync` on the re-read, sanitised stored record, exactly as decision 0006. Writes happen after each wave clear, victory, claim, purchase and equip. There is no extra write on leave: every change is already written when it happens.
- **Load:** `GetAsync` with three attempts. On failure, or without DataStore access, the session runs offline on an in-memory profile, writes nothing, and the Stats panel says saving is offline. No kick.
- **Sanitising:** as decision 0006 (numbers floored and clamped: XP 1,000,000, coins 10,000,000, `wins`, `runs`, `waves`, `kills` and quest progress 1,000,000), plus `bestTier` clamped 0 to 5, `tierPick` clamped 1 to 5, `weapon` falls back to `katana` if unknown or locked, `blade` to `steel` and `mask` to `none` if unknown or locked, `owned` keeps only priced cosmetic ids.
- **Leaderboard:** on Victory the server writes `wins` to `NightWins<suffix>` (best effort, as 0006).

### Economy (XP, souls, rewards)

| Source | XP | Souls |
|---|---|---|
| Each wave `w` cleared (every participant, downed included) | `floor((15 + 3w) × R)` | `floor((8 + 2w) × R)` |
| Victory (wave 10 cleared) | `floor(150 × tierMult)` | `floor(100 × tierMult)` |
| Daily login streak, days 1 to 7+ | | 50, 75, 100, 125, 150, 200, 400 (day 7 repeats while the streak holds) |
| Weekly bonus (online on 5 different UTC days, Monday to Sunday) | | 500 |
| Daily quests (3 a day from a pool of 8) | | 100 to 250 each |

- `R = tierMult × styleMult × partyMult`; `tierMult = 1 + 0.5 × (t − 1)`; `styleMult` by the player's highest style rank in the wave: D 1.0, C 1.1, B 1.2, A 1.3, S 1.5, SS 1.75, SSS 2.0; `partyMult = 1 + 0.1 × min(3, n − 1)` with `n` = participants when the wave clears. Every `floor` adds 1e-9 first so float products such as `20 × 1.1` cannot drop a point.
- Check value: a solo tier-1 night won at rank D pays 465 XP and 290 souls.
- Kills do not pay. Damage dealt does not pay. Only clearing waves and winning pay.
- **Quest pool:** `nights3` (runs 3, 100), `waves10` (waves 10, 100), `kills60` (kills 60, 100), `launch30` (launches 30, 120), `trigger5` (triggers 5, 120), `rankS3` (rankS 3, 150), `general2` (generals 2, 150), `boss1` (bosses 1, 250). Selection uses the 0006 `questsFor` rule over this pool.
- **Stats counted at each wave clear:** `waves +1`; `kills`, `launches`, `triggers` += the player's counts this wave (kills = killing blows, launches = enemies launched, triggers = Trigger activations); `rankS +1` if the wave's best rank was S or better; `generals +1` on wave 5; `bosses +1` on wave 10; `runs +1` at the player's first wave clear in a run. On Victory: `wins +1`, `bestTier = max(bestTier, t)`. Only `wins`, `runs`, `waves`, `kills` and `bestTier` are stored as totals; the rest exist only as quest progress.
- **Levels:** level = floor(sqrt(XP / 40)) + 1, capped at 50 (same as 0006).
- **Weapons:** Katana level 1, Twin Kodachi level 6, Nodachi level 14. Sidegrades. Equip refused while a run participant.
- **Moon tiers:** tier 1 always; tier `t > 1` once `bestTier ≥ t − 1`.
- **Blades:** Steel (default, level 1), Sakura 3, Ember 5, Moonlight 8, Demon Shadow 12, Rainbow 18, Champion Gold (5 nights won), Lightning 750 souls, Galaxy 1,500, Inferno 2,500, Void 5,000.
- **Masks:** None (default), Kitsune level 4, Tengu level 10, Oni (3 nights won), Eclipse (tier 5 won), Okame 600 souls, Hannya 1,000 souls.
- **No Robux, no paid items, no trading** (decision 0002). Souls buy cosmetics only; nothing bought changes combat.
- **Day and week** from the server clock (UTC day number), as 0006.

### Remote contract

All under `ReplicatedStorage.NightRemotes`, created by the server.

- **`Request`** (RemoteFunction): `Request(action: string, arg: string?) -> boolean`.
  - Common checks, in order: the player has a loaded session; `action` is a string; `arg` is nil or a string of at most 32 characters; at most one request per 0.35 s per player (refused requests inside the cooldown do not reset it); `action` is in the table below. Anything else returns false and changes nothing.

  | Action | `arg` | Accepted when |
  |---|---|---|
  | `play` | nil | not already a participant; run has fewer than 6 participants; run state is any (Idle starts a countdown; Victory and Defeat join the next countdown) |
  | `leaveRun` | nil | is a participant |
  | `pickBlessing` | `"1"`, `"2"` or `"3"` | is a participant; state is `Break`; has not picked this break; index ≤ size of the offer |
  | `setTier` | `"1"` to `"5"` | the tier is unlocked; stores `tierPick` (affects the next run only) |
  | `equipWeapon` | weapon id | not a participant; the weapon is unlocked |
  | `claimDaily`, `claimWeekly` | nil | as 0006 |
  | `claimQuest` | quest id | today's quest, progress ≥ goal, not claimed |
  | `buyCosmetic` | cosmetic id | priced, not owned, souls ≥ price |
  | `equipCosmetic` | cosmetic id | unlocked; equips into that cosmetic's slot (`blade` or `mask`) |

  A non-nil `arg` sent to an action that takes none is refused.
- **`Combat`** (RemoteEvent, client to server): `Combat(action: string)`, `action` ∈ `attack`, `skill`, `dash`, `trigger`. No positions, targets, directions or amounts. Refused if: the event carries any second argument; `action` is not a string or not one of the four; the player is not a participant, is downed, or the state is not `Countdown`, `Wave` or `Break`; more than 20 Combat events arrived from the player in the last 1.0 s (refused ones count); the rule in `CombatRules` refuses it (combo timing, 5 s skill cooldown minus blessings, dash 0.95 s, Trigger needs gauge 100 and not active). `attack` and `skill` are also refused for 1.0 s after the teleport guard fires (root moved more than 12 studs horizontally between two 10 Hz samples). Hit tests use the server's replicated root position and flattened LookVector at the moment the event arrives.
- **`Fx`** (RemoteEvent, server to all clients): `Fx(kind: string, data: table)`, display only; payloads in `docs/architecture/night.md`. The server ignores `Fx.OnServerEvent`.
- **`ReplicatedStorage.NightStatus`** (StringValue, JSON, server-written): `{ state, wave, tier, left, ids, host, boss }`; `left` whole seconds of the current timed phase, `ids` participant UserIds in join order, `boss` HP fraction 0 to 1 on waves 5 and 10, absent otherwise.
- **Player attributes** (server-written; clients read only): `Profile` (JSON), `ProfileOnline`, `LastReward`, `XP`, `Level`, `Coins`, `Weapon`, `Blade`, `Mask`, `HP`, `MaxHP`, `Gauge` (0 to 100, floored), `StyleRank` (1 to 7, index into `StyleRules.RANKS`), `StylePoints`, `Charms`, `Trigger` (boolean, active), `Blessings` (JSON stack map), `Offers` (JSON array of blessing ids; empty when none or picked). Leaderstats: `Level`, `Nights`.
- The client never sends amounts, prices, rewards, damage, targets, positions or results.

### MetaRules

- Relay's day/week maths, daily streak, weekly bonus, quests, levels, cosmetic unlock/buy/equip and sanitising move from `src/shared/ProgressRules.luau` into a new pure `src/shared/MetaRules.luau`, configured per game (cosmetics with a `slot` naming the profile field, quest pool, daily and weekly amounts, and the game's sanitiser).
- `ProgressRules` keeps every exported name, type, constant, value and behaviour it has today: it becomes Relay's config plus its match rules, delegating to `MetaRules`. Relay trails get `slot = "trail"`. `tests/ProgressRules.spec.luau` must pass unchanged, and no file under `src/relay` or `src/relay-client` changes. Relay's saved record and decision 0006 are untouched.
- `MetaRules` adds a `tier` unlock kind (`bestTier ≥ tier`; a profile without `bestTier` counts as 0).

## Why

Same reasons as 0006: return hooks (streak, weekly, quests, levels, cosmetics) on a server-validated, pure, Lune-tested core. Generalising instead of copying keeps one tested implementation of the reward rules for both games. Combat is server-decided (CLAUDE.md rule 4) because style rank, kills and wave clears pay souls; the client only predicts VFX.

## Consequences

- Changing reward amounts, prices, unlocks, the level curve or record fields needs a new decision record; new fields need a `schemaVersion` bump and a step in `NightProgress.sanitize`.
- Any `MetaRules` change is a Relay change too: Relay's spec must stay green.
- Player root position and facing are client-owned physics. The teleport guard limits abuse; a player can still turn freely, which the wide arcs already allow. Accepted for v0.1.
- `PRODUCTION_UNIVERSE_ID` must be set, with SHANNON's approval, before a production release; the `night-staging` publish environment needs its variables and secret set by a human.
