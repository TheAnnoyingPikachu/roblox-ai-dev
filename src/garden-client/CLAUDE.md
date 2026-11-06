@../garden/CLAUDE.md

## v0.4 client (GARDEN-030, architecture 6.3)

| File | Owns |
|---|---|
| `TradeFx.client.luau` | Trade panel from `trade` / `tradeEmote` Fx only; sends the six `trade*` actions through the 0.4 s `ask` pacing |
| `FollowerFx.client.luau` | One visual copy per player from the `Follower` attribute under `Workspace.GardenFollowers`; milestone title tags |
| `BedFx.client.luau` | V7 egg looks per bed from the bed `Egg` attribute; nothing on the cart egg |

- The Highlight budget is shared: `ClientState.HIGHLIGHT_BUDGET` and `ClientState.highlights` (CreatureFx, BedFx).
- Charm looks read the creature `C` attribute and rebuild when it changes; pet names come only from the profile `n`, never from client input.
- The fairness line only displays the server's two `rate` values against `TRADE.fair`; the server's refusal decides.
