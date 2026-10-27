# 0009: Neon Spire economy, saved profile and remote contract

Date: 2026-10-26
Status: Proposed by A06 and A09 for SHANNON (CLAUDE.md rule 8). Implements `docs/game-design/game5-gdd.md` (the GDD; section letters refer to it). SPIRE-003 finalises it with exact signatures before SPIRE-004 starts; any change to a value below after acceptance needs an amendment here.

## Decision

### Economy

- Currency: credits (¢), clamped to 1e15. `lifetimeEarned` clamped to 1e18. Start: 100 ¢, floors 2 (lobby + an empty Data Farm floor).
- Floor costs: the GDD C2 table (floor 3 = 129 ¢ … floor 30 = 122,000,000,000 ¢), stored as data, not as a formula.
- Departments, module costs, income, power draw and the floor each can go on: GDD C3. Module levels `LV = {1, 2, 4, 8, 16}`, upgrade multipliers `UP = {2, 5, 12, 30}`, fusion supply `{8, 18, 32, 50, 75}`, base supply 6 (GDD C4, C5).
- Power only blocks new modules; it never reduces income (GDD C5).
- Ad Agency stacking: +25% per active neighbour, +50% during Neon Night (GDD C6).
- Plaza: GDD D2 items and limits; `hype = min(Σ, 10 × floors, 200)`, `hypeMult = 1 + hype / 100` (GDD D3).
- Income: GDD E1. Online income is credited every second directly to the balance: **no unbanked pool** (avoids the Egg Garden GARDEN-006 M1 double-pay class).
- Hot Data: every 60 to 120 s, lasts 45 s, owner only, pays `floor(30 × income)` and 5 XP (GDD E3).
- Offline: `floor(baseIncome × 0.5 × min(away, 28,800))`, no event multiplier (GDD E4).
- Refunds: modules and plaza items 50% of what was paid. Property: no sequence of buys and sells increases credits.
- Market Pulse: 10-minute windows, first 300 s active, `Rng.seed(w, 7077)`, GDD F tables. Flash Sale: modules and upgrades at `floor(price × 0.75)`.
- IPO (M4): floors ≥ 20; `gained = floor(sqrt(runEarned / 1e7))`; shares capped at 500; `shareMult = 1 + 0.10 × shares`; resets and keeps per GDD H.
- Rewards: MetaRules daily, weekly and quests with `scale(base, minutes) = max(base, floor(income × 60 × minutes))`.
- Pacing targets: GDD B, enforced by `tests/SpireBalance.spec.luau` within ±30%.

### Saved profile (schema v1)

- Store `SpireProfile<suffix>`, ordered store `SpireBoard<suffix>` (value `floor(lifetimeEarned)` capped at 2^53, written at most every 120 s when changed). Suffix per environment, so staging and production never share data.
- Fields and sanitising rules: GDD N. Estimated encoded size 5 to 6 KB; SPIRE-005 logs the real size of a maxed test profile.
- Session lock `{ id, at }` on the record, stale after 120 s, claimed by the load's `UpdateAsync` (as the decision 0008 amendment of 2026-10-26). Only the holder writes. A session without the lock or the store runs offline and never writes; a failed load never writes defaults.
- Writes: coalesced `UpdateAsync` re-apply, at most one per player per 7 s; 60 s autosave; final write on leave and in `BindToClose`, releasing the lock. Every flush ends with `snapshot` (credits, `lifetimeEarned`, `runEarned`, `lastSeen`) from the lock holder. Random choices are made once and applied as fixed values.
- No personal data beyond the profile keyed by UserId (decision 0003).

### Remote contract

- `ReplicatedStorage.SpireRemotes.Request: RemoteFunction`, `Request(action: string, arg: string?) -> (boolean, string?)`.
- Common checks in order: loaded online session; `action` is a string; `arg` nil or a string ≤ 40 characters; token bucket (capacity 6, refill 4 per second) per player; known action; arg/no-arg rule; then the action's Lua pattern from GDD O. Malformed input is refused with no state change.
- Actions and acceptance: GDD O table. World checks on the server-side character position: lift zones, 12 studs for prompts.
- `SpireRemotes.Fx: RemoteEvent` is server-to-client display only; the server ignores `OnServerEvent`. Payloads: GDD O.
- `SpireStatus: StringValue` (JSON), lot attribute `State` (public JSON), player attributes per GDD O.
- The client never sends amounts, prices, levels, positions, outcomes or targets beyond the ids and cells in GDD O.

### Child safety (players under 18)

- No stealing, sabotage, trading, gifting, text input, custom chat, random loot, Robux prompts or paid items (decision 0002).
- Company names from fixed word lists only (GDD G). Ticker shows company names only.
- Endorse is the only cross-player effect; once per company per day, 30 per day.
- Light flicker ≤ 3 Hz everywhere; Reduce Flashing setting (GDD I4.6).

## Why

The values come from the pacing simulation in `docs/game-design/game5-pacing-sim.py` and match the first-session script in GDD K5. Direct crediting and the session lock reuse what the Egg Garden review taught. The string-arg Request contract and token bucket keep the remote surface as small as earlier games while allowing fast building clicks (hypothesis: Egg Garden's flat 0.35 s limit would feel slow when a player taps UPGRADE several times in a row).

## Consequences

- `SpireConfig` holds every value; tests assert the tables above.
- Changing a price, income, odds or limit after acceptance needs an amendment and must keep the balance spec green or update its targets with a reason.
- The token bucket is new to the studio; QA (SPIRE-008) checks that refused requests never refill it and that spam cannot exceed 4 per second sustained.
