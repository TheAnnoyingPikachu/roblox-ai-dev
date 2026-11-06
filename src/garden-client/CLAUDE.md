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

## v0.5 client (GARDEN-053, architecture 6.4, GDD X1)

| File | Owns |
|---|---|
| `UiKit.luau` | Every widget's geometry, colours, strokes and animation: `scaleRoot`, `panel` / `modal` shells (ribbon, shadow, close X, tabs, footer), 3D `button`, `iconButton` + `setBadge`, `strip` (touch: 5 + MORE sheet), `coinPill`, `levelRing`, `card` / `grid` / `row` / `bar`, `chip`, `toast`, `startMenu`, `viewport`, `selector`, `flyTo` |

- Callers compose; they never set a radius, stroke or tween on a kit widget. No widget sends a Request.
- One panel at a time (`UiKit.panel` closes the previous one, `onClose(byUser)` tells its owner); modals sit over it. Escape and gamepad B close the top one, bumpers change tabs.
- Icons are `GardenIcons` Decal ids drawn through `rbxthumb://type=Asset`; the two-letter glyph shows until the image loads (or when the id is nil).
- Every animation checks `GuiService.ReducedMotionEnabled`. Sizes are px at 1920 x 1080 under `scaleRoot` (0.6 to 1). No text under 12 px on screen: build text with `UiKit.text` and give it room for 12 px at 844 x 390 (GARDEN-058).
- Requests added in v0.5: `play` (PLAY; the 1.6 s fly to `ClientState.gateLook` starts once `play` returns true) and `claimLogin week|month` (REWARDS); `claimDaily` / `claimWeekly` are gone.
- Pad tags (Plots, studs-sized) are clamped by `CreatureFx` to their 15-stud size when the camera is closer.
