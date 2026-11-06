# Egg Garden v0.5 combined release: QA and security review (GARDEN-056)

Reviewer: A15 (did not write GARDEN-050 to 055 or GARDEN-057). Date: 2026-11-06. Branch `garden/v05`, worktree `rad-v05-qa` (detached), reviewed at `7560da3`. Line numbers refer to `7560da3`.

Scope: `git diff garden/v04...garden/v05 -- src tests` (28 files, 5,376 insertions, 2,340 deletions): the login tracks (`LoginRules`, the `GardenConfig` rows, `GardenProgress.login/loginTick/claimLogin`, `sanitize`, `MetaRules` `grant`), the exclusive eggs and six species, the spawn and `play` (`World`, `GardenServer` router, join and `slowTick`, `Plots.gateLook`), the UI kit (`UiKit`, `Menu`, `Hud`, `TradeFx`, `DashFx`, `WheelFx`, `ClientState`), the valley (`World`, `CreatureFx` petals) and the creature HD remake (GARDEN-057: `GardenAssets`, `tools/blender/garden/manifest.json`, `uploaded.json`, the register). Connected code read: `Profiles.luau` (load, apply, flush, request), `src/relay/Models.luau` (`loadNight`, `textureOf`), `Plots.luau` (tags, `GardenSpecies`), `Wheel.leave`, `Dash.place`. v0.4 and Petal Catch were reviewed in `garden-v04-review.md` (re-review "ship"); their code is unchanged by this diff except the UI shells, so it is only re-checked where v0.5 touches it. Checked against decision 0017, GDD X (V for context), `docs/architecture/garden.md` 3.11, 4.7, 6.4, 9.3 and `docs/checkpoints/GARDEN-V05.md`.

Labels: **Computed** came from a script run here against the real pure modules, **Read** from reading the code, **Engineer** from the GARDEN-052/053 task evidence, **Director** from the Director's Studio integration run (combined build, owner account, saving off; no build stamp recorded, so rule 13 is not met for those items). **Nothing was run in a Studio play session by this reviewer.**

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 3 |
| Minor | 10 |

**Verdict: fix first** (no blocker; three small majors, then ship to `garden-staging` for the checkpoint). The owner's hard rules hold through the merge: the trading code is unchanged and the new trade panel sends the same six actions from buttons only; no v0.5 action touches another player; a login claim can never pay a slot twice or past what was earned (Computed, including a write that landed but reported failure); every v0.2, v0.3 and v0.4 save I wrote loads field for field; the exclusive eggs cannot be bought and plant at level 1; nobody is moved at join; no purchase, no countdown and no loss sound was added. The three majors: **M1** an earned but unclaimed Weekly or Monthly Egg disappears at the UTC rollover (the design, but it is a lost reward, and it happens on Sunday afternoon in the Americas); **M2** the kit's 0.5 scale floor puts most text at 8 to 9 pt on a phone; **M3** the stud-sized pad tags (v0.4 m1) cover the screen up close. Director items (a) to (f) are m1, M3, M2, m2, m3, m4.

### Tool runs (local, 2026-11-06, at `7560da3`)

| Command | Result |
|---|---|
| `lune run tests/run` | **571/571 passed**, 0 failed, 0 load errors. `test-results.json` deleted |
| Reviewer script (scratchpad, not committed) against `GardenConfig`, `GardenProgress`, `GardenRules`, `HatchRules`, `LoginRules`, `MetaRules`, `Rng` and Lune's `DateTime` | **171 checks pass**; prints three observations (F3, J1, J2) used in m5, M1 and m6 |
| `python -I docs/game-design/game4-v05-pacing-check.py` | Output equals GDD X4 (66.4 and 2,382.7 coins/s; 9.0 + 7.0 = 16.0 minutes a day; 88.9 against 904; worst 60% bound 56.4%; the 90-day table) |
| `selene src tests` | 0 errors, 0 warnings, 0 parse errors |
| `stylua --check` on LF copies of the 26 changed `.luau` blobs | Clean |
| `rojo build garden.project.json` and `node tools/check-place.mjs` | Builds (66 scripts, stamp `dev`); matches `garden.project.json` |
| `node tools/blender/write-assets-module.mjs garden` run on a scratch copy | `GardenAssets.luau` and `GardenIcons.luau` regenerate byte-identical |
| `node tools/validate-tasks.mjs` | 77 task files valid (re-run after this review's task edit) |
| `node tools/check-scope.mjs origin/main` | All 223 changed files in scope |
| `node tools/check-scope.mjs garden/v04` (the v0.5 delta alone) | One file out of GARDEN-050 to 057's files: see m10 |

## Findings

| Id | Severity | Where | Scenario | Suggested fix |
|---|---|---|---|---|
| M1 | Major | `src/shared/LoginRules.luau:72-77` (reset), `:97` (key check); decision 0017 item 4, GDD X3.1, X3.2, checkpoint item 1 | **Computed (J1, D7) and Read.** A child signs in Wednesday to Sunday and does not open REWARDS. At 00:00 UTC Monday the tick zeroes `weekDays` and `weekClaimed`: the earned Weekly Egg and slots 1 to 4 can never be claimed (`prizeEggs.weekly` stays nil, a claim dated Sunday is refused). The same happens to an unclaimed Monthly Egg on the 1st. A child online across the rollover sees the CLAIM cards vanish (the client hides a stale period at once, `slowTick` resets the server copy within a second); 00:00 UTC Monday is Sunday 16:00 in Los Angeles and 19:00 in New York. It is the documented design, but it is a reward lost (the owner's rule) and a child made sad, and the UI cannot warn without countdown pressure (G4) | Pay at the rollover instead of expiring: in `LoginRules.tick`, before resetting a track whose key changed, pay every earned unclaimed slot of the old period with the `claim` pay code (slots from `slots(track, login[track .. "Last"])`). Still pure and idempotent (a re-run sees the new key); the server can diff the profile and toast "We saved your login rewards". Add spec cases. Put it to SHANNON as the recommendation under checkpoint item 1 |
| M2 | Major | `src/garden-client/UiKit.luau:148` (floor 0.5), `:130`, `:342`, `:644`, `:692`, `:741-748`; `Hud.client.luau:58-64`; `Menu.client.luau:1494` | **Read, Computed, Director (c).** On an 844 x 390 phone (Roblox viewport in points) the kit scale is `clamp(min(0.44, 0.36), 0.5, 1)` = 0.5, so the body text renders at half size: strip captions, card names, card pills and chip lines (18 px) at 9 pt; the XP line, the Index count, badge counts and the REWARDS card captions and pills (16 px) at 8 pt. Only titles (36), the weather name (26), toasts and tabs (22, so 11 pt) reach the 11 pt platform minimum (Apple HIG). "3 more days" and "Weekly Egg" on a reward card are 8 pt. On PC the Director found the XP text and "Index 7 / 108" small too: 16 px, `INK_SOFT` and `LEAF` with a 1 px white outline straight over the world (LEAF is 2.9:1 even on white). The layout itself fits at 0.5 (strip ends at 172 of 390 pt, panel 410 x 280, showcase ends at 348) | On touch, raise text instead of shrinking it: a phone factor (about 1.4) in `UiKit.text` and the fixed `TextSize` sites when the kit scale is under 0.7, with the panel shell sized to the screen (not 820 x 560) so the larger text has room. Move the XP line and the Index count into a CREAM pill under the ring at 20 px INK. Re-check on the Device Emulator at 844 x 390 with the build stamp |
| M3 | Major | `src/garden/Plots.luau:771-778` | **Director (b), Read.** Pad tags are `UDim2.fromScale(6, 1.6)` (v0.4 m1), so they grow without limit as the camera nears: at 6 studs a tag is about 40% of the screen width (70 degree field of view) and the nearest pads' tags overlap each other and the HUD. The player's own garden is where the camera spends most of the session, so every player sees it | Keep the stud size for range but stop the growth up close (`DistanceLowerLimit` about 15; check the exact behaviour in Studio), or return to a pixel size (170 x 46) with `MaxDistance` 25; optionally show line 2 only within 15 studs |
| m1 | Minor | `src/garden-client/Hud.client.luau:101-109`, `:341`; `UiKit.luau:675-693` | **Director (a), Computed.** Chips are white at transparency 0.35 over the world. WCAG contrast of the chip text against that fill over sky, grass and dusk: the Snowfall weekend line (the weather colour pulled 45% to INK) 2.5, 2.2, 1.7; the CORAL restock line 2.1, 1.9, 1.5; the LEAF ripe line 2.4, 2.1, 1.7 (small text needs 4.5). INK reaches 8.7, 7.6, 6.0 | INK text on every chip line, with the colour moved to a small dot at the left; or a less transparent chip (0.1) |
| m2 | Minor | `src/relay/Models.luau:189-199`, `:227`; `tools/blender/garden/uploaded.json` | **Director (d), Read.** What happens when a texture never arrives: every creature's texture id is null in `uploaded.json` (all 26, and 53 of 62 assets), so `textureOf` resolves it at server start with `InsertService:LoadAsset(decal)`, and the built template is cached for the server's life. If that lookup fails, `textureOf` returns nil without a warning and the species is untextured (its imported MeshPart colour, grey) for everyone on that server, the start-menu showcase included (its ViewportFrames clone `GardenSpecies`). If the lookup works but the image is still processing or is rejected, the MeshPart shows its grey base and nothing retries or falls back. **Assumption:** clients that join after processing see the texture; one that saw it grey may keep it until rejoin | Set each loaded creature MeshPart's `Color` to its `FALLBACK` colour (it shows only when the texture is missing), warn when the decal lookup fails and retry it once after about 30 s, and record the image ids in `uploaded.json` so no runtime lookup is needed |
| m3 | Minor | `src/garden-client/CreatureFx.client.luau:207` (Golden `:183`) | **Director (e), Read.** Rainbow and Moonlit draw a `Highlight` over the whole creature with `FillTransparency` 0.6 in a pastel (HSV saturation 0.55, value 1); the fill is unlit, so 40% pastel over the HD texture flattens it to a washed-out, nearly translucent look | Fill 0.85 to 0.9 for Rainbow and Moonlit (about 0.75 for Golden), outline unchanged; re-check against the 26 HD textures |
| m4 | Minor | `src/garden-client/Menu.client.luau:301-303`, `:1473`; `UiKit.luau:840-852` | **Director (f), Read.** Egg cards in REWARDS (and the Dash prize row) use `eggDisc`, a two-colour gradient pill. X1.3 asks for an "egg colour disc", so this is to spec, but it is not the egg's look although `egg_weekly` and `egg_monthly` exist | A `ViewportFrame` of the egg model (the server already warms them in `Plots.build`; publish them in a `GardenEggs` folder as `GardenSpecies` is), the disc as the fallback |
| m5 | Minor | `src/shared/LoginRules.luau:107-131`; `src/garden/Profiles.luau:161-177`; decision 0017 "Why the shape" (c), GDD X3.6, architecture 4.7 | **Computed (F1 to F3).** The docs say a re-applied claim "finds `claimed` already advanced and returns the profile unchanged". That holds for a retried flush and for UpdateAsync re-running its transform (F1, F2), but a claim op that re-runs on a record already holding it (a write that landed but reported failure) pays the **next** earned slot (+150 in F3). Bounded: ten re-runs pay exactly the earned slots, each once; nothing beyond the period, no slot twice | Capture the slot at the request (`n = claimed + 1` on the in-memory profile) and pay only when `claimed == n - 1`; or correct the three documents |
| m6 | Minor | `src/shared/LoginRules.luau:72` | **Computed (J2), Assumption.** The tick resets a track whenever the period key differs, also when it goes back. A claim on server A just after 00:00 UTC Monday, then a join on server B whose clock still says Sunday, then B passing midnight: the week resets twice and slot 1 pays again (+100). Needs server clocks apart by more than a leave and rejoin (with the session lock, seconds); practically nil | Reset only when the new key is greater than the stored one, and count a day only when `today > *Last` |
| m7 | Minor | `src/garden-client/Menu.client.luau:2002-2032`; `src/garden/Profiles.luau:324-340` | **Read.** The `Profile` attribute that enables PLAY is published by the login `apply` before the trade heal finishes and `session.ready` is set; meanwhile the router refuses every request. PLAY in that window (or in the Dash start hold, where `ClientState.racing` is still false but the server refuses `play`) flies the camera to the gate and then hands it back to the character, still on the plaza. Nothing is lost; HOME works | Send `play` first and fly only when it returns true; on false keep the start menu with "Still loading your garden..." |
| m8 | Minor | `src/garden-client/CreatureFx.client.luau:534-605` (match `:594`, `:599`); `src/relay/Models.luau:216-231` | **Read.** `loadNight` keeps the uploaded MeshPart's name, which is the asset name (`parts = { "sakura_large_a" }`), so each large tree is a Model and a MeshPart both named `sakura_large_*`. Both match, so the cap of 12 fills with the first 6 trees at double rate and the other 6 get no petals. Not seen in Studio (GARDEN-053's build had no sakura models) | Register only `Model`s (`tree:IsA("Model")`) |
| m9 | Minor | `tools/blender/garden/manifest.json` (`tris_budget` 6000); `docs/architecture/garden.md:1080`, `:1107`, `:1117` | **Computed.** The HD creatures are 5,430 to 5,978 tris (were 2,048 to 2,425 at budget 2,500); 9.1 and 9.3 still say a 3,000 budget and "120 creatures on screen", and 9.3 says the otter is 3.6 tall (the manifest's is 2.6, on its back). Six full pens are about 700,000 creature triangles plus followers. **Assumption:** Roblox's automatic mesh LOD carries the distant ones | Record 6,000 and the otter height in 9.1 and 9.3; check frame time on a low-end phone with six full pens at the greybox gate |
| m10 | Minor, process | `studio/tasks/GARDEN-055.json`, `GARDEN-054.json` | **Computed.** `check-scope garden/v04` flags `tools/blender/write-assets-module.mjs` (changed by GARDEN-055 in `c35715d`, not in its `files`; the check against origin/main passes only because GARDEN-031 and 044 list it). GARDEN-054 and 055 are still `planned` while their uploads are merged and in game (their register rows exist) | Add the file to GARDEN-055's `files`; move 054 and 055 to `in_review` with their upload evidence |

## Verified clean

### The owner's hard rules after the merge (Read unless marked)

| Check | Result | Evidence |
|---|---|---|
| Trading unchanged and still safe | Pass | `TradeRules.luau` and `Trades.luau` are not in the v0.5 diff; the v0.4 trade specs pass (571). The rebuilt `TradeFx` sends only `tradeAccept`, `tradeCancel`, `tradeConfirm`, `tradePick`, `tradeEmote`, `tradeUndo`, each from a button (`TradeFx.client.luau:289-311`, `:425-455`); the player closing the panel (X, Escape, B) is CANCEL (`:361-366`); another panel replacing it sends nothing, so the trade times out with nothing changed |
| No stealing | Pass | No v0.5 action reads or writes another player's profile; `play` and `home` move only the caller to the caller's own gate (`GardenServer.server.luau:343-361`) |
| No duplicate or loss from v0.5 code | Pass, see M1, m5, m6 | Claims bounded by the earned slots (Computed F1 to F3); the tick idempotent (D1, D2); old saves keep every field (I1 to I5); `prizeEggs` keeps `weekly` and `monthly`; the rollback loss is documented in 0017 |
| Exclusives traded only under V1 | Pass | Value by `rate` like any species; checkpoint item 5 |
| G4: no purchase | Pass | No `MarketplaceService` or product call in `src/garden`, `src/garden-client` or `src/shared` |
| G4: no countdown pressure, no "limited" copy | Pass | REWARDS shows "Week of Monday 2 Nov · signed in 3 days", "N more days" pills and "Any 5 days count" (`Menu.client.luau:1448-1460`, `:1521`); one "Login reward ready!" toast at join; no pressure words in the client. The HUD's weather and restock timers are v0.1 to v0.4 content, unchanged |
| G4: no loss sounds | Pass | New sounds are the tick, chime, fanfare and whoosh on positive actions; refusals show a toast only |

### Login rewards (Computed unless marked)

| Check | Result | Evidence |
|---|---|---|
| Config equals decision 0017 | Pass | 26 species in X3.4 order (each exclusive after the named species, cry nil); 10 eggs, `aurora` last sold, `weekly` then `monthly` with grow, odds (sum 10,000), top, meter, XP, no price or stock, level 1; `INDEX_SIZE` 108 equals the counted indexable pairs; `LOGIN` both tracks slot by slot; five `grant = "login"` cosmetics with no price, level or index; `isPrizeable` |
| No sold egg hatches an exclusive | Pass | 4,900,070 seeded `rollSpecies` over the sold eggs in all 7 weathers: 0 exclusives; no sold egg's odds or `top` names one; the Weekly and Monthly Eggs hatch only their three, each within 5% of its bp over 100,000 rolls |
| Distinct UTC days; Monday week; calendar month; month length | Pass | `monthOf` key and length against `DateTime` for every day 1970 to 2100, and `weekOf` changing exactly on Mondays: 0 mismatches; February 2026 last slot 28, February 2024 29, April, November, December 30; `slots` does not mutate `LOGIN` |
| Counting | Pass | Two joins and a tick on one day count 1; a tick twice on the next day counts it once (rollover while online); Monday resets the week and keeps the month; 1 December resets the month and keeps the week |
| Claims once and in order; refusals | Pass | Four earned slots claimable, the fifth refused; a full week pays seven slots, the egg once and both cosmetics; an eighth refused; a second week pays coins only in the cosmetic slots; February with 28 sign-ins completes the month, April with 29 stops at six; a bad track (`day`, empty, `weekClaimed`) is refused by `canClaim`, and the router allows only `week` or `month` (`GardenServer.server.luau:339-342`) |
| Idempotent on flush re-apply | Pass, see m5 | A retried flush pays once (F1); the transform re-run is deterministic (F2); a claim and the midnight tick in one flush apply in queue order (F4, F5) |
| Rollover while online and at join | Pass | `slowTick` re-ticks a profile whose `weekLast` or `monthLast` is not today (`GardenServer.server.luau:558-571`); `Profiles.get` hides the profile until the load is done, so the tick queues behind the login op; a load that spans midnight counts both days (intended, garden.md 4.7) |
| Unclaimed slots expire | As designed: see M1 | |
| Exclusive eggs: not buyable, plant at level 1 | Pass | `buyEgg weekly` and `monthly` refused with 1e12 coins; `plantPrize` plants each at level 1 with a 1 h and 4 h grow; the Moon prize still waits for its level; the starter is never prizeable; the real hatch path rolls only the egg's three species with weather mutations and adds the Index cell |
| Login cosmetics | Pass | `buyCosmetic` refuses all five; locked and not equippable until owned; owned and equipped survives `sanitize`; a forged equip without ownership falls back to the default |
| Schema v3 keeps every v0.2, v0.3 and v0.4 save (the check asked for) | Pass | My own literal records (Celestial, Star, Moon, Aurora, meadow and starter beds; Celestial Phoenix, Rainbow Lion, Golden Axolotl, Moonlit Kirin, a stored duck, a Frosted Moth; seven pity keys; prize eggs including Aurora; owned and equipped Candy fence; daily streak 4 and a claimed weekly bonus; quests in progress; dash; for v0.4 a trade, today's trade count, milestone 20, two wheel spins): after `sanitize` every field is equal, with only `login`, `pity.weekly`, `pity.monthly` (and for v2 the three creature fields and the v3 defaults) added; the input is untouched; `sanitize` is a fixed point; a v0.5 record round-trips. My first literals had three out-of-range values that the existing clamps corrected (a Moon bed ready past its grow, `dash.coins` over its cap, a "tiny" size); they were fixed in the script, not in the code |
| `claimDaily` and `claimWeekly` refused without breaking old saves | Pass (Read; Engineer) | Neither is in `REQUEST_ARGS` (`play` and `claimLogin` replaced them, `GardenServer.server.luau:66-67`), so the router refuses them before any profile work; neither is in `Profiles` `ACTIONS`; the `daily` and `week` fields stay in the save and `MetaRules.login` still ticks them (Computed I4). Engineer Studio: both false |

### Spawn and `play` (Read; Engineer for the moves)

| Check | Result | Evidence |
|---|---|---|
| Nobody at the gate at join | Pass | `World.build` moves the place file's `SpawnLocation` first, before anything yields (`World.luau:965-978`, `:1070`); it is the only `SpawnLocation`; `Neutral`, `Duration 0`, invisible, non-colliding, facing the tree; at (21, 0.3, 28), inside X2's 6-stud allowance (recorded deviation). No `toGate` at join (`GardenServer.server.luau:689`); `CharacterAdded` only re-places a racer (`:670-680`). Engineer: spawned at (19.9, 4.0, 25.7) facing the tree; Director: spawned on the plaza pad |
| `play` rate-limited and checked | Pass | Loaded session and plot, string action, no argument (`REQUEST_ARGS.play = false`), the shared 0.35 s limit (`admit`); Engineer: a second `play` within 0.35 s false, `play x` false |
| A racer or a Petal Catch player pressing PLAY | Pass | Refused while racing, the start hold included; the client skips the request and the fly while racing (`Menu.client.luau:2022`), and a round start closes the menu. A Petal Catch round is dropped by `Wheel.leave` with no grant, as HOME did in v0.4 |
| HOME still works | Pass | Unchanged path (Dash leave, Wheel leave, `toGate`); Engineer: `home` true; Director: PLAY to the gate worked |

### UI kit, Menu and Hud (Read)

| Check | Result | Evidence |
|---|---|---|
| No widget sends a Request | Pass | `UiKit.luau` has no `Request`, `InvokeServer` or `FireServer` |
| Same requests as v0.4 | Pass | Every `ask` in Menu, Hud, TradeFx, WheelFx and DashFx, v0.4 against v0.5: identical except `claimDaily` and `claimWeekly` gone and `claimLogin` and `play` added (0017's table) |
| Only GardenIcons images and ViewportFrames | Pass | The only new image is `UiKit.icon` (`rbxthumb://type=Asset` of a `GardenIcons` id, glyph until loaded); creatures and showcase cards are `ViewportFrame`s |
| Reduced Motion | Pass for v0.5 code | Every tween in `UiKit` goes through `tween()` or checks `still()`; `flyTo` is instant; Menu (`:1509`) and DashFx (`:650`) check it. WheelFx's v0.4 "+1" float and fades do not (pre-existing) |
| One panel at a time; modals; Escape and B | Pass | `UiKit.panel` closes the current one (module state shared by Menu and TradeFx); modals stack over it; Escape and B close the top one; bumpers change tabs only with no modal open |
| Gamepad | Pass (Read only) | Panel bodies and the strip are `SelectionGroup`s; `selectFirst` on open; one shared GOLD selector |
| Phone layout | Fits; legibility is M2 | At scale 0.5: touch strip 2 rows ending at 172 of 390 pt; MORE sheet for the rest; panels 410 x 280; the start menu's showcase ends at 348 |
| Every v0.4 panel reachable | Pass | EGGS + ODDS, INDEX GRID + MILESTONES (`claimMilestone`), CREATURES PEN / STORAGE / TRADES (NAME modal, trade list with UNDO), LOCKER, REWARDS, STATS, DASH with the prize eggs (Weekly and Monthly included, PLANT), PATCH, SETTINGS + HOW TO PLAY, ADMIN (strip button for `ADMINS` only; the server gate is unchanged), the trade panel from the TRADE button. Engineer saw each in Studio |

### Valley (Engineer at stamp `dev`, and Read)

| Check | Result | Evidence |
|---|---|---|
| Part budget | Pass | 3,947 parts at build, 4,036 with a loaded plot, against 7,500; `World.build` sets `Parts` and warns over budget |
| Moonfall lights | Pass | Lanterns go through `lamp()` into `lamps` (`World.luau:110-119`); Engineer: 38 of 38 valley `PointLight`s on at Moonfall, none casting shadows, 0 otherwise |
| Emitter caps | Pass on the cap, see m8 | At most 12 client emitters, rate 3, enabled within 60 studs of the camera; none on the server |
| Fixed positions | Pass | The diff moves no cart, board, Petal Patch or Splash Island coordinate; meadows now also avoid the Patch and the pond |

### Creature HD (Computed)

| Check | Result | Evidence |
|---|---|---|
| `GardenAssets` ids and sizes match the manifest | Pass | Regenerated byte-identical from `manifest.json` and `uploaded.json` (also `GardenIcons`) |
| 26 creature rows complete | Pass | Every `creature_<id>` has a model and a decal id; measured heights equal the targets (otter 2.62 against 2.6); all under the 6,000 budget (see m9) |
| Register rows | Pass | Every v0.5 id (26 creatures, two eggs, three sakura, three hills, lantern, spawn pad, 16 icons) has a row: 140 of the 148 uploaded ids; the 8 without one are the v0.3 egg texture image ids, whose decals have rows (pre-existing) |

## GARDEN-056 acceptance

| Criterion | Status |
|---|---|
| Review in the v0.4 format with labelled findings | Done, this file |
| Login tracks tried with a fake store and a moved clock, build stamp | **Partly.** Every listed case was run on the real pure modules with moved clocks and the flush semantics (Computed); the Studio run with a fake store was not done here. Engineer (GARDEN-052, stamp `dev`): rollover +1 day, a Monday reset keeping the month, claims paid once, a Weekly Egg planted at level 1. Director: weekly claim once, `claimDaily` refused |
| Config equals 0017 by script; 100,000 seeded rolls; v3 save without `login`; `claimDaily` and `claimWeekly` refused | Done (Computed; the last by Read and Engineer) |
| Spawn and PLAY from two clients; respawn; valley screenshots with `Parts` under 7,500 | **Partly.** Read plus the Engineer's and Director's single-client runs; two clients not tried |
| UI: same requests as v0.4 (script grep); phone and gamepad screenshots; Reduced Motion | Request grep done; phone judged by arithmetic (M2); gamepad and Reduced Motion by Read only |
| The checkpoint doc lists the evidence | **Open.** `GARDEN-V05.md` still says "pending"; fill it after M1 to M3 with the CI run, the build stamp and the recordings. This review's tool runs and the pacing output above can go in as they are |

## Not checked

- Anything live: a Studio play session, two clients, a forced flush failure, a real phone or the Device Emulator, a gamepad, Reduced Motion switched on, the petal emitters, the 1.6 s fly.
- Performance of the HD creatures and the valley on a low-end phone (m9).
- Whether a texture that finished processing later appears for a client that already saw it grey (m2, Assumption).
- The art itself beyond the Director's notes, and the pacing script's simulation logic (its output was compared, not audited).
- The Director's items carry no build stamp (rule 13).
