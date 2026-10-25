# 0006: Relay Rounds profiles, coins and the Request remote

Date: 2026-10-25
Status: Accepted by SHANNON's standing instruction ("do everything you can to make this the best game"); review before the first production release.

## Decision

### Saved profile (schema v1)

- **Stores:** `RelayProfile_studio` in Studio, `RelayProfile_staging` on live servers until `PRODUCTION_UNIVERSE_ID` is set in `src/relay/Profiles.luau`, then `RelayProfile`. An ordered store `RelayWins<suffix>` holds each player's win total for the lobby leaderboard. Staging and production never share a store. Separate from Bake Rush's stores.
- **Key:** `player_<UserId>`.
- **Record:** `{ schemaVersion, xp, coins, wins, races, legs, trail, owned, daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }`. No names, chat or analytics.
- **Writes:** every change is a pure function in `ProgressRules` (match, login, claim, buy, equip). It runs on the in-memory profile at once and again inside `UpdateAsync` on the stored record, re-read and sanitised first. A failed or slow load therefore cannot write defaults over saved progress, and two servers cannot lose each other's changes. The stored result then replaces the in-memory copy.
- **Load:** `GetAsync` with three attempts. If it fails, or DataStores are unavailable (Studio without API access), the session runs on an in-memory profile, writes nothing, and the Stats panel says saving is offline. No kick: there is nothing to protect because nothing was loaded.
- **Sanitising:** numbers floored and clamped (XP 1,000,000, coins 10,000,000, counts 1,000,000), unknown shop items dropped, a trail the profile has not unlocked falls back to "team".

### Economy (coins, XP, rewards)

| Source | XP | Coins |
|---|---|---|
| Finishing a match | 20 | 10 |
| Each leg you ran | 10 | 5 |
| Each round your team survived | 5 | 0 |
| Winning | 60 | 25 |
| Daily login streak, days 1 to 7+ | | 50, 75, 100, 125, 150, 200, 400 (day 7 repeats while the streak holds) |
| Weekly bonus (online on 5 different days, Monday to Sunday UTC) | | 500 |
| Daily quests (3 a day from a pool of 6) | | 100 to 300 each |

- **Levels:** level = floor(sqrt(XP / 40)) + 1, capped at 50.
- **Trails:** level unlocks (Sakura 3, Ember 5, Neon Cyan 8, Demon Shadow 12, Rainbow Dash 18), a wins unlock (Champion Gold at 10 wins) and coin shop items (Lightning 750, Galaxy 1,500, Inferno 2,500, Void 5,000).
- **No Robux, no paid items, no trading** (decision 0002 still holds). Coins only buy cosmetics, so nothing affects who wins a race.
- **Day and week** come from the server clock (UTC day number). The client only displays them.

### Remote contract

- `ReplicatedStorage.RelayRemotes.Request` (RemoteFunction): `Request(action: string, arg: string?) -> boolean`.
- Actions: `claimDaily`, `claimWeekly`, `claimQuest(questId)`, `buyTrail(trailId)`, `equipTrail(trailId)`. Anything else is refused.
- The server type-checks both arguments, refuses `arg` longer than 32 characters, allows one request per 0.35 s per player, and validates every claim, purchase and equip with `ProgressRules` against its own copy of the profile. The client never sends amounts, prices, progress or results.

## Why

Daily and weekly logins, quests, levels and cosmetic unlocks are what keep players coming back to Roblox games. Keeping every rule pure and server-validated follows CLAUDE.md rules 4 and 5. The write pattern avoids the overwrite risks decision 0005 handled with session locks, without needing a lock, because each write re-applies one small change to the stored record.

## Consequences

- Changing reward amounts, prices, the level curve or the record fields needs a new decision record. New fields need a `schemaVersion` bump and a step in `ProgressRules.sanitize`.
- `PRODUCTION_UNIVERSE_ID` must be set, with SHANNON's approval, before a production release, as with Bake Rush.
- Leaderboard names use `GetNameFromUserIdAsync`, which is public Roblox data, refreshed once a minute.
