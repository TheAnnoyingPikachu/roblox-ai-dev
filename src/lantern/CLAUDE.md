# Lantern Express server: read this first

Co-op train run for a crew of up to 6, one crew and one train per server (decision 0018). Status:
v0.1 server built on part fallbacks (LANTERN-006); the client is `src/lantern-client` (LANTERN-007).

- Project `lantern.project.json`; publish target `lantern-staging` (Max Players 6, set in Creator Hub).
- Docs, open only the section you need: `docs/architecture/lantern.md` (§3 signatures, §4 server, §5 Fx,
  §9 assets), `docs/decisions/0018-lantern-express.md` (§2 seated rule, §3 remotes, §4 save),
  `docs/game-design/game6-gdd.md`, `docs/game-design/game6-art-bible.md` §3 (lighting).

## Files

| File | Owns |
|---|---|
| `LanternServer.server.luau` | boot, `Saves.start`, the `Router` actions, `LanternRemotes`, `LanternRun` attributes, join and leave, the 10 Hz run loop and its event dispatch, the Heartbeat drive, day rollover, Max Players warning |
| `World.luau` | track paths (`World.at`, `World.site`), rails, platforms, Lamplight Depot, Dawn Station, decor, weekly boards, Lighting and Atmosphere |
| `Train.luau` | four anchored cars (`train_engine`, `train_car_*`) moved by CFrame, `Seat` parts (`Kind`, `Car`), `lamp_turret_head` parts (`Seat`), load boxes, the train frame (`TrackRules.at(track, D)`, y 0, as the client rebuilds it) |
| `Stops.luau` | the stop tile (blocks, ground, edges), item models with the `Pick` and `Help` prompts, `sync` to the run's item states |
| `Carry.luau` | carried items on backs, in front, or the critter crate on Align constraints; each carrier's G4 samples (`CarryRules.pace`) |
| `Night.luau` | the `Aim` remote and its checks, fresh beams, turret heads, wisp Fx and puff credit |
| `Rewards.luau` | every payout (`saves.apply` per player), run-end bests, weekly boards, end card tallies |

Pure rules: `TrainRules` (the run), `CarryRules`, `WispRules`, `LootRules`, `TrackRules`, `DepotRules`,
`LanternProgress` (the save), `LanternConfig` (every number). Specs: `lune run tests/run Train Carry Wisp Loot Track Depot Lantern`.

## Must stay true

- The run changes only through `TrainRules`: the tick's returned run is kept (after `hub` too: it carries
  the crew); a request or prompt replaces `run` in the same frame, with no yield in between.
- The train moves only while every crew member is seated or in the fog; `seat` events are acted on every
  tick, so a member who jumps off a moving car is back in a seat within 0.1 s. A non-crew sitter is stood up.
- Every reward is one `saves.apply` on that player's own save with a change that captures its inputs; a
  load is paid the moment it reaches the train; nothing is ever taken from a save.
- No remote carries an amount, position, time or hit. `Aim` is a direction only (Vector3, finite, length
  0.5 to 1.5, sender in a turret seat, burst 4 at 12 a second, clamped); hits use server wisp positions.
- The server ignores `Fx.OnServerEvent`. Fx kinds and payloads are architecture lantern 5 (0018 section 3
  and amendment 1: `shoo`, the carry refusal codes).
- The stop frame is the art's LAYOUT frame (`LanternConfig.TILES` copies `tools/blender/lantern/assets/tiles.py`):
  `Site * Vector3.new(x, y, depth)`, origin on the deck's track edge 4 studs out, +Z into the stop; the deck
  (depth 10 or less) is never caught. A tile mesh that arrives mirrored is fixed in `Stops.build`'s yaw.
- The client reads `LanternRun`, `LanternBoards`, `LanternModels` (templates from `Models.night`) and the
  names `train_engine`, `lamp_turret_head`, seat `Kind`, item `ItemId` (architecture lantern 5).
- A save whose `schemaVersion` is above 1 is never written: the kit's `newer` option loads it read-only.
- A session that could not claim its save (busy, offline, lost) keeps every change; the server retries
  `SaveStore.reclaim` every 15 s, keeps `ProfileOnline` false until then and never says "saved" (QA M4).
- The G4 carry check (`Carry.check`, `CarryRules.pace`) runs before the tick's loads; only a checked
  carrier is in the load box. `sit` is refused while carrying (`TrainRules.canSit`). Activity is a real
  input: a request, 10 studs walked (server moves excluded), a turned aim, a puff (QA M1 to M3).
- Stores `LanternProfile<suffix>`, `LanternWeekCritters<week><suffix>`, `LanternWeekDist<week><suffix>`.
- `Models.luau`/`Props.luau` are mapped in from `src/relay`; never add files with those names here.

Fast check: `rojo build lantern.project.json -o build/lantern.rbxl && node tools/check-place.mjs lantern.project.json build/lantern.rbxl`.
