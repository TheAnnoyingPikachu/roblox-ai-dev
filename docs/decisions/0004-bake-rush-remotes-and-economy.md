# 0004: Bake Rush stations and economy values

Date: 2026-10-24
Status: Proposed (QA review on PR #1)

## Decision

- **Interaction:** three server-side ProximityPrompts (Oven = bake, Counter = sell, Upgrade station = upgrade). No client remotes. Prompts work on PC, mobile and console.
- **Authority:** the server reads no values from the client. A prompt can only trigger one action.
- **Cooldown:** a tier's bake time is the minimum gap between bakes, measured with `time()`. Requests faster than that are dropped without reply.
- **Economy values:** `src/shared/BakeConfig.luau` matches the tier table in `docs/game-design/bake-rush-gdd.md` section C. A test pins them to that table.
- **Leaderstats:** owned only by BakeService (Coins, Tier, Pastries). The M0 RewardService sample was removed to avoid a second owner.

## Why

Prompts give every platform the same input path without a client-trust remote. One owner for leaderstats prevents two balances fighting over one value.

## Consequences

- There is no client remote for bake, sell or upgrade, so there is no payload to validate.
- Shared-server stations live in Workspace and are created once per server.
- Per-player request throttling is deferred. Each action is cheap and rejected without effect, so it can't double-apply.
