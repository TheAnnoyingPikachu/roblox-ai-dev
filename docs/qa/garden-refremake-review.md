# Egg Garden creature remake: QA review (GARDEN-059)

Reviewer: A15 (did not write GARDEN-059). Date: 2026-11-06. Branch `garden/refremake`, worktree `rad-ref`, reviewed at `e1c59e7`.

Scope: `git diff origin/garden/v05...HEAD -- src docs studio` (8 files): `GardenAssets` (25 new model and decal ids, new sizes, `creature_hedgehog` with no model), `Models.MESHES.hedgehog`, `CreatureFx` (no SelectionBox, faint fills), `BedFx` (Aurora fill 0.88), the architecture, register and pipeline docs. Connected code read: `Plots.luau` (`blenderCreature`, `makeCreature`, `Plots.build` warm-up), `Models.luau` (`spawn`, `night`, `place`, `loadNight`), `CreatureFx` (`track`, the sweep, the frame loop), `BedFx` (`drop`), `ClientState.HIGHLIGHT_BUDGET`.

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 2 |
| Minor | 4 |

**Verdict: fix first.** The models themselves are ready: all 26 load with no `[Models]` warning, are textured, face the front, stand on the pad at a sensible size, and the hedgehog AI mesh faces forward (not 45 degrees). The mutation looks keep faces readable, Celestial is not gold, and no box is drawn anywhere, including past the budget. Two small fixes first: the Highlight budget leaks on every creature rebuild, which (now that the SelectionBox fallback is gone) leaves mutated creatures and the Aurora egg with no Highlight later in a session (M1); and the 50 new asset ids have no register rows (M2).

## Tool runs (local, at `e1c59e7`)

| Check | Result |
|---|---|
| `lune run tests/run` | 578/578 passed, 0 failed, 0 load errors (test-results.json deleted) |
| `selene` on the 4 changed .luau | 0 errors, 0 warnings |
| `stylua --check` on LF copies of the 4 changed .luau | clean |
| `node tools/validate-tasks.mjs` | 79 task files valid |
| `node tools/check-scope.mjs origin/main` | all 332 changed files in scope (GARDEN-027 to 059) |
| `rojo build garden.project.json` + `node tools/check-place.mjs` | built; place matches the project |

## Findings

### Major

**M1. The Highlight budget leaks on every creature rebuild, so mutated creatures and the Aurora egg lose their Highlight later in a session.** (`CreatureFx.client.luau`, the sweep at about line 366, and `track`'s `Destroying` hook at about line 322)

- When the server rebuilds a creature (placing, storing, hatching, renaming, a display garden swap), the client never calls `Destroy` on it. The model is only removed, so neither `inst.Destroying` nor the Highlight's `Destroying` fires. The sweep sets `views[inst] = nil` but does not destroy `view.look`, so `ClientState.highlights` is never decremented.
- Measured in Studio: after one rebuild of plots 2 and 3, the counter read 26 with 5 Highlight instances in the place. Every mutation look built after that had no Highlight. Two Aurora eggs planted next also got none, because `BedFx` uses the same counter. Resetting the counter in a scratch script brought both back.
- The root cause predates this task (v0.3). Before this task, a drained budget fell back to a SelectionBox, so the look still showed. Now it falls back to nothing: only sparkles and particles. On a live server, a few dozen rebuilds of mutated creatures will leave every new mutated creature without its outline or fill, and every Aurora egg without its Highlight.
- Fix: release the look the way `BedFx.drop` does. When the sweep finds an `inst` outside Workspace, destroy `view.look` and `view.extras` (the `Destroying` hook then decrements). Better still, do it in one `drop(inst)` that both the sweep and `inst.Destroying` call.

**M2. The 25 new creature models and textures have no register rows.** (`docs/assets/register.md`)

- 50 new ids (25 models plus 25 decals in `GardenAssets`) appear nowhere in the register. Rule 9 requires a row, and the v0.5 review held every shipped id to it.
- The 26 old rows (for example `creature_bunny` 127855365541226, line 172; `creature_hedgehog` 91865811495849, line 183) still say "in game", but those ids are retired.
- Fix: update each creature row to its new model and decal ids and its upload runs (42281587048, 42281598118). Mark the old hedgehog Blender row as retired, since the hedgehog now ships through the AI-mesh row on line 12.

### Minor

- **m1. Architecture 6.2 is half updated** (`docs/architecture/garden.md`). The Golden bullet still says `FillTransparency` 0.5, but it is now 0.9. The Celestial bullet still gives the 0.45 to 0.7 pulse, the SelectionBox past the budget, outline 0.2 and PointLight brightness 1.4; they are now 0.82 to 0.94, no box, outline 0.1 and brightness 0.8. The Budget bullet says "about 31", but `HIGHLIGHT_BUDGET` is 26. The section 5 table row was updated.
- **m2. The pipeline reference log is out of date** (`docs/production/ai-reference-pipeline.md`). Every row still says "not uploaded; awaiting Director sign-off", although 25 creatures are now uploaded. The hedgehog row says "Remade (`creature_hedgehog`, 5,978 tris)" without saying that the AI mesh ships instead. The "Shipped AI meshes" section below the log does say so.
- **m3. Two sizes for the hedgehog.** `GardenAssets.creature_hedgehog.size` is {2.57, 2.8, 2.45}, the unshipped remake's manifest size. `Models.MESHES.hedgehog.size` is (2.4, 2.8, 2.63), the size that ships. The first is unused while `model` is nil, but anyone who later uploads `creature_hedgehog` gets the remake silently. A comment there would help ("model nil on purpose: the AI mesh in Models.MESHES ships, see the pipeline doc").
- **m4. Texture images still processing.** The console shows "Asset content representation is being generated" for many of the new texture ids (for example 71711232674738 bunny, 113239624764284 capybara, 110536781273370 hedgehog). It is transient: every creature rendered textured within the session, and no `[Models] ... texture did not load` warning appeared. Re-check once on staging before publishing.

## Evidence (Studio play test)

Setup: a local build of `garden.project.json` at `e1c59e7` (corner label and log `[Build] dev`, a local build with no CI stamp), opened in its own Studio instance (`garden-qa.rbxl`). DataStores were off; the dev profile was 96807256. The owner's `garden.rbxl` and `refgen.rbxl` were not touched. Scratch server and local scripts were inserted only into the play session, and the session was closed without saving. Screenshots are in `C:\Users\pikachud\AppData\Local\Temp\claude\C--WINDOWS-System32\43c7be21-b4af-4eeb-bd21-a7c85b727749\scratchpad\shots\refremake\` (not committed).

1. **Load.** `ReplicatedStorage.GardenSpecies`, which `Plots.build` fills through `Models.night` with a `Models.spawn` fallback, held all 26 species: 25 Models with the new MeshIds and TextureIDs, and the hedgehog as a MeshPart (mesh 100166956137262, texture 110536781273370, size 2.4 x 2.8 x 2.63). Sizes match `GardenAssets`. The console showed no `[Models]` warnings.
2. **On pads, the game's path.** A scratch server Script called the game's `Plots.refresh` on display plots 2 and 3 with all 26 species, which runs `makeCreature`, `blenderCreature` and the mesh fallback. Every creature's bounding-box bottom is at Y 0.50 (the pad top), and every one faced the plaza. Screenshots: `01-plot2-lineup-low.jpg`, `02-plot2-13-creatures.jpg`, `03-hedgehog-on-pad-animated.jpg` (taken mid idle turn).
3. **Facing, static lineup.** All 26 were placed with the same calls (`Models.night` at yaw 0, and `Models.spawn` then `CFrame * facing` for the hedgehog) on a platform at Y 200, where CreatureFx does not animate them. They were photographed head-on from -Z, which is the plaza side of a plot. Every face is to the front, every creature is textured, and none is grey. Screenshots: `04-lineup26-half-a.jpg`, `05-lineup26-half-b.jpg`, `06-row1-front-1to7.jpg`, `07-row1-front-7to13.jpg`, `10-row2-front-14to20.jpg`, `11-row2-front-20to26.jpg`. The three that looked turned in the angled shots were checked straight on and face front: `08-turtle-front.jpg`, `12-capybara-front.jpg`, `13-axolotl-front.jpg`.
4. **Hedgehog.** Straight on, it faces front with no 45 degree turn. Its LookVector equals the plot's, and the face, nose and paws are centred: `09-hedgehog-static-front.jpg`.
5. **Mutations.** All 26 were respawned on plots 2 and 3, cycling Golden, Celestial, Moonlit and Rainbow, alongside the display gardens: 31 mutated creatures in all. The result was 0 SelectionBoxes and 23 Highlights. Fills are 0.90, and Celestial read 0.85 and 0.93 mid-pulse. The Golden creatures beyond the 8 reserve got no Highlight and no box. Faces and markings stay readable, and Celestial is not gold: `14-plot2-mutations-no-boxes.jpg`, `15-celestial-frog-closeup.jpg`.
6. **Past the budget.** `HIGHLIGHT_BUDGET` was set to the used count in a client scratch script, then all 26 were respawned mutated. Every one had no Highlight, no box, and its sparkles or particles still on. There were 0 SelectionBoxes in the place. This run also showed the M1 leak (counter 26 against 5 instances).
7. **Aurora egg.** Two Aurora eggs on plot 2 beds (one ripe) each got a Highlight at 0.88, with the egg's stripes and stars clearly visible: `16-aurora-eggs-on-beds.jpg`. They got none before the counter reset, because of M1.

## Not checked

- Whether each remake matches its reference sheet. That is the Director's sign-off; the refcompare sheets are not committed.
- The 6,000-triangle and no-decimation criterion, and front -Y in Blender (Read of task evidence only).
- The upload runs themselves.
- A real owner flow: hatch reveal, ADMIN catalogue previews and the CREATURES panel viewport with the new models and the hedgehog MeshPart.
- Big and other size variants (only `z = normal` was spawned).
- Charm looks (Frosted, Blooming), Stormy flash.
- Two clients, phone, and night or weather lighting.
- A staging build with a CI stamp.

## Fixes (Director, 2026-11-06)

- M1: `CreatureFx.forget` destroys a creature's Highlight and extras when its model is destroyed or leaves Workspace (both the `Destroying` handler and the sweep), so `ClientState.highlights` counts back down. Waiting for a Studio re-check.
- M2: the 26 creature rows in `docs/assets/register.md` now list the new ids (runs 42281587048, 42281598118) and the retired HD ids. The old Blender hedgehog row is marked retired. The hedgehog AI mesh row was added earlier (08df7ab).
- m1: architecture section 6.2 now gives Golden 0.9, Celestial 0.82 to 0.94 with a 0.1 rim, light 0.8, budget 26 and `forget`.
- m2: the Reference log rows say uploaded and signed off. The hedgehog row says its remake is not shipped.
- m3: left as is. `GardenAssets.luau` is generated from the manifest, so it can't carry a comment. The reason the model id is empty is documented in `Models.MESHES.hedgehog` and in the pipeline doc's "Shipped AI meshes" section.
- m4: to check on staging after publish.

## Re-check (A15, 2026-11-06, at `31645fe`)

**Verdict: ship.** M1 is fixed and confirmed in Studio. M2 and m1 are fixed. m2 is fixed except for three rows (n1 below), which do not block.

Tool runs at `31645fe`: lune 578/578 (test-results.json deleted); selene and stylua (LF copy) clean on `CreatureFx.client.luau`; validate-tasks 79 valid; check-scope origin/main all 333 in scope; rojo build + check-place match.

M1, Studio: a fresh local build of `31645fe` (`[Build] dev`), in my own instance (`garden-qa2.rbxl`), closed without saving. A client scratch LocalScript compared `ClientState.highlights` with a live count of Highlight instances every 0.25 s. A scratch server Script called the game's `Plots.refresh` on plots 2 and 3 five times, 3 s apart. Each round shifted the mutations (Golden, Celestial, Moonlit, Rainbow) across all 26 species so every creature was rebuilt, and odd rounds also planted two Aurora eggs.

- **Rounds 3 to 5.** The counter was 26 and there were 26 live Highlights, so the budget was full and none had leaked. No SelectionBox appeared. 21 creatures had a Highlight; the 5 without were Golden creatures held back by the 8-slot reserve. The two Aurora eggs got none: the budget was really full of creature Highlights, which is the designed behaviour.
- **Clearing.** I cleared both plots, then refilled plot 2 with Celestial whale, Golden hedgehog, Moonlit fox and two Aurora eggs. The counter was 10 with 10 live. Each new creature got its Highlight (0.94, 0.90, 0.90), and both Aurora eggs got theirs at 0.88.
- **Clearing plot 2 again.** The counter was 5 with 5 live (the remaining display gardens).

Before the fix, one rebuild left the counter at 26 with 5 live.

M2: all 52 new ids from `GardenAssets` are in the register. The `creature_bunny` row and the others carry the new ids, and the old Blender `creature_hedgehog` row says "Retired 2026-11-06".

m1: architecture 6.2 now matches the code (Golden 0.9, Celestial 0.82 to 0.94 with a 0.1 rim, light 0.8, budget 26, `forget`).

m2: 23 rows updated.

- **n1 (minor, docs only).** The lion, phoenix and axolotl rows in the pipeline Reference log still say "Not uploaded; awaiting Director sign-off". Their sentences start with a capital "Not", so the replacement missed them. All three are uploaded and in game.

m3 and m4: the Director's reasons are accepted. m4 is to be checked on staging.
