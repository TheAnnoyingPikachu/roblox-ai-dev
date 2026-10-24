# 0005: Bake Rush save data

Date: 2026-10-24
Status: Proposed (PILOT-004 review)

## Decision

- **Stores:** `DataStoreService` store per environment. Studio uses `BakeRushSave_studio`. Live servers use `BakeRushSave_staging` until `PRODUCTION_UNIVERSE_ID` is set in `SaveService`. Only then does the live server use `BakeRushSave`, and only when `game.GameId` matches that ID. Staging and production never share a store.
- **Key:** one key per player, `player_<UserId>`.
- **Record (schema v2):** `{ schemaVersion = 2, coins, tier, pastries, saveCount, lock }`. `lock` is `{ jobId, at }` and `saveCount` is a counter. Nothing else is stored: no chat, names or analytics.
- **Writes:** every load and save is an `UpdateAsync`. It takes or checks the session lock and the save count in the same call.
  - A load claims the record unless another server holds a lock younger than 300 seconds.
  - A save is rejected when another server holds the lock, or when the stored `saveCount` is newer than this server's copy. A rejected save leaves stored data unchanged.
- **Load:** three attempts with exponential backoff. Loaded data is sanitised first: floored, clamped to the coin cap, pastry cap and tier count, and non-finite or non-numeric values replaced.
- **Kick cases:** if the load fails, or the record is locked by another server, the player is kicked and saving stays off for that session. A failed load never writes defaults over saved progress. A rejected save also kicks the player.
- **Save timing:** on leave, on server close, and every 60 seconds. Never per action. Leave and shutdown share one teardown path, so no player is saved twice at the end. Shutdown waits up to 25 seconds.
- **Failed save:** three attempts with backoff, then a warning. Stored data is left unchanged.
- **Gating:** bake, sell and upgrade are ignored until the player's load has finished, so nobody can act over saved progress.
- **Caps:** coins are capped at 1,000,000,000 and pastries at 10,000, in both gameplay and saved data.

## Why

These rules keep player progress safe from failed loads, two servers racing for one player, stale writes and bad data. The blueprint lists these as core persistence risks.

## Known gaps

- A player who leaves while their load is still running keeps the lock until it goes stale, which takes up to 300 seconds. Releasing it early is a follow-up.
- Staging playtests must confirm two-session and fast-rejoin behaviour before PILOT-004 is accepted.

## Consequences

- Schema changes need a new `schemaVersion` and a migration step in `SaveRules` before any release that changes the fields. Version 1 records are not yet in use, so no migration is needed for v2.
- Studio playtests use their own store, because DataStore calls behave differently there.
- Changing the lock timeout, the store names or the caps needs a new decision record.
