# Egg Garden v0.4 checkpoint (put to SHANNON once, at the end of GARDEN-032)

Decision `docs/decisions/0015-garden-v04-trading-charms.md` (Proposed), GDD section V. Work continues on the recommended option for every item: all of it is branch code, docs and staging. Attach the milestone's evidence when asking: CI run, test counts, build stamp, a two-client recording of one trade and its undo, the Thunder weather and a Stormy reveal, the follower, a named pad tag, the eight eggs side by side.

| # | Decision | Recommendation | If rejected |
|---|---|---|---|
| 1 | **Trading exists, in the V1 form only** (friends both ways, one creature each, value within 2×, TRADE then 10 s hold then CONFIRM, 3 a day, undo by either for 10 minutes, emotes only, ledgered). Amends 0008's "no trading". | Accept. | Delete `Trades.luau`, `TradeFx`, `TradeRules` and the `trade*` actions; the schema fields stay empty and harmless. |
| 2 | **Schema v3 migration** (rule 7): old saves gain `trades`, `tradesToday`, `milestones`, `pad`; creatures gain `c`, `fa`, `n`; no conversion job, `sanitize` fills defaults; no rollback past 0015 after publishing. | Accept. | v0.4 does not publish; nothing else is at risk. |
| 3 | **Charm chances 25% / 15% / 10%** (Frosted, Blooming, Stormy) with the Director's ×1.5 / ×2 / ×3. Chosen so every rare weather's expected multiplier stays under Rainbow Shower's and the 60% rule holds (worst still Meadow in Rainbow Shower, 56.4%). At 100% chance Thunder would return 146% of a Meadow Egg's price. | Accept. | Lower multipliers instead (×1.25 / ×1.5 / ×2 at higher chances): a new table and pacing run. |
| 4 | **Weekend event weather at 10% of weekend windows, the other two rare weathers at 2%, weekdays 1% each, all out of Clear.** Sunbeam, Moonfall and Rainbow Shower odds unchanged. | Accept. | Any other split that sums to 10,000; one table and the `WorldRules.spec` frequency check. |
| 5 | **Lantern Moth from Forest and Sunset only, 300 bp, only in a rare weather** (any day: nothing is exclusive). Index 84. | Accept. | Add it to Meadow too (a third `event` row) or raise the bp; both are data. |
| 6 | **Traded creatures give no Index entry and no XP** on either side; the Index is for hatching. | Accept. | Let a received creature add its entry: trading then completes Indexes and the 80 voucher becomes tradeable-for; not recommended. |
| 7 | **Undo is unilateral** (either player, 10 minutes, once, both present). | Accept. | Require both to agree: a child who regrets can then be refused, which is the "made sad" case. |
| 8 | **Fairness band 50%** (lower value at least half the higher). | Accept. | 70% is safer but refuses most mutation-for-size swaps children want; 30% lets a Rainbow go for a Golden. |
| 9 | **Milestone rewards as the Director set them** (5,000 / 50,000 / 1,000,000 coins, Clover Pads, Starlit fence, Aurora voucher, two titles); cosmetics unlock by Index count the moment it is reached, the claim pays the rest. | Accept. | Flat coins could be `scaled` like other rewards; a new line in `claimMilestone`. |
| 10 | **Pet names: 20 characters, letters, digits, spaces, `'` and `-`, filtered on the server with the broadcast filter, 10 s cooldown, 3 renames per creature per day; names never in announcements or on the board.** The first text input in the game. | Accept. | No names: drop `n`, the action and the NAME button; everything else stands. |
| 11 | **Followers on by default** for everyone, client setting to hide them; hidden for racers. Up to 6 in a server. | Accept, checked at the greybox gate for clutter near the cart. | Default off, or owner-only visibility. |
| 12 | **Egg looks pass (V7):** re-baked textures for all 8 eggs plus per-tier bed effects within 2 emitters per bed and lights on Moon and above. | Accept, checked with the side-by-side screenshot. | Textures only, no bed effects: `BedFx` is dropped, nothing else changes. |
| 13 | **New DataStore `GardenTrades<suffix>`** (per player key, 30 records) read once per load for the heal. | Accept. | Without it, a crash between the two flushes can duplicate or lose a traded creature; then trading should not ship. |
| 14 | **Three new weather looks and stingers, five egg crack sounds and the Moth cry** from licensed partners, registered before use; silent until then. | Accept. | Any one can stay silent or reuse an existing stinger. |

## Evidence (filled by GARDEN-032)

- CI run, test counts, build stamp: pending.
- Two-client recording: a trade (invite, picks, unfair message, TRADE, hold, CONFIRM, done, STATS list) and its undo: pending.
- Studio: Thunder weather look, a Stormy reveal, the Moth in the Index and ODDS card, the follower hopping into Splash Island and hiding during a round, a named pad tag, the Clover Pads and Starlit fence, the eight eggs side by side: pending.
- A literal v2 save loaded on the v0.4 build with every field kept: pending.
