# Bake Rush: game design spec (pilot, v0.1)

Status: draft for SHANNON's approval. Scope is frozen once approved.

## A. Product

- **Pitch:** tap to bake, sell pastries, upgrade your oven.
- **Audience:** younger players, all ages; no chat required to play.
- **Platforms:** PC, mobile, console. Touch and mouse first.
- **Pillars:** instant feedback; a readable economy; nothing needs Robux.
- **Non-goals (v0.1):** trading, pets, paid items, rebirths, leaderboards beyond the built-in one.

## B. Core loop

1. Tap the oven to bake a pastry (1 pastry per tap, 0.5 s cooldown).
2. Walk to the counter to sell pastries for coins.
3. Spend coins to upgrade the oven.
4. Each oven tier bakes faster and sells for more.

**Controls:** tap or click the oven; E or the "Sell" button at the counter.

## C. Progression

| Tier | Upgrade cost (coins) | Bake time | Sell price per pastry |
|---|---|---|---|
| 1 (start) | 0 | 1.0 s | 1 |
| 2 | 50 | 0.8 s | 2 |
| 3 | 200 | 0.6 s | 3 |
| 4 | 800 | 0.5 s | 5 |
| 5 | 3,000 | 0.4 s | 8 |

Tiers beyond 5 are out of scope for v0.1. Costs and prices belong in `src/shared/Config.luau`.

## D. Economy and anti-exploit rules

- The server owns coins, pastry counts and tier. Clients send "bake", "sell" and "upgrade" requests only.
- The server enforces the bake cooldown; requests faster than the cooldown are dropped.
- Sell requests carry no amount. The server sells all carried pastries at the current tier price.
- Upgrades are rejected unless coins ≥ cost and the tier is the next one.
- Coins are capped at 1,000,000,000 (matches `maxCoins`).

## E. Session

- First sale within 30 seconds of joining.
- Reaching tier 2 takes about 5 minutes for a typical player; tier 5 needs repeat sessions.
- Players can leave and rejoin; progress is saved (M3).

## F. Persistence

- Saved per player: coins, tier, pastry count.
- Saves happen on leave and every 60 seconds, with retries. A failed save logs a warning and never wipes saved data.
- Staging uses its own DataStore name, so tests never touch production data.

## G. Acceptance criteria (pilot milestone)

- [ ] Server rejects bake requests faster than the cooldown (unit test).
- [ ] Sell and upgrade produce correct totals across all tiers (unit test).
- [ ] An invalid upgrade request leaves coins and tier unchanged (unit test).
- [ ] A new player sells their first pastry within 30 seconds in a playtest.
- [ ] Progress survives leave and rejoin in staging (M3).
- [ ] No Robux prompts, no paid items.

## H. Kill criteria

- Fewer than half of playtesters reach tier 2 within 10 minutes.
- Playtesters stop before their second upgrade in more than half of sessions.

## I. Open questions

- Ages: "younger individuals" is not specific. Confirm an age range before the design goes live.
- Trend: the genre choice was based on the request, not checked against live data.
