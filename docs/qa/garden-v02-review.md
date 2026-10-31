# Egg Garden v0.2: QA and security review (GARDEN-011)

Reviewer: A15 (did not write GARDEN-007 to GARDEN-010 or GARDEN-020). Date: 2026-10-31. Branch `garden/v2`, worktree `rad-garden`, reviewed at `186756b` against `origin/main`.

Scope: `git diff origin/main...HEAD` for `src/shared/{GardenConfig,GardenRules,HatchRules,GardenProgress,DashRules}.luau`, `src/garden/*`, `src/garden-client/*`, `src/relay/Models.luau`, the tests and the upload tools. Checked against `docs/game-design/game4-gdd.md` sections S and T, `docs/decisions/0012-egg-garden-v02.md` and `docs/architecture/garden.md`. Line numbers refer to `186756b`.

This is a code review with scripted checks against the real `DashRules`. **Nothing was run in Studio by this reviewer.** Studio facts below are the Director's offline, one-tester notes. Labels: **Computed** came from a script run here, **Read** from reading the code, **Director** from the Studio notes.

## Summary

| Severity | Count |
|---|---|
| Blocker | 1 |
| Major | 1 |
| Minor | 9 |

**Verdict: not ready for the checkpoint.** B1 means no honest player can finish a race, so no prize or coins can be earned. B1 and M1 are small data and one-line fixes. Everything else in the prize, save and round logic held up.

### Tool runs (local, 2026-10-31, at `186756b`)

| Command | Result |
|---|---|
| `lune run tests/run` | **450/450 passed**, 0 failed, 0 load errors. `test-results.json` deleted |
| `selene src tests` | 0 errors, 0 warnings, 0 parse errors |
| `stylua --check` on the 28 changed `.luau` files | Clean on the git blobs (LF, the form CI checks). The worktree fails on 10 files only because `core.autocrlf=true` left them CRLF. Not a defect |
| `rojo build` of `default`, `garden`, `night`, `relay` | All build (outputs in the scratchpad) |
| `node tools/check-place.mjs garden.project.json` | Matches, 54 scripts |
| `node tools/validate-tasks.mjs` | 47 task files valid, re-run after this review's edit to GARDEN-011 |
| `tools/scan-secrets.sh` | No secrets found |
| `checkScope` called directly | `ok: true`, 90 changed files, 0 outside, tasks GARDEN-007, 008, 009, 010, 011, 020. `node tools/check-scope.mjs origin/main` prints nothing on Windows (m9) |
| `python docs/game-design/game4-pacing-check.py` | Same numbers as decision 0012: worst return 52.3%, Celestial payback 64,429 s, 60 min/day Celestial on day 12, day 45 income 42,752 without and 496,000 with. The script's `CELESTIAL` constants match `GardenConfig` |

## Blocker

### B1. Lily Hop cannot be crossed: three of its five gaps are 12 studs and a default jump clears about 8.7

- **Where:** `src/shared/GardenConfig.luau:418-421` (platforms at x 76, 52, 28, 4, half width 6), `src/garden/DashWorld.luau:33-34` (decks end at x 88 and x -8). No `WalkSpeed`, `JumpPower`, `JumpHeight` or gravity is set anywhere in `src/garden`, `src/garden-client` or `garden.project.json`, so the defaults apply.
- **Numbers (Computed):**

| Gap | Width (studs) |
|---|---|
| CP3 deck to platform 1 | 6 |
| Platform 1 to 2 | **12** |
| Platform 2 to 3 | **12** |
| Platform 3 to 4 | **12** |
| Platform 4 to CP4 deck | 6 |

| Character | Air time | Flat reach at 16 studs/s | Best case: 2 studs of extra drop and 1 stud of overhang at each edge |
|---|---|---|---|
| JumpPower 50 | 0.51 s | 8.15 | 10.75 |
| JumpHeight 7.2 | 0.54 s | 8.67 | 11.23 |

  Clearing 12 in flat air time takes 22 to 24 studs/s. The best case column is a generous upper bound, not a normal jump. The platforms move only along z, so they add no x speed, and carry changes position, not velocity (`DashFx.client.luau:201-207`). No knock source is near. The 6-stud gaps are fine, even with the platform top 1 stud above the deck (reach about 7.8).
- **What happens:** every honest racer stops at platform 1. CP4 is unreachable, so nobody finishes, the round ends on the 120 s limit, and no Moon Egg or coins are ever paid. The only racer who can finish is an exploiter (m2). The Director's scripted straight run passed because the server does not check for a platform under a root, which is correct. The bot falling at the first gap is a separate timing matter: that gap is reachable.
- **The tests could not catch it:** no spec relates platform positions to jump reach. The 200,000-step fuzz and the T10 values only exercise the rules.
- **Fix:** 5 platforms at x 76, 58, 40, 22, 4, phases 0, 0.5, 0, 0.5, 0. That makes all six gaps 6 studs. With 4 platforms the best possible even gap is 9.6, still too long. Course layout may be tuned in the same task (decision 0012 Consequences). Change `tests/GardenConfig.spec.luau:254` (`3 4 3 4` to `3 4 3 5`), GDD T2 and the table in `garden.md` 3.2. Add a spec: walking edges along the route are at most 7 studs apart. Then cross it by hand in Studio on a keyboard and a phone, with the uploaded mesh (m4).

## Major

### M1. HOME silently un-readies a ready player and can cancel the countdown for everyone

- **Where:** `src/garden/GardenServer.server.luau:201-204` calls `Dash.leave` for every `home`; `src/garden/Dash.luau:194-200`; `src/shared/DashRules.luau:263-271` removes the id from `ready` and cancels below 3.
- **What happens:** the natural flow is to press Ready at the plaza pad, then HOME to walk back to the garden, which is what T3 promises ("a player can ready up from their garden and keep gardening"). HOME takes that player off the list. With exactly 3 ready the countdown drops to idle for all three (Computed: `countdown -> idle`, 2 ready). The player who pressed HOME gets no message; only the other two get the toast. The architecture says this is intended, GDD T3 says otherwise, so the GDD wins (`garden.md` header). GARDEN-009's notes promised a checkpoint item for it, and `docs/checkpoints/GARDEN-V02.md` has none.
- **Fix:** in the `home` branch, call `Dash.leave` only when `Dash.isRacing(player)`. Update `Dash.leave`'s line in `garden.md` 4.1. A ready player who wants out uses NOT READY.

## Minor

### m1. Ball Alley has one lane no ball can hit, the exact centre line

- **Where:** `src/shared/DashRules.luau:312-315`, `src/shared/GardenConfig.luau:411-414`.
- **What happens:** a ball is at its peak (y 153) when it crosses z 300 and on the deck only at z 293 and 307. On z = 300 the closest approach to a standing root (y 143) is 7.28 studs, and a hit needs 7 or less (Computed, all phases). Chance of at least one knock walking the alley: z 300 **0%**, z 299 and 301 about 40%, z 298 and 302 about 63%, z 295 and 305 about 90%. So the Director's clean walk through the alley on the centre line was geometry, and it is not evidence that balls do not hit. A real player rarely holds that line exactly, so this is a tuning issue.
- **Fix:** `lift` 4 in place of 8 closes it: z 300 becomes 100%, and the side lanes stay at 95 to 100% (Computed). `lift` 5 does not.

### m2. The speed check does not stop teleports, so T7's "cannot teleport" is false

- **Where:** `src/shared/DashRules.luau:224-235` (the limit grows while the root stands still; `lastAt` moves only when the position changes), `251-260` (`lastPos` nil, so the first sample after a server teleport is not checked). GDD T7 line 650.
- **What happens (Computed):** a client that stands still 4.8 s and then jumps to the next zone, five times, gets checkpoints at 5, 10, 15 and 20 s and a **finish at GO + 25.2 with 0 strikes**. It meets no obstacle and needs no platform. Also, after a deliberate fall a client can appear 100 studs away just after the settle window with no strike. An honest run is at least about 34 s (Director: 33.9 s at 17 studs/s), so this client takes the egg whenever it wants, up to the cap. Skipping checkpoints stays impossible, and 25 s stays the floor.
- **Risk:** bounded by the same limits T7 accepts: 3 Moon Eggs a day, nothing touched that another player owns. Accepted in spirit, but the text claims more than the code gives.
- **Fix:** correct T7. After B1, measure the fastest honest run and raise `minFinish` to just under it. Optionally pass the destination to `teleported` and keep it as `lastPos`, which closes the second path in one line.

### m3. Two ways an honest player can be flagged, both needing a very bad connection

- **Where:** `src/shared/DashRules.luau:228` and `src/shared/DashRules.luau:217`.
- **What happens (Computed):** (a) Allowed distance between samples 0.2 s apart is 31 studs. The largest honest horizontal speed is about 65 studs/s (pendulum knock), so a strike needs about 0.48 s of knock movement arriving inside one tick, a jitter swing near 280 ms in the middle of a knock. (b) After a *flag*, with ping above 1 s, a stale sample after the settle window is stored as `lastPos`, then the real teleport lands as a jump: a second strike. After a *fall* this cannot give a strike: the stale sample is below `fellY`, so it repeats the splash and clears `lastPos`.
- **Everything else is clean (Read and Computed):** start, fall, flag, CharacterAdded and all other server teleports call `teleported` or clear the round. A frozen client gets more allowance, not less. A knock (at most 70) plus walking stays under the limit. A strike costs a checkpoint, 3 are needed to leave a round, and nothing is saved.
- **Fix:** optional. Stay in settle until a sample is near the teleport target, with a 3 s limit. Worth doing only if staging logs show `[Dash] failed a position check` for honest players.

### m4. The uploaded lily pad is round and collides as a mesh, against architecture section 9

- **Where:** `src/garden-client/DashFx.client.luau:142-150`, `tools/blender/garden/assets/dash.py:123-141`, `src/relay/Models.luau` (`loadNight` sets no `CollisionFidelity`), `docs/architecture/garden.md:714` ("No mesh collision is used on the course").
- **What happens (Read):** the walked surface is a round pad of 9 petals inside a 12-stud box. Its real edge is shorter than 12 away from the axis and between petals, so the z timing is harder than the block fallback suggests. The carry raycast (`DashFx.client.luau:202`) can miss between petals, so a player can stop being carried for a frame. The collision shape depends on how Roblox decomposed the mesh.
- **Fix:** keep the mesh as decor and add an invisible 12 x 2 x 12 Block as the collider and raycast target, as the decks do.

### m5. A finisher who steps off the deck stays below it

- **Where:** `src/shared/DashRules.luau:217` returns early for a finished racer.
- **What happens (Read):** after finishing, a racer who walks off the deck gets no splash. They stand on the invisible catcher at y 118 for up to 20 s, until the round ends and sends them home. They are also clear of every obstacle by then, so nothing is lost.
- **Fix:** optional. Run only the fall check for finishers.

### m6. Racers face north after every teleport

- **Where:** `src/garden/Dash.luau:69` (`CFrame.new` with no rotation).
- **What happens (Read):** the course starts eastward (+x) and the character faces -z, at the start spots and at every respawn, so the first second after a splash is spent turning.
- **Fix:** pass a facing with the spot (GO: +x; each checkpoint: towards the next one).

### m7. Text under 18 px on phones in two new places

- **Where:** `src/garden-client/DashFx.client.luau:328-347` (pill), `src/garden-client/Menu.client.luau:677` (Index cells).
- **What happens (Read, estimate from about 0.56 em per character):** the pill is 376 by 40 px of text area under a 0.6 UIScale. "Ready for the next Splash Dash" scales to about 13 px, "Splash Dash starts in 12" to about 17 px. The file's own rule (`DashFx.client.luau:212`) is that text stays above 18 px. On a 5-cell lion or dragon row a cell is about 95 px wide on a 640 px phone, so "Clear, Sunbeam, Moonfall, Rainbow Shower" in 44 px falls to about 12 to 14 px. The other new text is fine: results rows 20.4 px, hint 19.2 px, `para` 18 px with no UIScale on the panel.
- **Fix:** shorten the pill text ("Next race: ready") or widen it. Show "Any weather" in a cell whose mutation is in all four tables.

### m8. Documents that drifted from the code

| Where | Says | Code |
|---|---|---|
| GDD T7 line 650, T10 line 698 | finish under 28 s; check value 27.9 / 28.0 | `minFinish` 25; spec tests 24.9 / 25.0 (`tests/DashRules.spec.luau:134`) |
| `garden.md:638` | INDEX (36 entries) | 38 |
| `garden.md:714` | no mesh collision on the course | platform mesh collides (m4) |
| `garden.md` 4.1 `Dash.leave` | home leaves ready | conflicts with GDD T3 (M1) |
| `src/relay/Models.luau:162`, `src/shared/NightAssets.luau:2` | `tools/blender/night/write-assets-module.mjs` | moved to `tools/blender/write-assets-module.mjs` |
| `docs/checkpoints/GARDEN-V02.md` | no HOME item | GARDEN-009 notes promise one (M1) |

### m9. Local tool entry points do nothing on Windows

- **Where:** `tools/check-scope.mjs:48`, `tools/verify-publish.mjs:142`, `tools/write-build-info.mjs:15`.
- **What happens:** ``import.meta.url === `file://${process.argv[1]}` `` compares `file:///C:/...` with `file://C:\...`, so the main block never runs. `node tools/check-scope.mjs origin/main` prints nothing and exits 0, which looks like a pass. CI runs on Linux, where it works, so this is a false comfort locally and not a hole in the gate.
- **Fix:** `import { pathToFileURL } from "node:url"`, then `import.meta.url === pathToFileURL(process.argv[1]).href`.

## Director's open questions

- **Can Lily Hop be crossed?** No (B1).
- **Ball alley without a knock:** geometry on the exact centre line (m1). Off that line balls hit 40 to 90% of the time.
- **Pendulums without a knock:** not explained by geometry. Walking the bridge unhit is an 8 to 18% event (Computed: x 100 92% hit, x 95.5 82%), and on a straight line at z 300 Sweeper Green hits 100%. A knock on a 10-wide bridge should mean a splash, and 20.6 s to CP3 leaves no room for one. Luck is possible but is not a safe reading. The client path is sound (Read: `DashFx.client.luau:192-197` runs `knock` each Heartbeat with server time), so there are two things to separate live. Either the bot's movement overrode the velocity, or T11's assumption fails: a walking humanoid may cancel a one-shot `AssemblyLinearVelocity` within a few frames. Test: stand still at (100, 143, 350), which by the rules gives 2 knocks in 5 s, then again holding W. If the push dies, hold a `LinearVelocity` for about 0.2 s.
- **Is the pendulum bridge passable?** Yes with timing: a bob is in a lane for about 0.4 s of each 2.5 s, and crossing its 12-stud reach takes 0.75 s. Blind walking fails, which is the point of the stage.

## Focus checks

In this section and the T9 table, "spec `:n`" is line n of `tests/DashRules.spec.luau`.

| Check | Result | Evidence |
|---|---|---|
| Prize exactly once: finish | Pass | One finish per racer (`DashRules.luau:217,206-209`). `award` runs in the same step with no yield (`Dash.luau:84-109`). Specs `tests/DashRules.spec.luau:440,458`, fuzz at `:833` |
| Prize: leave | Pass | `onLeave` runs `Dash.leave` first (grants nothing), then the final write carries the queue (`GardenServer.server.luau:509-522`, `Profiles.luau:460-489`). A leaver is `out`, so no later sample can finish them |
| Prize: disconnect | Pass | Same path as leave |
| Prize: shutdown | Pass | `Dash.close` sets `closed` first, so no finish after it, then `finishAll` (`GardenServer.server.luau:541-551`). PlayerRemoving and BindToClose cannot bank twice (`State.live` cleared first) |
| Prize: save retry | Pass, one accepted limit | Failed flush puts ops back in order; each attempt re-applies to the stored record; re-apply spec present; `session.prizes` falls only on success (`Profiles.luau:148,178`). See accepted risks for a commit that returns an error |
| Ordered checkpoints | Pass | `racer.next` only (`DashRules.luau:238-246`), spec `:335`. Every zone spans its deck at the exit (Read, geometry checked for all 5) |
| Speed checks and server teleports, no false strikes | Pass, see m3 | Spec `:377`. Falls never strike |
| Legitimate player flagged | Only with extreme jitter or ping (m3) | Computed |
| Ready and countdown with 2, 3, 6 and a 7th | Pass | Specs `:61,75,222,233`. All on one thread with no yields in `Dash.luau` |
| Players leaving at each phase | Pass | Specs `:548,559,569,589,604,619,643` |
| Fewer plots than ready players | Cannot happen | Ready is capped at 6 and needs `State.live`, which needs a plot (`GardenServer.server.luau:175`, `:456-470`); `Dash.step` re-checks at the start (`Dash.luau:224`) |
| `Dash.leave` during `starting` | Pass | Racer marked out, round goes on, or `over` "empty" if none left. Spec `:569` |
| Rate limits | Pass | `dashReady` and `plantPrize` pass `admit` in `onRequest` (`GardenServer.server.luau:181`), the pad prompt too (`:307-311`). Shared 0.35 s limit |
| Schema v2 sanitize | Pass | `GardenProgress.luau:222-236`. Bad values covered by specs; both fields survive the flush path |
| v1 save with an in-progress egg | Pass (rules) | Literal record with star growing, moon ripe, meadow growing: every field equal (`tests/GardenProgress.spec.luau:458`). DataStores-on run still to do |
| Rollback risk | Real, documented | Decision 0012 and checkpoint item 1. `ROBLOX_RESTART_SERVERS` is off unless set, so the restart is manual on both places. Must be in the publish notes |
| Celestial mutation in every rolling path | Pass | `HatchRules.luau:66-81` skips the draw; `apply` refuses a mismatch both ways (`:95-99`); no weather table has it, and `rollMutation` is the only other path |
| Index 38, cosmetic thresholds | Pass | `INDEX_SIZE` counted by a spec (`tests/GardenConfig.spec.luau:171`). Only cosmetic with an index gate is `golden` at 20, a count. No other 36 in the client code |
| Published odds equal the rolls | Pass | Card reads `egg.odds`, the fixed mutation at 100.00% and `SIZES` (`Menu.client.luau:533,568`). Meter text "by hatch 10" matches `pity >= 9` |
| Release at most 60% | Pass | Worst 52.3% by script; spec uses the fixed mutation (`tests/GardenRules.spec.luau:117`). Celestial 0.01% |
| Client and server contract | Pass | Below |
| Obstacle timing | Pass | `ClientState.now` is `GetServerTimeNow`; `pose` is pure |
| Client joining mid-round | Pass | Not in `status.racers`, so no obstacles and no card; panel says the race is running and it can ready for the next. A rejoining racer stays out (`out` is kept for the round) |
| Memory leaks | None found | `clearObstacles` destroys the folder and clears both tables on every exit; `names` cleared on `over`; `Dash.track`'s connection dies with the character; `meshCopies` is one per bed |
| Per-tick cost | Fine (not profiled) | Server: at most 6 samples at 5 Hz, each a small table copy, and no writes. Client in a race: 14 `PivotTo` and 1 raycast a frame |
| Text minimums, gamepad | m7; gamepad reads correct, device check open | `selectFirst` on open, `rerender` restores selection, READY changes in place, selection cleared at a round start |
| Trademark | Pass | No match in `src`, `docs`, `tools`, `tests`, `assets` except GARDEN-010's own check wording in its task file, which is not player text |

### Contract, each side read

| Item | Server | Client | Match |
|---|---|---|---|
| `dashReady` (no arg) | `GardenServer.server.luau:43,199` | `Menu.client.luau` `ask("dashReady")` | Yes |
| `plantPrize` (egg id) | `:42`, `Profiles.luau:324` | `ask("plantPrize", egg.id)` | Yes |
| `home` leaves a round | `:201` | HUD button stays in a race | Yes (M1) |
| `dashCheckpoint { cp, total }` | `Dash.luau:129` | `DashFx.client.luau:698` | Yes |
| `dashSplash { cp, reason }` | `Dash.luau:138` | `:702`, `onSplash` | Yes |
| `dashFinish { by, name, place, time, egg, coins }` | `Dash.luau:148` | `onFinish`, `showResults` | Yes |
| `dashOver { winner, prize, reason }` | `Dash.luau:161` | `onOver` uses `winner`; `prize` and `reason` unused | Harmless. The card's egg line comes from `dashFinish`. "Time is up." also shows for `empty`, which only a struck-out last racer can see |
| `GardenStatus.dash` | `DashRules.status` | `ClientState.dashOf` defaults every field | Yes |
| Attributes | `Profile`, `ProfileOnline` only | both read | Yes, none new |
| `DashFx` sends nothing | | no `Request` handle in the file | Yes |

## GDD S6 cases

| Case | Status | Evidence |
|---|---|---|
| Bought during a weather event | Pass (rules) | `HatchRules.luau:75-79`; spec: Celestial is always `celestial` in all 4 weathers. ODDS card "any weather" |
| Hatched with the garden full | Pass (rules) | `roll` returns nil, notice, egg stays ripe (`GardenServer.server.luau:230-233`, `tests/HatchRules.spec.luau:359`) |
| Released by mistake | Pass (rules) | Confirmation shows the value; favourites refused (`tests/GardenRules.spec.luau:93`). Celestial release 60,000 to 450,000 (`:80-84`) |
| Rollback | Documented, not testable here | Decision 0012, checkpoint item 1. No guard by decision |

## GDD T9 cases

Pass means the rule and the server or client code were checked. Nothing here was run with more than one client.

| Case | Status | Evidence |
|---|---|---|
| Ready player leaves during the countdown | Pass | `DashRules.leave`, specs `:548,559`; pad text `DashWorld.luau:140-147`; toast `DashFx.client.luau:633` |
| Ready player has no character at the start | Pass | `Dash.luau:224`, specs `:259,272`. The left-out player also loses ready, which T9 allows |
| Fewer than 3 in the server | Pass | `Menu.client.luau:1135`, greyed button text. Client side only, and the server accepts a ready, which is harmless |
| Racer leaves or disconnects | Pass | `DashRules.leave`; a rejoin is not a racer |
| 2 left mid-round (3 started) | Pass | Spec `:589` |
| Everyone left | Pass | Spec `:604` |
| Winner leaves before the prize saves | Pass by review | See focus checks. Needs the DataStores-on test in GARDEN-009 |
| Profile offline or locked | Pass | Director: offline finisher got 100 coins and no prize. `Dash.luau:225,120-121,99-101` |
| Session goes offline mid-round | Pass | `Dash.luau:94-96`, `Profiles.luau:175` |
| Beds full | Pass | `Menu` "BEDS FULL"; `canPlantPrize`; prize needs no bed |
| Below Level 10 | Pass | Director: `plantPrize` at Level 1 refused. T10 spec `:196`; `Menu` `LEVEL 10`; results line in `DashFx.client.luau:441-445` |
| Already at the daily cap | Pass | Spec `:469`; panel and notice text match T9 word for word |
| Coin cap reached too | Pass | `dashCoins` returns 0, no op, "Finished!" |
| Round during a weather event | Pass | No weather read in `Dash.luau` or `DashRules.luau` |
| Round crosses midnight UTC | Pass | Eligibility at the start (`Dash.luau:225`), grant by the day of the finish (`:85`) |
| Character resets or dies | Pass (reviewed) | `Dash.place`, `GardenServer.server.luau:481-493`. Not run live |
| HOME during a round | Pass, see M1 for HOME outside a round | Director's flow; `GardenServer.server.luau:201-209` |
| Waiting for a plot | Pass | No `State.live`, so `onRequest` and `admit` refuse |
| Server shutdown | Pass by review | `Dash.close`, no teleports |
| Server crash | Pass | No round state is saved |

## Accepted risks, for SHANNON

- **N2 (checkpoint item 9):** a flush still retrying 10 s after leave, or a final write failing all retries, loses that session's ops, a prize among them. The player has left, so nothing tells them.
- **`UpdateAsync` commits but returns an error:** the retry re-applies `dashPrize`, giving one extra egg, within the daily cap. Every op already behaves this way.
- **Griefing:** a friend can toggle ready at the last moment to cancel a 3-player countdown. T3 allows the cancel; the 0.35 s limit is the only brake.
- **StreamingEnabled** is set nowhere in the repo (GDD T11). The Director's Studio run had the course present, so confirm it on the published place.

## GARDEN-011 acceptance

| Criterion | Status |
|---|---|
| Every T9 and S6 case checked with evidence or a defect | Done, tables above |
| Server decides every outcome; prizes survive leave, offline, shutdown | Done by review |
| v1 save keeps every field, Studio with DataStores on | **Open** (spec passes) |
| Pacing re-run, same results | Done |
| Greybox feel gate and a 3 to 6 player staging playtest with the build stamp | **Open**, and blocked by B1 |
| Checkpoint put to SHANNON once | **Open**, after B1, M1 and the above |

## Only a live session can prove

- A real 3 to 6 player round: ready races, everyone teleported, GO, finish order, teleport home, and a results card on every client.
- Crossing the fixed Lily Hop by hand, on keyboard, phone and gamepad, with the uploaded mesh.
- Whether a knock moves a walking player (T11), and whether a typical run is 70 to 90 s.
- Prize after leaving at once and rejoining, and a shutdown during a round, with DataStores on. A v1 save loaded on the v2 build. A server hop.
- `GetServerTimeNow` agreement across clients, the feel on a phone with real ping, and whether honest players ever log a strike.
- Text sizes and gamepad selection on a device. Server frame time and network use with 6 racers.
- That publishing restarts every server, on staging first.
