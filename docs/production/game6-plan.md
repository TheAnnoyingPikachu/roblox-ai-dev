# Lantern Express: production plan (v0.1)

Status: draft for SHANNON (LANTERN-001). Companion to `docs/game-design/game6-gdd.md`, `docs/architecture/lantern.md` and decision 0018. Task files: `studio/tasks/LANTERN-*.json`. One checkpoint for the whole milestone: `docs/checkpoints/LANTERN-V01.md`.

## 1. How this plan is built

- **Look first.** The art director's style test (the engine, one critter, the village house set at the HD standard) runs in parallel from day one in its own worktree, and its contact sheet is reviewed before the feature art tasks (LANTERN-008 to 010) start (studio lessons, Product and Art pipeline).
- **Rules before glue.** The pure modules (LANTERN-003, then LANTERN-004) land first with their specs and the pacing check values; every economy and safety bug QA has found so far lived in a pure module without a test or in server glue around a yield (studio lessons, Engineering).
- **Server and client in parallel on disjoint files** (LANTERN-006 writes `src/lantern/**`, LANTERN-007 writes `src/lantern-client/**`), both coding against architecture section 3 and decision 0018, so neither waits for the other. The shared UI kit and the SaveStore guard (LANTERN-005) land before the client starts its panels.
- **Art in parallel by file:** each art task owns its own `tools/blender/lantern/assets/*.py`; one task (LANTERN-011) writes the manifest, uploads, `LanternAssets.luau` and the register rows, so no two threads edit the same file. The game runs on part fallbacks until then.
- **Integration in Studio after the merge of server and client** (LANTERN-012): both sides tested alone missed real bugs before (studio lessons, Process).
- **Independent QA** (LANTERN-013, A15, who wrote none of it), then the staging publish and one checkpoint card (LANTERN-014).
- **As few PRs as possible** (SHANNON merges by hand): one PR per task, about ten files each; tasks that touch disjoint files can share a branch and a PR when one thread does both.

## 2. Milestones

| # | Milestone | Goal | Tasks | Exit |
|---|---|---|---|---|
| M0 | Design and look | GDD, decision 0018, architecture, this plan; the style test | LANTERN-001; the art director's task | Director reads the docs; the style test contact sheet reviewed |
| M1 | Rules | Every pure module and spec, the pacing check values in Lune | LANTERN-002, 003, 004, 005 | CI green; `lune run tests/run Lantern Loot Carry Wisp Track Depot Train SaveStore` |
| M2 | Playable greybox | Server and client on part fallbacks: a full run end to end, 1 to 6 players | LANTERN-006, 007 | Each task's Studio notes with the build stamp |
| M3 | Art | 45 assets, sounds, icons uploaded and registered | LANTERN-008, 009, 010, 011 | Contact sheets reviewed; register rows; `LanternAssets.spec` |
| M4 | Integrated v0.1 | Server, client and art together; the GDD Q timings and two-client checks | LANTERN-012 | Studio notes with the build stamp; MicroProfiler; phone emulator |
| M5 | QA | Independent review; fixes re-reviewed | LANTERN-013 | Verdict "ship to staging" |
| M6 | Staging and checkpoint | `lantern-staging` publish; SHANNON's one card: feel gate, look, setup, economy | LANTERN-014 | SHANNON's answers recorded in `docs/checkpoints/LANTERN-V01.md` |

Rough effort (hypothesis, thread-days): M1 3 days; M2 4 to 5 days in parallel; M3 4 days in parallel with M1 and M2; M4 2 days; M5 1 to 2 days plus fixes; M6 1 day plus SHANNON's 60 minutes (a solo leg, a two-player leg, the look review, the setup steps).

## 3. Task map

| Task | Type | Owner → verifier | Depends on | Risk | Output |
|---|---|---|---|---|---|
| LANTERN-001 | design | A06 → A01 | – | low | GDD, decision 0018 (Proposed), architecture, this plan, the pacing script, the checkpoint list, task files |
| LANTERN-002 | infrastructure | A14 → A04 | 001 | low | `lantern.project.json`, CI build and place check, `lantern-staging` publish target, architecture README row |
| LANTERN-003 | implementation | A10 → A15 | 001 | medium | `LanternConfig`, `LootRules`, `CarryRules`, `WispRules` and their specs |
| LANTERN-004 | implementation | A10 → A15 | 003 | high | `TrackRules`, `DepotRules`, `TrainRules`, `LanternProgress` and their specs (the seated rule, nothing lost, pacing values) |
| LANTERN-005 | implementation | A11 → A15 | 001 | medium | shared `UiKit` in the kit, `SaveStore` `newer` option and spec, decision 0011 note |
| LANTERN-006 | implementation | A09 → A15 | 002, 004, 005 | high | the server (`src/lantern/**`), `Models.luau` reads `LanternAssets` |
| LANTERN-007 | implementation | A11 → A15 | 002, 004, 005 | medium | the client (`src/lantern-client/**`) |
| LANTERN-008 | asset | A12 → A15 | 001 | medium | train, turret, items, depot pieces, rails, decor (Blender scripts) |
| LANTERN-009 | asset | A12 → A15 | 003 | medium | the 8 stop tiles, built on `LanternConfig.TILES` |
| LANTERN-010 | asset | A10 → A15 | 001 | medium | 13 critters, the wisp, the Lampeater |
| LANTERN-011 | asset | A14 → A15 | 008, 009, 010 | medium | manifest, uploads, `LanternAssets`, icons, sounds, register rows |
| LANTERN-012 | implementation | A09 → A15 | 006, 007 | high | integration fixes in Studio, timed playtest notes, two-client and phone checks |
| LANTERN-013 | test | A15 → A01 | 012 | high | `docs/qa/lantern-review.md`, fix re-review |
| LANTERN-014 | release | A14 → A01 | 013, 011 | high | `lantern-staging` publish with the build stamp, the checkpoint evidence |

The art director's style test is that thread's own task (not in this list). **Task ids:** this plan uses LANTERN-001 to LANTERN-014; the art thread should use a different prefix or numbers from LANTERN-020 up, so the two worktrees never create the same file. LANTERN-008 and LANTERN-010 start after the style test's contact sheet is reviewed (their `notes` say so; a dependency on a task file outside this branch would fail `validate-tasks`).

## 4. Build order

```
day 1   LANTERN-001 (this PR)        art director: style test (own worktree)
        LANTERN-002 ─┐
        LANTERN-003 ─┼─ LANTERN-004 ─┐
        LANTERN-005 ─┘               ├─ LANTERN-006 (server) ─┐
                                     └─ LANTERN-007 (client) ─┼─ LANTERN-012 ─ LANTERN-013 ─ LANTERN-014
        style test reviewed ─ LANTERN-008, 009 (after 003), 010 ─ LANTERN-011 ┘
```

- LANTERN-003 authors `LanternConfig.TILES` (sites and building boxes) and `TRACKS` (control points); LANTERN-009 builds the tile meshes around those boxes, so the tile layout is fixed before the tiles are modelled.
- LANTERN-006 and 007 may start on stubs as soon as LANTERN-003 merges (architecture section 1); they need LANTERN-004 merged to pass their Studio checks.
- LANTERN-011 can run twice (two upload runs of about 22 assets each), the first as soon as LANTERN-008 is reviewed.

## 5. Playtest gates (asked at the one checkpoint)

| Gate | Who | Where | Steps | Passes when |
|---|---|---|---|---|
| Stamp | SHANNON, 2 min | staging | read `build <sha>` in the corner and the `[Build]` line in F9 | equals the release commit |
| Feel | SHANNON, 25 min | staging, PC and phone | one leg solo on a fresh profile, timing GDD K's beats; one leg with a second player (help-carry a crate, a night on two turrets); rate 1 to 5; "what did you want to do next?" | rating ≥ 4 (GDD R) |
| Look | SHANNON, 10 min | staging | the start menu, a stop at the bell, a night with beams, the Lampeater, the album | each frame ≥ 4 or a fix list |
| Content | QA plus one tester | staging | the GDD Q list; leave and rejoin mid-leg; a phone; a gamepad | every Q item has evidence |

Every note records the date, device, build stamp, profile state, pass or fail per step, console warnings and the rating.

## 6. Risks

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | The train jitters on clients | Medium | High | server-owned rigid align constraints, seated rule; two-client recording in LANTERN-012 before art lands; fallback in decision 0018 | A09 |
| R2 | Lamp aiming feels laggy | Medium | High | aim in the train frame, local beam drawn at once, 7° cone, 10 Hz server test; QA attack for fairness and abuse | A09, A11 |
| R3 | Carrying with two players fights over physics | Medium | Medium | the crate is server-owned and follows the carriers' midpoint (no weld to two characters); small items weld to one | A09 |
| R4 | Stops look samey | Medium | Medium | 8 tiles, seeded items, rarity glows, day light changing over the leg; v0.2 adds tiles and biomes | A12 |
| R5 | Runs too easy for 16+ (pacing: casual crews always reach Dawn) | Medium | Medium | the feel gate asks; `PER_TURRET` and the dive rate are data; the weekly board rewards greed | A06 |
| R6 | Read as a Dead Rails clone (M34) | Low | High | lanterns, fog, critters, no guns, own name and thumbnail; the look review | A06, art director |
| R7 | Phone performance at night (40 wisps, beams, 14 critters) | Medium | Medium | tri budgets (architecture 9), fog at 250 studs, Roblox mesh LOD; phone check in LANTERN-012 | A11 |
| R8 | The 16+ trial is slow without an audience (M39) | High | Medium | the checkpoint's Sponsored ads question waits for launch data (concepts section 5, item 4) | Director |
| R9 | A shared-kit change breaks another game | Low | Medium | the UiKit move is a new file (Garden unchanged); `newer` is an optional SaveStore field with tests | A11 |
