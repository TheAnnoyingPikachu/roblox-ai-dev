# Egg Garden v0.3: QA and security review (GARDEN-026)

Reviewer: A15 (did not write GARDEN-022 to GARDEN-025). Date: 2026-11-01. Branch `garden/creatures`, worktree `rad-creatures`, reviewed at `1b4f88c` against `origin/main` (`f677b1c`). Line numbers refer to `1b4f88c`.

Scope: `git diff origin/main...HEAD -- src tests` (13 files, 774 insertions) and the connected code: `src/shared/{GardenConfig,HatchRules,GardenRules,GardenProgress,GardenAssets}.luau`, `src/garden/{Plots,World,GardenServer.server}.luau`, `src/relay/Models.luau`, `src/garden-client/{ClientState,CreatureFx,HatchFx,Hud,Menu}.client.luau`, the four changed specs, `docs/assets/register.md`, `tools/blender/garden/manifest.json`. Checked against decision 0014, GDD section U, `docs/architecture/garden.md` 3.2, 6.1, 6.2, 9.1 and `docs/checkpoints/GARDEN-V03.md`.

This is a code review with a scripted check against the real pure modules. **Nothing was run in Studio by this reviewer**, and no Studio run is needed for the verdict below; the Studio facts quoted are GARDEN-023's and GARDEN-025's notes, all at build `dev` (rule 13 not met). Labels: **Computed** came from a script run here, **Read** from reading the code, **Engineer** from the task notes.

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 0 |
| Minor | 6 |

**Verdict: ship** (to staging, for the checkpoint). Every economy value in `GardenConfig` equals decision 0014, old saves pass `sanitize` unchanged, the rules accept exactly the 80 pairs, the client never repaints a creature, and the cries are gated by the `sfx` setting and backed by register rows from the two licensed partners. The six minors are a missing spec check, two small client timing edges (one pre-existing), two document rows and one art gap; none changes a player outcome. The checkpoint itself is not ready to put to SHANNON until `docs/checkpoints/GARDEN-V03.md` carries the evidence block (see acceptance).

### Tool runs (local, 2026-11-01, at `1b4f88c`)

| Command | Result |
|---|---|
| `lune run tests/run` | **480/480 passed**, 0 failed, 0 load errors. `test-results.json` deleted |
| Reviewer script against `GardenConfig`, `HatchRules`, `GardenRules`, `GardenProgress` (scratchpad, not committed) | **378 checks pass**, 1 expected mismatch (m4: the documents' Aurora return row, not the code) |
| `python docs/game-design/game4-v03-pacing-check.py` | Part 1 table reproduces U6 for every egg; Aurora prints 0.0% at the script's precision |
| `selene src tests` | 0 errors, 0 warnings, 0 parse errors |
| `stylua --check` on the 13 changed `.luau` git blobs (LF) | Clean |
| `rojo build garden.project.json` and `node tools/check-place.mjs` | Builds; matches `garden.project.json` |
| `node tools/validate-tasks.mjs` | 56 task files valid (re-run after this review's edit to GARDEN-026) |
| `node tools/check-scope.mjs origin/main` | Tasks GARDEN-022 to 026; all 68 changed files in scope |

## Findings

| Id | Severity | Where | Scenario | Suggested fix |
|---|---|---|---|---|
| m1 | Minor | `tests/GardenAssets.spec.luau:54-85`; `src/shared/GardenAssets.luau` (`creature_hedgehog` size 2.73, 2.72, 3.61; `creature_kirin` 3.75, 6.25, 4.74) | Architecture 9.1 and GARDEN-023's first acceptance criterion say the spec "must also check every `creature_*` height is within 2.8 to 6 and x, z within 6". The spec pins sizes to the manifest and bands only eggs and dash models. **Computed:** 2 of 19 are outside the band, hedgehog 2.72 (3% under) and kirin 6.25 (4% over); every footprint is within 6 (dragon x is exactly 6.0, so a Huge is 12.0 wide). Against the manifest's own `target_size_studs`, five models differ by more than 10% on an axis: unicorn x 2.26 vs 4 (−43%) and z −19%, kirin x −18%, deer z +11%, panda z +11%, axolotl z +11%. Visual only; nothing keys on the mesh size | Add the band check to the spec as 9.1 words it; either widen the band to 2.7 to 6.3 in 9.1 or rescale the two models. The target drift is the artists' call, note it in `garden-blender-plan.md` |
| m2 | Minor | `src/garden-client/CreatureFx.client.luau:214-218`, `:185-187` | **Read:** `DescendantAdded` only tracks an instance whose parent is `Creatures`; a late MeshPart's own event is ignored because its parent is the Model. If the MeshPart replicates after the deferred `track` (the engineer saw the Model arrive first in Studio, and `task.defer` fixed it there), `track` returns and only the 0.5 Hz sweep picks the creature up. A fresh hatch of a Model creature could then be visible for up to 0.5 s before the reveal hides it. Likely rare (a one-MeshPart Model replicates in one batch) and self-healing | In the `DescendantAdded` handler also accept `inst:IsA("BasePart") and inst.Parent.Parent and inst.Parent.Parent.Name == "Creatures"` and defer `track(inst.Parent)` |
| m3 | Minor, pre-existing | `src/garden-client/CreatureFx.client.luau:259-261` (also at `origin/main` `:246`) | **Read:** `(view.look :: any).Enabled = not hidden` runs for the `SelectionBox` fallback too; `SelectionBox` has `Visible`, not `Enabled`, so the assignment errors once per hide and unhide of a mutated creature past the Highlight budget, and that frame's loop stops for the views after it. Reachable only with more than 26 looks on screen during a reveal; one console error and one skipped frame | `if view.look:IsA("Highlight") then view.look.Enabled = not hidden else view.look.Visible = not hidden end` |
| m4 | Minor, documents | `docs/game-design/game4-gdd.md:785,814`, `docs/decisions/0014-garden-creatures-v03.md:43,81`; GDD U1 `:717,721,729` | **Computed:** the Aurora return on buy, hatch, release is 0.00067% in Clear and 0.00128% in Rainbow Shower (bound 0.0014%), not "0.0008% / 0.0008%": an egg that rolls its mutation from the weather cannot return the same in both. The committed script prints 0.0% at its precision, so the digits were hand-derived. The spec's pinned "0.0 0.0" is right. Also GDD U1's cry column still says duck and owl are "to find" and the dragon uses 9116311855 at 0.8, while `GardenConfig` and the register have duck 1840105521 at 1.2, owl 9117181540 at 1.0 and dragon 9125470864 at 0.9 (U10 and the register are correct) | Correct the two tables; no code change |
| m5 | Minor, art | `tools/blender/garden/manifest.json` (no `egg_aurora`), `src/garden/World.luau:310`, `src/garden/Plots.luau:102-108` | **Read:** the seven older eggs load Blender models through `Plots.eggModel`; the Aurora has no manifest entry, so the 5,000,000,000 coin egg is the only part-built egg on the cart and in beds. Intended for v0.3 (U10 says "teal-violet shell"), but it will read as the unfinished one next to seven modelled eggs | A follow-up asset task for `egg_aurora` (the egg contract in section 9 already covers it); nothing in code changes |
| m6 | Minor, pre-existing | `src/garden-client/HatchFx.client.luau:578-586` | **Read:** `runOff` clones the pad creature with its client-side look, so a released Golden or Celestial carries a second `Highlight` for up to 7 s that the `highlights` counter never sees. A release spree on a full mutated garden can push the real count past Roblox's limit briefly; the pad's own Highlight is freed when the server's destroy replicates | Destroy any `Highlight` or `SelectionBox` in the copy before parenting it, or set it `Enabled = false` |

## Verified clean

### Economy and rules (Computed unless marked)

| Check | Result | Evidence |
|---|---|---|
| Every egg's odds sum to 10,000, name only real species, list each once | Pass | All 8 eggs; script |
| Odds, top and meter equal decision 0014 for all 7 sold eggs, outcome for outcome | Pass | Script against the 0014 table typed in verbatim; `src/shared/GardenConfig.luau:116-234` |
| `top` is the rarest species of each egg | Pass | Rarity index of `top` is the maximum over the egg's odds, every sold egg |
| Aurora: price 5,000,000,000, grow 43,200, level 32, stock 3% min 1 max 1, XP 3,000, no fixed mutation; last in `EGGS`, stock index 7, older eggs in their old positions | Pass | `GardenConfig.luau:221-233`; `EGGS[1..7]` are starter, meadow, forest, sunset, moon, star, celestial |
| Celestial Egg unchanged except odds; odds are exactly the Legendary and Mythic species | Pass | Price, grow, level, stock 5, XP, `mutation = "celestial"`; set equality with `SPECIES` by rarity |
| Species rates equal U1 for all 19 | Pass | Script |
| `rarityIndex` of the nine old species unchanged (1,1,2,2,3,3,4,5,6); divine 7, secret 8 | Pass | `RARITIES` appended only (`GardenConfig.luau:283-284`); `HatchRules` LEGENDARY 5 and `RARE` 3 untouched |
| Lucky Meter forces the stated top at `pity = meter - 1` and not at `meter - 2`, every egg | Pass | `HatchRules.luau:41-43`, 50 seeds each |
| `INDEX_SIZE` 80 equals the count of `indexable` pairs | Pass | 76 weather pairs + lion, unicorn, dragon, phoenix `:celestial`; `GardenConfig.luau:346,562-568` |
| `GardenRules.grant` accepts every indexable pair and refuses every other (76 × 4 + 4 checked, plus `kirin:celestial`, `whale:celestial`) | Pass | `GardenRules.luau:174-175`; `adminGrant` is unchanged and goes through `grant`, so non-admins are still refused in the router (`src/garden/CLAUDE.md`) |
| 60% rule by the spec's bound, 28 egg-weather pairs | Pass | Worst Meadow in Rainbow Shower 56.41% bounded, 54.16% exact; my recomputation reproduces U6's digits for meadow, forest, sunset, moon, star and celestial exactly (see m4 for aurora) |
| `announce` for Divine and Secret, not Epic | Pass | `HatchRules.luau:136-138` |
| `sanitize` keeps a v0.2 save unchanged | Pass | My own literal v2 record (6 creatures with Celestial lion and dragon, Celestial and Star in beds, 6 pity keys, 7 Index keys, stock, cosmetics, quests, prizes, dash): every field equal after `sanitize`, the only addition `pity.aurora = 0`, no `stock.bought.aurora` key added; the spec's own record (`tests/GardenProgress.spec.luau:607-617`) agrees |
| `sanitize` accepts new species, the Aurora in a bed, `pity.aurora`, `stock.bought.aurora`, `phoenix:celestial` | Pass | Unchanged through `sanitize`; `whale:celestial` and a `kirin:celestial` creature are dropped, `pity.aurora` clamps to 20 and stock to 1 (spec `:619-643`) |
| Every cry: positive whole id, pitch 0.5 to 2, all 19 present | Pass | Script; spec `tests/GardenConfig.spec.luau` "gives every cry present..." |
| No new remote, Fx kind, status field or attribute | Pass (Read) | `GardenServer.server.luau` unchanged; `Remotes.fx("collect", { owner, pad, amount })` as before; `Pad`, `Hatched`, `Id`, `S`, `M`, `Z` as before; the Admin tap calls `ClientState.cry` only |

### Server (Read)

| Check | Result | Evidence |
|---|---|---|
| `Plots.makeCreature`: all three paths set `Name`, `Id`, `S`, `M`, `Z`, `Pad`, `Hatched` on the returned instance and carry a `Tag` BillboardGui | Pass | `Plots.luau:744-774`; `tag` on the MeshPart (`:740`), the mesh (`:759`) and the fallback's `PrimaryPart` (`:763`) |
| Non-colliding, anchored parts | Pass | Blender: `loadNight` anchors (`Models.luau:217`) and `Models.ghost` clears collide, query, touch (`:332-340`); mesh: `CanCollide`/`CanTouch` false (`Plots.luau:757-758`, `CanQuery` left true as in v0.2); fallback: `decor` (`:242-249`) |
| `Plots.refresh` never yields | Pass | The Blender path runs only when `Models.nightReady` (`:751`), which is true only once `nightTemplates[name]` is set, and `nightLoading` is cleared in the same step with no yield between (`Models.luau:237-238`), so `loadNight`'s wait loop is never entered; `Models.spawn` is guarded by `warmed` as before |
| A creature built before its model loaded is rebuilt | Pass | `creatureKey` includes `n`/`w` (`:778-781`); live plots refresh at 1 Hz (`GardenServer.server.luau:402`), showcase plots after the warm-up (`Plots.luau:1012-1016`) |
| Warm-up cannot throw or leave `GardenSpecies` half-filled | Pass | `Models.night` and `Models.spawn` wrap their loads in `pcall` and return nil (`Models.luau:141,210`); each species falls through Model, mesh, nothing; the folder is parented only after the loop (`Plots.luau:1007`); `preloadGarden` runs first (`GardenServer.server.luau:63`) so the loop only waits on loads already in flight |
| `Models.night` scale against `SIZES` | Pass | Template fitted to the manifest height (`Models.luau:228-229`), copy `ScaleTo(scale)` with scale 1.0 / 1.4 / 2.0 (`GardenConfig.luau:297-301`), stood on the pad by `Models.place`; tag height from `GetExtentsSize().Y` after scaling |
| Leftover 9-species, 6-rarity, 7-egg assumptions in `src/garden`, `src/garden-client`, `src/shared` | None | grep for `38`, `mythic`, `dragon`, `lion`, hard-coded egg lists: only the showcase gardens (`Plots.luau:935-947`, display data), the cart list which now has 7 (`World.luau:310`, pedestals at x ±7.8 on an 18-wide cart), pixel offsets, and the `RARITIES` table itself |

### Client (Read)

| Check | Result | Evidence |
|---|---|---|
| `CreatureFx` never writes `TextureID`, `Color` or `Material` | Pass | `applyLook` creates only `Highlight`/`SelectionBox`, `Sparkles`, emitters, a `PointLight` and the halo (`CreatureFx.client.luau:145-177`); the frame loop writes `LocalTransparencyModifier`, Highlight and SelectionBox colours and transparencies only (`:253-285`); no `Foil` anywhere in the file |
| Celestial and Golden per 6.2 | Pass | Golden fill (255,200,60) 0.5, outline (255,230,140) 0.3, Occluded, `need` 8 (`:151-155`); Celestial fill `CELESTIAL` outline 0.2, pulse `0.575 + 0.125 sin(2πt/2.4)` on Highlight fill or SelectionBox transparency (`:271-284`), halo, stars rate 7 lifetime 2.2-3.6 speed 0.3-0.8 size 0.5→0, PointLight 14 / 1.4 (`:161-171`) |
| Highlight budget accounting | Pass | `+1` only when a Highlight is created, `-1` on its `Destroying` (`:115-128`); extras never counted; `need` makes Golden stop at 18 and the rest at 26; a Highlight on a creature destroyed by the server dies with it (as in v0.2) |
| Deferred Model tracking: Model destroyed before its parts arrive; `views` leaks | Pass, see m2 | `track` records nothing while `#parts == 0` (`:185-187`); `Destroying:Once` and the 0.5 Hz `IsDescendantOf(Workspace)` sweep clear `views` (`:206-208`, `:232-236`) |
| Idle cry scheduler | Pass | 1 Hz loop; first and later delays `12 + random() * 18` (`:202`, `:315`); garden-wide `lastCry` 2 s gap (`:317`); hidden skipped (`:318`); 60 studs from `camera.CFrame.Position` (`:319`); out of range redraws without queueing; `sfx` off returns before any instance is made (`ClientState.luau:331-333`) |
| No sound instance leak | Pass | One `Sound`, 3D ones in an `Attachment` under `Terrain`; `done` destroys the holder on `Ended` and after 8 s (`ClientState.luau:348-355`); the longest clip is the owl at 5.5 s at pitch 1.0 |
| Cry on reveal, owner 0.5 / others 0.25, both hatch speeds, never on a refusal | Pass | One line after the pop, shared by the 1.5 s and 0.4 s paths (`HatchFx.client.luau:446`); the reveal only runs on the `hatch` Fx (`:605-606`) |
| Banking cry, owner only, 0.2, species from the pad's `S` | Pass | `coinPop` under `if mine` (`:489-499`), matches `Pad` to `data.pad`, silent when no model is on the pad |
| Admin tap 2D 0.5, owner's panel only | Pass | `Menu.client.luau:752-762`; the ADMIN panel is gated as in 0013 |
| `ClientState.cry` is the one formatter | Pass | `rbxassetid://{id}` and `pitch` only here (`ClientState.luau:360-367`); unknown or cry-less species are silent, no log |
| Admin `ViewportFrame` with Models | Pass | Bounding box centred on the origin for Model or part (`Menu.client.luau:724-730`), camera at `size.Magnitude * 2` with FOV 30: a 6-stud model has a half-height of 3 against about 4.3 visible at that range |
| Index: 80 cells, phone width | Pass | Cells `1 / #kinds` wide (`:662`) with 6 px padding; five cells on the four Celestial species, four elsewhere; text as in the v0.2 close of m7 |
| Secret colour as text | Pass | Pad tag: pale stroke (235,230,255) at 0.2 (`Plots.luau:703-708`, the `UIStroke` always exists, `:272`); HatchFx card: Secret on `CREAM` (`HatchFx.client.luau:158-165`); Hud banner: white on the Secret fill (`Hud.client.luau:463-467`); Menu Index, Creatures, Admin and Odds rows: Secret on white `CARD`. Divine aqua as text on white is about 1.5:1, the same as the existing Legendary gold; not new |
| Aurora in every egg-keyed table | Pass | `ClientState.EGG_COLOURS` (`:287`), `Plots.EGG_LOOKS` (`:102`) and the sparkle branch (`:331`), cart pedestals (`World.luau:310`), HatchFx reads `EGG_COLOURS` and `lastEgg`, ODDS card and EGGS panel loop `EGGS` (`Menu.client.luau:521`, `:440`) |

### Assets

| Check | Result | Evidence |
|---|---|---|
| Every cry id in `GardenConfig` has a register row | Pass (Computed) | 18 distinct ids, 18 "Garden cry" rows (`docs/assets/register.md:55-72`); the cat shares the bunny's row, which names both |
| Every cry row is ProSoundEffects or APMOfficial | Pass (Read) | 16 PSE, 2 APM (duck 1840105521, kirin 1846547135). Not checked: the Creator Store listings themselves |
| 19 `creature_<id>` model rows | Pass | `register.md:170-188`, studio-owned, model and decal ids matching `GardenAssets` |
| `GardenAssets` ids positive integers, one part named after the asset | Pass (Computed) | 19 rows; spec `tests/GardenAssets.spec.luau:41` |
| Sizes within 10% of the U9 band | Pass with m1 | Heights 2.72 to 6.25, all within 4% of the band edges; footprints at most 6.0 |

## GARDEN-026 acceptance

| Criterion | Status |
|---|---|
| Review in the v0.2 format with labelled findings | Done, this file |
| `GardenConfig` equals 0014 by script; every egg under 60% by the spec's bound | Done (Computed) |
| Pre-0014 save loads unchanged; new species survive; no new remote, Fx, attribute; `adminGrant` refuses non-admins for new ids | Done (Computed and Read) |
| Cries obey `sfx`, never on a refusal, licensed rows; no repaint | Done (Read) |
| Checkpoint doc lists the evidence: CI run link, test counts, build stamp, three-Lions screenshot, cry recording | **Open.** `docs/checkpoints/GARDEN-V03.md` has the 11 decisions and no evidence block. GARDEN-025's Studio notes are at build `dev` (rule 13), its screenshot and the recording are not linked, and no CI run is linked. Add the block after the PR's CI run, then put the checkpoint to SHANNON once |

## Not checked

- Anything live: replication order of a Model and its MeshPart (m2), whether `Destroying` fires on the client for every server destroy (the budget relies on it, as in v0.2), the `SelectionBox` property (m3), real text contrast on a phone, cry volumes and pitches by ear, the Celestial look at pad distance (the greybox gate's screenshot).
- The Creator Store listings behind the 18 cry rows and the 19 uploaded models; the register is taken at its word.
- The pacing simulation's player model (Part 2 of the script): run, not audited.
- Splash Dash, weather, cosmetics, quests and `Profiles`: unchanged by the diff and not re-read.

## Fixes after the review (Director, 2026-11-01)

- m4: Aurora return digits corrected in GDD U6 and decision 0014; U1 cry column updated for duck, owl and dragon (commit 6dcd90f).
- m5: `egg_aurora` Blender model built, uploaded (run 41363287252) and registered; `Plots.egg` picks it up through `GardenAssets` like the other eggs.
- m1, m2, m3, m6: left as noted, conservative choice; m3 and m6 predate v0.3.
