# Egg Garden v0.4 and v0.5: build order and merge plan (Director, 2026-11-05)

Two PRs, two checkpoints. Nothing publishes until SHANNON says yes at each.

## PR A: v0.4 + Petal Catch + egg looks (branch garden/v04)
1. GARDEN-028 rules (running) lands on garden/v04.
2. Merge garden/egg-looks (eight re-uploaded eggs) and garden/wheel (WheelRules, Wheel, WheelWorld, WheelFx; schema field `wheelToday`) into garden/v04. Conflicts expected only in GardenConfig/GardenProgress field tables and specs: keep both sides.
3. GARDEN-029 server and GARDEN-030 client run in parallel (disjoint files; 030 also wires the wheel's HUD entry if 043 left it to Menu).
4. Merge garden/v04-art and garden/wheel-art (moth, Clover Pads, Starlit fence, wheel props); run the upload workflow once for every new asset; regenerate GardenAssets.
5. GARDEN-032 QA, Studio pass, checkpoint GARDEN-V04 + GARDEN-WHEEL as one message to SHANNON.
Schema: v3 = `trades`, `tradesToday`, `milestones`, `wheelToday`, creature `c`, `n`, `fa`, `pad`. One bump.

## PR B: v0.5 (branch garden/v05, rebased on PR A)
1. GARDEN-051 rules (LoginRules, exclusive eggs and species, Index 108): new fields under schema v3 with defaults, no second bump.
2. GARDEN-052 server (spawn, valley, login tick) and GARDEN-053 client (UiKit, Menu and Hud rewrite, rewards panel) in parallel: 053 starts only after PR A's client work is merged, because it rewrites Menu and Hud.
3. GARDEN-054/055 art (6 creatures, 2 eggs, sakura_large, hills, spawn pad, lanterns, 16 icons) can start as soon as the design lands; upload once.
4. GARDEN-056 QA, Studio pass, checkpoint GARDEN-V05.

## Known risks and how they are handled
- Trading correctness: pure TradeRules fully specced; the two-apply commit is idempotent on the trade id with a ledger first and a heal at login; QA reads the connected code; the only real two-client run is on staging after publish, said plainly in the checkpoint.
- Text filtering: `FilterStringAsync` needs a published place; Studio proves the plumbing, staging proves the filter.
- Asset uploads: the uploader's image-id resolver returns null when the decal is still processing; it now retries. Fallback stays the Studio `GetObjects` trick.
- Shared files: GardenConfig and GardenProgress are touched by 028, 041 and 051 in sequence, never in parallel; Menu and Hud by 030 then 053, never in parallel.
- Index: 80 (v0.3) -> 84 (moth) -> 108 (v0.5 exclusives); milestone thresholds stay 20/40/60/80.
- v0.3 is merged but NOT yet published; SHANNON runs the garden-staging publish.
