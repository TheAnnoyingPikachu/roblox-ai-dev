# 0005: Bake Rush save data

Date: 2026-10-24
Status: Proposed (PILOT-004 review)

## Decision

- **Store:** `DataStoreService` store `BakeRushSave`, one key per player: `player_<UserId>`.
- **Record:** `{ schemaVersion = 1, coins, tier, pastries }`. Nothing else is stored: no chat, names or analytics.
- **Load:** three attempts with exponential backoff. Loaded data is sanitised (clamped to the coin cap and tier count, floored, non-numbers replaced) before use.
- **Failed load:** the player plays with default state, but saving is disabled for that session. A failed load never writes defaults over saved progress.
- **Save timing:** on leave, on server close, and every 60 seconds. Never per action.
- **Failed save:** three attempts with backoff, then a warning. Existing saved data is left unchanged.
- **Gating:** bake, sell and upgrade are ignored until the player's load has finished, so nobody can bake over saved progress.
- **Isolation:** staging and production are separate experiences, so their stores are separate.

## Why

These rules keep player progress safe from failed loads, racing requests and bad data, which the blueprint lists as core persistence risks.

## Consequences

- Schema changes need a new `schemaVersion` and a migration step in `SaveRules` before any release that changes the fields.
- Studio playtests need a separate test experience, because DataStore calls behave differently there.
- Coins are capped at 1,000,000,000 in saved data, matching the rules.
