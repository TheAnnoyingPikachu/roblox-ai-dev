# Neon Spire: architecture (v0.1 plan)

Owner: A09. Status: plan for SHANNON's review (SPIRE-001). Inputs: `docs/game-design/game5-gdd.md` (the GDD; section letters refer to it), `docs/game-design/game5-art-bible.md` (the art bible), decisions 0009 (economy, saves, remotes) and 0010 (assets), and the Egg Garden code after its GARDEN-006 fixes. SPIRE-003 turns this plan into exact Luau signatures (as `docs/architecture/garden.md` section 3 did) before any game code is written. If this file and the GDD disagree on a rule, the GDD wins and this file is fixed.

## 1. Place, files and who owns them

Rojo project `spire.project.json` (created in SPIRE-003):

| Instance | Source |
|---|---|
| `ReplicatedStorage.Shared` | `src/shared` (pure modules, shared with the other games) |
| `ReplicatedStorage.BuildInfo` | `build-info/BuildInfo.txt` (StringValue). Committed with the text `dev`; CI overwrites it with the commit SHA, UTC build time and task id before `rojo build`. Section 9. |
| `ServerScriptService.Spire` | `src/spire` |
| `ServerScriptService.Spire.Models` | `src/relay/Models.luau`, required in place (hero props, decision 0010) |
| `StarterPlayer.StarterPlayerScripts.SpireClient` | `src/spire-client` |
| `Workspace.SpawnLocation` | Grid Plaza fallback; the server moves each character into its lobby |

### Reused files

| File | Spire | Notes |
|---|---|---|
| `src/shared/Rng.luau` | required in place, unchanged | Market schedule, Hot Data slot choice in tests |
| `src/shared/MetaRules.luau` | required in place | Spire config uses the existing optional `maxCoins` and `scale`; no change expected. If one is needed, it is optional and Relay, Night and Garden specs must stay green. |
| `src/garden/Profiles.luau` | **copied** to `src/spire/Profiles.luau` | Session lock, coalesced re-apply, offline mode, `BindToClose`; no `bank`/`unbanked` (GDD E2) |
| `src/garden/Remotes.luau` | **copied** to `src/spire/Remotes.luau` | `SpireRemotes` (`Request`, `Fx`), `SpireStatus`; `Request` returns `(ok, code)` |
| `src/garden-client/Menu.client.luau` | **forked** to `src/spire-client/Menu.client.luau` | restyled to the art bible UI kit |
| `src/relay/Models.luau` | required in place | new entries only, after their register rows |

Every file under `src/relay*`, `src/night*` and `src/garden*` stays byte-identical except new `Models.luau` entries.

### File ownership by task

| Task | Writes |
|---|---|
| SPIRE-004 | `src/shared/{SpireConfig,TowerRules,PlazaRules,SpireEconomy,MarketRules,SpireProgress}.luau`, their specs, `tests/SpireBalance.spec.luau`, `tests/run.luau` (`SPECS`) |
| SPIRE-005 | `src/spire/*`, `src/relay/Models.luau` (new entries), `docs/assets/register.md` |
| SPIRE-006 | `src/spire-client/{Menu,Hud,Build,Lift,ClientState}.*` |
| SPIRE-007 | `src/spire-client/{TowerView,PlazaView,City,Atmos,Crowd,Traffic,Fx}.*` |

## 2. Shape of the system

```
          Request(action, arg)                           SpireStatus (event, forecast)
 client ─────────────────────────▶ server router ──▶ pure rules (src/shared) ──▶ in-memory profile
   ▲                                   │                                            │
   │   Lot.State JSON, player attrs    │  Profiles: coalesced UpdateAsync,          │
   └───────────────────────────────────┴── session lock, 7 s / 60 s / leave / close ┘
   │
   └─ client builds every visual (towers, plazas, crowds, traffic, rain) from replicated state
```

- **Server owns:** profiles, credits, every rule decision, lot assignment, the 1 Hz income tick, the Hot Data schedule, the Market schedule, character teleports (lift, home), collision shells, prompts, leaderboards.
- **Client owns (display only):** all decorative geometry and effects, build-mode previews (computed with the same pure modules), camera, UI, audio.
- **Why client-built visuals:** a 30-floor tower with interiors is thousands of parts. Replicating one JSON attribute per lot and building locally lets each client choose its own level of detail, keeps server memory flat, and means the server never has to create or destroy decorative parts. This is the main difference from Egg Garden, where `Plots.refresh` built models on the server.

## 3. Pure modules (`src/shared`)

Conventions as `docs/architecture/garden.md` section 2: `--!strict`, no Roblox globals, string requires, functions return new tables and never mutate inputs, `floor(x + 1e-9)` for every floor of a product, times passed in as `now`. Results are `(profile, ok, code?)` where `code` is a short refusal id the client maps to text (`power`, `credits`, `locked`, `occupied`, `bounds`, `walkway`, `max`, `full`).

Planned public surface (exact signatures in SPIRE-003):

| Module | Depends on | Functions |
|---|---|---|
| `SpireConfig` | `MetaRules` (types) | data: `DEPTS`, `FLOOR_COST`, `LV`, `UP`, `FUSION_SUPPLY`, `ITEMS`, `DECOR`, `EVENTS`, `NAMES`, `GLYPHS`, `COLOURS`, `COSMETICS`, `QUESTS`, `XP`; types `Profile`, `Floor`, `Item`, `TowerState` |
| `TowerRules` | `SpireConfig` | `supply(p)`, `draw(p)`, `floorMult(p, n, event)`, `deptAllowed(dept, n)`, `buyFloor(p, dept)`, `refitFloor(p, n, dept)`, `buyModule(p, n, slot, event)`, `upgradeModule(p, n, slot, event)`, `sellModule(p, n, slot)`, `moduleCost(dept, level, event)`; layout: `floorY(n)`, `slotOffset(slot)`, `liftZone(n)` |
| `PlazaRules` | `SpireConfig` | `footprint(id, r)`, `cells(item)`, `canPlace(p, id, x, y, r, ignoreUid?)`, `placeItem`, `moveItem`, `sellItem`, `hype(p)`, `hypeCap(p)`, `hypeMult(p)` |
| `MarketRules` | `Rng`, `SpireConfig` | `eventAt(unix)`, `eventLeft(unix)`, `forecast(unix, n)`, `isWeekend(unix)`, `price(base, event)` |
| `SpireEconomy` | `SpireConfig`, `TowerRules`, `PlazaRules` | `income(p, event)`, `tick(p, carry, dt, event) -> (p, carry)`, `offline(p, now)`, `hotBonus(p, event)`, `ipoShares(p)`, `ipo(p)`, `short(n)` |
| `SpireProgress` | `MetaRules`, all of the above | Spire `MetaRules` config, `defaults(now, seed)`, `sanitize(record, now)`, `login(p, now)`, `snapshot(p, now)`, lock helpers `canClaim/holds/locked/release` (as `GardenProgress`), request ops (`apply(p, action, arg, now, event) -> (p, ok, code)`), XP and quest wrappers, `publicState(p) -> TowerState` (the subset replicated on the lot) |

The request ops in `SpireProgress.apply` parse `arg` with the GDD O patterns, so the server router and the client preview call the same parser.

## 4. Server (`src/spire`)

| File | Kind | Owns |
|---|---|---|
| `SpireServer.server.luau` | Script | Entry: lot assignment (lowest free of 6; wait with notice if none), spawn in lobby, `Request` router (common checks, token bucket, then world checks, then `Profiles.request`), prompt handlers (Hot Data, visitor lift), lift and home teleports, the loop below, `SpireStatus`, ticker announcements, `BindToClose`; warns if `Players.MaxPlayers > 6`; logs `BuildInfo` at start. |
| `State.luau` | Module | `State.live: { [Player]: { lot, carry, bucket, hot, lastState } }`. |
| `Remotes.luau` | Module | Copied from Garden (section 1). |
| `Profiles.luau` | Module | Copied from Garden: session lock, coalesced `UpdateAsync` re-apply (one write per player per 7 s at most), 60 s autosave, final write on leave and `BindToClose`, failed load never writes, offline sessions never write. Publishes `Profile`, `Credits`, `Income`, `Floors`, leaderstats, and `Lot.State` via `publicState` when it changed (at most 4 Hz). Ordered store `SpireBoard<suffix>` by `lifetimeEarned` every 120 s when changed. |
| `Lots.luau` | Module | Builds the 6 lot shells once: ground, plaza grid collision, lobby collision and lift pads, the BUILD terminal, sign, prompts. Collision floors for a 30-floor tower are one thin invisible slab per owned floor plus the lift shaft; created and removed on `Profiles.Changed`. ≤ 60 server parts per lot plus 2 per floor. |
| `City.luau` | Module | Server-side collision only for the Grid Plaza and streets (≤ 1,500 parts); boards (Top Spires, Market) as SurfaceGuis. Decoration is client-side. |

### 4.1 Loop

`Heartbeat` accumulates `dt`; `now = os.time()`; `event = MarketRules.eventAt(now)`.

Every 1 s:
1. For each loaded session: `p, carry = SpireEconomy.tick(p, carry, 1, event)` applied in memory only (not queued per tick; the coalesced flush stores the running balance through the `snapshot` op). Publish `Credits` and `Income`.
2. Hot Data: if none active and `now ≥ nextHot`, choose a filled non-fusion slot with server `Random`, set `hot = { floor, slot, until = now + 45 }`, `Fx("hot", …)`; expire at `until`; schedule the next at `now + Random:NextInteger(60, 120)`.
3. `SpireStatus` when changed.
4. `Profiles.step(now)`.

Every 60 s: refresh the Top Spires board in a spawned thread.

Credits from the income tick are applied to the in-memory profile; every flush writes `snapshot` (credits, lifetime, run earnings, `lastSeen`) through the re-apply transform as an absolute value taken from the lock-holding session. Because only the session-lock holder writes, there is no second server that could add the same income again (the GARDEN-006 M1 class of bug).

### 4.2 Request handling

1. Common checks (GDD O): loaded and online session, types, `arg` length ≤ 40, token bucket (6, refill 4/s; a refused request does not refill), known action, arg/no-arg rule.
2. World checks: `lift` needs the character root inside the owner's lift zone (`TowerRules.liftZone` in lot space, on the server-side root position); `endorse` checks the target is in the server, not self, and the gate (with a cached `IsFriendsWith`, re-checked after the yield as Garden's `like`).
3. Decision: `Profiles.request(player, action, arg)` runs `SpireProgress.apply` on the in-memory profile with the current `event`; if accepted, the same op with the same fixed inputs is queued for the stored record. Results return `(ok, code)` to the client.
4. Effects: `Fx("built", …)` on accepted build actions; ticker on milestones.

The client never sends prices, amounts, levels to buy, positions or outcomes. Flash Sale prices are decided by the server's `event` at acceptance.

## 5. Client (`src/spire-client`)

| File | Owns |
|---|---|
| `ClientState.luau` | settings (music, SFX, Reduce Flashing, rain density, camera shake, announcements), quality tier (auto by device and frame time), signals |
| `Menu.client.luau` | forked start menu (GDD K1), LOCKER, REWARDS, STATS, SETTINGS, How to Play, IPO screen (M4), company rename, toasts mapped from refusal codes |
| `Hud.client.luau` | GDD K2: credits count-up, income, power and Hype bars, Market chip, Hot Data toast with GO, BUILD/LIFT/HOME, first-session script (GDD K5), "While you were away" |
| `Build.client.luau` | Build mode (GDD K3): tower view camera rig, floor cards, department picker, plaza grid with ghost preview and rotation, input for touch, mouse, gamepad; previews from `SpireProgress.apply` on a copy of the own `Profile` |
| `Lift.client.luau` | lift UI and transition (GDD K4) |
| `TowerView.client.luau` | builds each lot's exterior from `Lot.State` (art bible 5.1), interiors near the camera (5.3), construction sweeps, data-packet beams, Hot Data sparks; rebuilds only the floors whose state changed (diff against the last state) |
| `PlazaView.client.luau` | plaza items from `Lot.State` |
| `City.client.luau` | backdrop megacity, maglev, blimp, billboards, searchlights (built once, fixed seed) |
| `Atmos.client.luau` | lighting recipe and event looks (art bible 3), rain and splashes around the camera |
| `Crowd.client.luau` | umbrella-crowd NPCs per plaza from Hype (art bible 7); animated only within 250 studs |
| `Traffic.client.luau` | hover lanes and drones |
| `Fx.client.luau` | `Fx` handlers: juice (GDD K6), SFX, ticker |

### 5.1 Level of detail

| Distance from camera | Tower | Plaza |
|---|---|---|
| < 120 studs (own tower: current floor ±2) | exterior + interiors | items + crowd animated |
| 120 to 400 | exterior | items, crowd static |
| > 400 | exterior without balconies and signature parts | items hidden, lights only |

Quality tiers (Low on phones by default): Low halves rain, crowd and traffic counts and turns off interiors except the current floor. Tier drops one step automatically if the 5 s average frame time exceeds 33 ms.

### 5.2 Streaming

`Workspace.StreamingEnabled` stays off in v0.1: the server owns few parts, and client-built content is not streamed anyway. Revisit if phone memory exceeds 800 MB in the M2 look pass (art bible 12).

## 6. Saves

Summary; the contract is decision 0009.

- Stores `SpireProfile<suffix>` and ordered `SpireBoard<suffix>`; suffix per environment as the other games (staging and production never share a store).
- Session lock `{ id, at }`, stale after 120 s (as Garden). Load claims it with `UpdateAsync` (3 tries); without it the session runs offline and the player is told. Offline sessions and failed loads never write.
- Coalesced writes: at most one per player per 7 s; 60 s autosave; final write on leave and in `BindToClose` (parallel), releasing the lock.
- Every op is re-applied on the stored record; random inputs (Hot Data slot, company name seed) are chosen once and passed as fixed values.
- `PRODUCTION_UNIVERSE_ID` stays nil until SHANNON approves a production release (as the other games).

## 7. Security checklist (for SPIRE-008 QA)

- Every `Request` action and prompt refuses: wrong types, long args, malformed patterns, unknown ids, out-of-range floors/slots/cells, other players' lots, spam beyond the bucket, offline sessions.
- No buy/sell sequence gains credits (property test in `SpireEconomy.spec`).
- No client value is trusted for money, prices, levels, positions or outcomes.
- Teleports only via `lift` and `home`, validated on server positions.
- No `MarketplaceService`, `TextBox`, trading or gifting in Spire code (grep check in QA).

## 8. Testing strategy

| Layer | Tool | What |
|---|---|---|
| Rules | Lune (`lune run tests/run`) | every GDD check value; boundary tests; sanitise; lock helpers |
| Economy | Lune property and balance specs | buy/sell never gains; pacing within ±30% of GDD B (port of `game5-pacing-sim.py`) |
| Build | `rojo build spire.project.json` in CI | the place builds; `BuildInfo` present |
| In-engine | Studio test checklist per task | Request refusals from a client, two clients, rejoin with DataStores on, MicroProfiler |
| Published place | **Proposed:** Open Cloud Luau Execution smoke test after publish (section 9) | the published version has `ServerScriptService.Spire`, the lots, and `BuildInfo` equal to the commit |
| Feel | Playtest gates (production plan section 4) | SHANNON's ratings and timed notes |

## 9. Build, release and the baseplate risk

- CI builds `build/spire.rbxl` alongside the other places. `publish.yml` gets a `spire-staging` option mapping `spire-*` to `spire.project.json` (SPIRE-003). The `spire-staging` environment and its experience are created by a human (rule 7).
- **Build stamp:** before `rojo build`, CI and `publish.yml` overwrite `build-info/BuildInfo.txt` with the commit SHA, time and task id; the project maps it to `ReplicatedStorage.BuildInfo` (a local build shows `dev`). The server prints it at start and the start menu shows the first 7 characters in a corner. A playtest note only counts when it records the stamp it saw.
- **Post-publish check (proposed, SPIRE-002):** after the Open Cloud upload, run a Luau Execution task against the new place version that returns `BuildInfo.Value` and the count of expected top-level instances; fail the run if they do not match. This needs an Open Cloud key scope for Luau execution on the staging universe only, which is a credential change: SHANNON creates it (rule 7).
- **Why:** Bake Rush published "version 5" successfully, but SHANNON saw a baseplate (handoff, 2026-10-24). Until the cause is known, a green publish run does not prove the place is right. The production plan (R1) lists the suspects and the fix order.

## 10. Lessons applied from games 1 to 4

| Lesson (source) | Applied here |
|---|---|
| Money outside the saved balance can be paid twice across a server hop (GARDEN-006 M1) | Income credited directly; no unbanked pool; session lock from day one |
| No free plot gave a silent dead session (GARDEN-006 M2) | Lot freed before the final write; waiting notice and retry; Max Players 6 warning |
| Repeated equips wrote to the DataStore every time (NIGHT-006 M2) | All writes coalesced; no-op requests (equip what is equipped) are refused before queueing |
| Table modified while iterating crashed the tick (NIGHT-006 M4) | Loops over `State.live` iterate a snapshot; QA checklist item |
| No `BindToClose` (NIGHT-006 m7) | `Profiles.finishAll` in `BindToClose` from the first server commit |
| Mesh loads during the tick (NIGHT-006 m8) | Hero props preloaded at start; decorative meshes are client-side |
| `Highlight` cap around 31 (Egg Garden U) | No Highlights for repeated items; Neon and ForceField instead |
| Code-only reviews; Studio playtests never ran (all four games) | A greybox playtest gate (M1) before art, and the build stamp so notes match a commit |
| Staging baseplate (Bake Rush) | M0 pipeline trust milestone before any Spire publish |
| Duplicate spec keys in `tests/run.luau` (Bake Rush) | One entry per spec; runner already fails on unregistered specs |
