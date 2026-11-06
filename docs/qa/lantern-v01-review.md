# Lantern Express v0.1: QA and security review (LANTERN-013)

Reviewer: A15, the independent QA thread (CLAUDE.md rule 2; did not write LANTERN-003 to 012 or 015). Date: 2026-11-06. Branch `game6/concept`, worktree `rad-lqa` (detached), reviewed at `ed1ef49`. Line numbers refer to `ed1ef49`. Code was read only; this review changes no code.

Scope: the pure modules (`LanternConfig`, `TrainRules`, `CarryRules`, `WispRules`, `LootRules`, `TrackRules`, `DepotRules`, `LanternProgress`, `LanternIcons`), the server (`src/lantern/**`), the client (`src/lantern-client/**`), the kit pieces Lantern added or changed (`src/kit/SaveStore.luau` `newer`, `src/kit-roblox/modules/Saves.luau`, `src/kit-roblox/modules/UiKit.luau`, now shared with Egg Garden), against decision 0018 and amendment 1, GDD sections A to S, architecture `lantern.md`, art bible section 3, `docs/checkpoints/LANTERN-V01.md`, the LANTERN task evidence and the studio lessons.

Labels: **Computed** came from a script run here against the real pure modules (the TrainRules state machine, LanternProgress, LootRules, WispRules, SaveStore with `tests/fakes/DataStore.luau`); **Read** from reading the code; **Engineer** from the task evidence (LANTERN-006, 007, 012, 015, with their build stamps). **Nothing was run in a Studio play session by this reviewer**, so no item here meets rule 13; the two-client, phone and DataStore checks stay open (see Not checked).

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 5 |
| Minor | 14 |

**Verdict: fix first** (no blocker; four small code majors and one doc major, then ship to `lantern-staging` for the checkpoint). The owner's hard rules hold in the code: nobody can take a carried item or a crate from its carrier, a helper never keeps a crate, rewards go only to each player's own save; there is no combat, no purchase, no paid roll, no text input, no countdown on any offer, and pings and announcements are fixed phrases with display names; the Lampeater only appears on leg 3 (after the first Depot) with a 3 s warning. Every load is paid the moment it lands, so ending by coal, by lantern, by leaving or by shutdown takes nothing already written (Computed). The majors: **M1** the SIT button teleports a carrier up to 40 studs into a seat and the load is paid the next tick, which skips the carry walk and the fog sprint for everything within 40 studs of the train; **M2** a teleporting exploiter is loaded before the G4 speed check ever runs; **M3** the client re-sends the turret aim every 0.3 s, so an AFK player at a lamp is "active" for ever and takes load shares and album entries (G4 says they earn none) while raising the wave size for everyone; **M4** a rejoin within 2 minutes of a crash (or after a failed final write) loads "busy": the player plays the whole session on a blank offline profile, is never told, and the end card says "Everything you earned is saved."; **M5** decision 0018 section 5 and checkpoint items 6, 8, 9, 10 and 14 still carry the pre-LANTERN-015 numbers, so SHANNON would approve values the build does not use (rule 8 needs an amendment).

### Tool runs (local, 2026-11-06, at `ed1ef49`)

| Command | Result |
|---|---|
| `lune run tests/run` | **724/724 passed**, 0 failed, 0 load errors. `test-results.json` deleted |
| Reviewer script (scratchpad, not committed) against `LanternConfig`, `LootRules`, `CarryRules`, `WispRules`, `DepotRules`, `TrainRules`, `LanternProgress`, `MetaRules`, `LoginRules`, `Rng`, `SaveStore` and the fake DataStore | **176 checks pass**, 1 fails on purpose (it demonstrates M2); prints the 0018 section 5 mismatches (M5) and the busy-load result (M4) |
| `python -I docs/game-design/game6-pacing.py 300` | Output equals GDD section P row for row (28.0 / 27.4 / 26.4 / 25.6 / 24.6 min; 697 / 718 / 745 / 768 / 866 Tickets; 989 to 1,254 XP; Dawn 88 / 100 / 92 / 65 / 87%; album 11 runs, 90%: 27; Moon Hare 10%; levels 5 / 9 / 16 / 28 / 50) |
| `selene src tests` | 0 errors, 0 warnings, 0 parse errors |
| `stylua --check src tests` on an LF copy | Clean (exit 0) |
| `rojo build` + `node tools/check-place.mjs` for `default`, `garden`, `lantern`, `night`, `relay` | All five build and match their project files |
| `node tools/validate-tasks.mjs` | 95 task files valid (re-run after this review's task edit) |
| `node tools/check-scope.mjs origin/main` | All changed files in scope (re-run after this review's commit) |

## Findings

| Id | Severity | Where | Scenario | Suggested fix |
|---|---|---|---|---|
| M1 | Major | `src/lantern/LanternServer.server.luau:40` (`SIT_REACH` 40), `:599-614` (`sit`), `:365-367` (load box sampled for any carrier, seated or not); `src/lantern/Train.luau:389-413` (`seat` pivots the character into the seat) | **Read, Computed (geometry).** At a stop a player picks up the 22-stud critter crate (or anything within about 40 studs of depth: the site origin is 4 studs out from the track, the car side 4 studs from it, so `Train.distance` equals the depth) and presses the HUD's SIT. The server pivots them into the first free seat (the cab, inside the engine's load box); the next tick `TrainRules.load` pays the crate. The same works after the bell: a carrier within 40 studs of the train cannot be caught. GDD K's "walks back at 9 studs/s", the help-carry and the fog sprint (GDD B, C2) are skipped by a normal button, not an exploit; G4's "carry speed is set by the server" no longer holds near the train | Refuse `sit` while carrying unless the root is already in a load box (it would load anyway), or drop what is carried at the spot before seating from further out (`TrainRules.drop` first, then `Train.seat`). Add a TrainRules or server-glue test: a carrier at depth 30 who sits is not loaded |
| M2 | Major | `src/lantern/LanternServer.server.luau:502-513` (tick order: `sample`, then `TrainRules.tick` loads, then `carryChecks`), `:408-424`; `src/lantern/Carry.luau:13`, `:87-101` | **Read, Computed (the scratch check "teleport-load refused" fails: TrainRules loads a carrier reported in the load box on the next tick).** An exploiter (client-owned character) teleports to a far crate, picks it (the prompt's reach is checked against the position they just teleported to), then teleports into a load box. `sample` sees them in the box and `TrainRules.tick` loads and pays before `carryChecks` runs; `Carry.tooFast` also needs 0.5 s of samples, and its limit (1.5 x speed + 4 studs a sample) lets a solo crate move at 21.5 studs/s. One exploiter can clear a stop in seconds and inflate the weekly "Most critters" board (H8) for the whole crew | Check carry movement every tick before the tick's loads: in `sample`, compare each carrier's root with its last tick position (allowed `1.5 x CarryRules.speed x dt + 4`); a carrier who moved further is not in the load box this tick and drops at the last valid position. Keep the 0.5 s check for slow drift. Also mark "the character was moved by the server" (seat, stand, place) so M1's fix and this check agree |
| M3 | Major | `src/lantern-client/LampFx.client.luau:232-240` (aim re-sent every 0.3 s while still); `src/lantern/Night.luau:53-54` (`lastAim` on every accepted aim); `src/lantern/LanternServer.server.luau:350-352` (`touch` when aimed within 1 s); `src/shared/TrainRules.luau:125-153` (seat by last kind) | **Read.** A player goes AFK. At night the server seats them at a turret (turrets first); at every later departure `seatAll` gives their last seat, the turret, again; their client keeps sending the unchanged aim every 0.3 s (so the beam is not stale), and each accepted aim marks them active. They are never idle: every load pays them a share, every rescue goes into their album, and `activeCount` counts them, so wave sizes rise (a crew of 2 plus 2 AFK faces 16 wisps a wave on leg 1, not 8) and each real player's share falls (a Rare: 9 Tickets instead of 14). GDD G4 and I3 say an idle account earns nothing from loads | Count an aim as activity only when its direction changed (more than about 1 degree from the stored aim) in `Night.onAim`; keep refreshing the beam's `at` for the keep-alive. Optionally stop the keep-alive after 30 s without input on the client |
| M4 | Major | `src/lantern/LanternServer.server.luau:103-110` (no `onStatus`); `src/kit/SaveStore.luau:143-169` (busy: defaults, offline); `src/lantern-client/Menu.client.luau:722-731` (one check at 3 s); `src/lantern-client/Hud.client.luau:685` | **Computed (SaveStore with the fake store: a lock stamped 30 s before the join loads `busy` with 0 Tickets against 500 stored) and Read.** The server crashes (or a final write fails in an outage); the child rejoins within the 120 s lock-stale window. The kit tries three times over about 6 s and gives up "busy": the session runs on a default profile (empty album, 0 Tickets) and is never written. The client's offline toast runs once, 3 s after start, before `ProfileOnline` is set (it is nil, not false), so nothing is said; the run-end card says "Everything you earned is saved." Everything earned that session is lost, and the empty album looks like a wipe. A lock lost mid-session (`goOffline`) is also silent | Retry a busy load until the lock goes stale (every 15 s up to about 130 s) with the start menu saying "Loading your save..." and PLAY held (Router `ready` false until then); pass `onStatus` to `Saves.start` and send a notice for `busy`, `offline` and `lost`; in the client react to `ProfileOnline` changing to false (not a 3 s one-shot) and drop "Everything you earned is saved." when it is false |
| M5 | Major (docs, rule 8) | `docs/decisions/0018-lantern-express.md:101`, `:110`; `docs/checkpoints/LANTERN-V01.md:19`, `:21`, `:22`, `:23`, `:27`, `:51` | **Computed (config and pacing against the documents).** LANTERN-015 retuned the nights (dim 4.5 / 3.5 / 3.5 / 3, drift 6 / 7 / 8 / 8 by min(n, 4)) in config, specs, pacing script and GDD, but 0018 section 5 still says "dim 6 / 4.5 / 3.5 / 3" and has no drift by crew, and its pacing line says 709 to 868 Tickets, 1,050 to 1,270 XP, 24.7 minutes and an album median of 10. The checkpoint SHANNON will sign says: item 6 "709 Tickets a run alone and 779 in a crew of 4" (now 697 and 768); item 8 "level 6 after the first run, 17 after ten" (5 and 16); item 9 "median of 10 runs (90%: 24); 9% ... Moon Hare" (11, 27, 10%); item 10 "casual crews always reach Dawn; new players lose 6% to 30%" (casual crews reach Dawn 65% to 100%; new players lose most runs from leg 2 and crews of 3 or more never meet the Lampeater), and its "Harder" alternative now points the wrong way; item 14 "Garden keeps its own copy" (Garden is on the kit since LANTERN-005); the evidence line names `docs/qa/lantern-review.md` | Add amendment 2 to 0018 (the night values, drift by crew, the new pacing line), and correct checkpoint items 6, 8, 9, 10 and 14 from GDD P; item 10 should carry the crew-of-4 result (m12) and LANTERN-015's playtest recommendation. Point the evidence line at this file |
| m1 | Minor | `src/lantern/LanternServer.server.luau:264-333`, `:502-518` | **Read.** `dispatch` runs a tick's events in one `pcall` (`guarded("tick")`). If any handler throws (a `Train.seat` on a half-loaded character, `Stops.build`), the rest of that tick's events are dropped, including `load` (the run already marked the items loaded and counted the critter, so that load is never paid) or `end` (leftover Parts, bests, the end card). Not seen; the handlers look safe today | Guard each event: `guarded(kind, function() ... end)` inside the loop, so one failure costs one event, never a payout |
| m2 | Minor | `src/lantern-client/Hud.client.luau:723-724`; server `LanternServer.server.luau:320` | **Read.** The server sends `arrive` with `phase = "depot"` at every Depot; the HUD toasts "Scavenge! the next stop" for any `arrive` | Toast only for `data.phase == "stop"`; at the Depot say "Depot: spend Parts, vote the next line" |
| m3 | Minor | `src/lantern/Stops.luau:141-142`, `:444`; `LanternServer.server.luau:254-257` | **Read.** "Help carry" is enabled on a crate carried alone, so the carrier sees it on their own crate (gamepad X, E, tap); pressing it shows "Someone is already carrying that" | Hide the prompt for the carrier on the client (`ProximityPromptService.PromptShown` or set `Enabled` locally when `Carry` says `big = "critter"`) |
| m4 | Minor | `src/shared/LanternProgress.luau:324-325`, `:361`, `:384`, `:417`; `src/lantern/LanternServer.server.luau:850-869` | **Computed and Read.** At 00:00 UTC the first reward of the day (at night a puff every few seconds) runs `dayTick` and pays yesterday's completed quests inside `load`, `award` or `count`, but `Paid.tickets` leaves them out: no "(saved for you)" toast (GDD J), and the end card's Tickets miss them. The 60 s rollover check then finds nothing to say. Paid once, never lost | Return the `dayTick` text and Tickets from `load`, `award` and `count` (or call `join` for every online player at the top of the tick when the day changed) so the toast always shows |
| m5 | Minor | `src/shared/TrainRules.luau:310-325`; `src/lantern/Rewards.luau:163-192`; GDD J (`docs/game-design/game6-gdd.md:396`, `:401`) | **Computed and Read.** A solo player who quits mid-run (the usual way a solo session ends) ends the run "empty": `end` is dispatched with nobody in the crew, so leftover Parts become no Tickets, and no best or weekly board value is written for that run; a crew member who leaves gets no Parts share either. GDD J says leftover Parts are converted "so they never vanish" and the J table says "Run ends (any reason)". Parts are run property, not earned, so this is a promise mismatch, not a loss of earned value | Pay the leaver `DepotRules.leftover(parts, #order)` and their `runEnd` bests in `TrainRules.leave` (a `stopLeft`-style event for the leaver), or reword GDD J |
| m6 | Minor | `src/lantern-client/Menu.client.luau:216-218`; GDD H9, O | **Read, Engineer (LANTERN-007 "not built: followers").** ALBUM > FOLLOWER says "Your follower hops behind you at the Depot and rides with you" and the server stores it, but nothing draws a follower. GDD O keeps the Depot follower in scope (only the seat ride is first in the cut order) | Build the Depot follower (Garden FollowerFx pattern), or cut it at the checkpoint and change the text |
| m7 | Minor | `src/lantern-client/LampFx.client.luau:204-206`; `Hud.client.luau:255`, `:271`; `Menu.client.luau:682` | **Read.** On PC a turret seat locks the mouse to the screen centre every frame (unless a panel or the ping wheel is open), so mid-ride the HUD's STOKER swap, MEND and MENU buttons cannot be clicked. A solo PC player seated at a lamp (their last seat after every night) cannot reach STOKE again until the Depot. Not checked in Studio (LANTERN-012 clicked LAMP from the stoker seat, the other direction) | Bind keys while on a turret (F: swap seat, R: stoke or mend) or free the cursor while Alt or Ctrl is held |
| m8 | Minor | `src/lantern-client/Hud.client.luau:185-272` (no `ContextActionService` or `KeyCode` binding) | **Read.** Console is a target platform (GDD A) but SIT, STAND, DROP, STOKE, MEND, LAMP / STOKER and DEPOT have no gamepad buttons; they are reachable only through Roblox's UI selection mode, where the character cannot move | `ContextActionService` binds: ButtonY sit or stand, ButtonB drop, ButtonR1 stoke or mend, DPadUp swap; show the glyph on each button for gamepad users |
| m9 | Minor | `src/lantern-client/TrainFx.client.luau:493-497` | **Read.** Under Reduced Motion the loose items stop bobbing but keep their slow turn (`t * 0.6`); architecture 6 says every animation is skipped | Use a fixed angle when `ClientState.still()` |
| m10 | Minor | no `CollisionGroup` in `src/lantern` or `src/lantern-client` | **Read.** Characters collide with each other, so a player (or a fling exploit) can shove a carrier into the fog or fling them; the G4 check then drops the carrier's load. Nothing earned changes, but it is the one way one player can make another lose a carry | Put characters in a collision group that does not collide with itself |
| m11 | Minor | `docs/assets/register.md:305-324` | **Read.** The 20 `pending (lantern_icon_*)` rows stay beside the 20 rows with the uploaded ids (`:325` on); every `LanternIcons` id is registered (Computed) | Delete the 20 pending rows |
| m12 | Minor, balance | GDD P (`game6-gdd.md:482`); checkpoint item 10 | **Computed (pacing).** After the solo retune the crew of 4 is the hardest size: casual crews reach Dawn 88% solo, 100% in pairs, 92% in threes, **65% in fours**, 87% in sixes, all losses to the lantern at night (crews of 3+ kept drift 8 and dim 3.5 / 3). "Better with friends" (pillar 3) reads the other way for the most common friend group | Put the curve in checkpoint item 10 with LANTERN-015's two-to-four player playtest; the lever for 4 is `perTurret` or `DIM[4]` |
| m13 | Minor, feel | `src/lantern-client/ClientState.luau` `SFX` (`chuff = nil`), `MUSIC` (menu, day, night); GDD L, M | **Read.** Not built: the chuff that follows speed (L "chuff rate follows speed"), the Lampeater theme and the Dawn sting, and the stoke, dim, ping pop, Depot fanfare, level-up, pick-up and load sounds of M; rescue tiers differ by chime count and pitch of one sound | Register and wire the missing sounds, or list them as cut at the checkpoint before the feel gate |
| m14 | Minor, docs | see Stale documents | **Read.** The architecture, the art bible section 3, decision 0018 sections 2, 4 and Consequences and the GDD carry statements the build no longer matches | Fix each line listed below (the architect for `lantern.md`, the art director for the bible) |

## Stale documents (m14, M5)

Each statement and what the build does at `ed1ef49`.

**Decision 0018**
1. Section 5 Nights (`:101`): "dim 6 / 4.5 / 3.5 / 3 by crew size". Build: `DIM = { 4.5, 3.5, 3.5, 3 }` and `WAVES.speed = { 6, 7, 8, 8 }` by min(n, 4) (no drift value is in 0018 at all). (M5)
2. Section 5 pacing line (`:110`): "24.7 to 28.0 minutes ... 709 to 868 Tickets ... 1,050 to 1,270 XP ... median of 10 solo runs". Pacing now: 24.6 to 28.0, 697 to 866, 989 to 1,254, median 11 (90%: 27). (M5)
3. Section 2 train physics (`:31`): the decision is unanchored cars on rigid Align constraints, and the fallback "a client-drawn train". Build (architecture 4.3, LANTERN-006): anchored server cars moved by CFrame on Heartbeat, replicated by the server, no client-drawn train.
4. Section 4 weekly boards (`:95`): "names from `GetNameFromUserIdAsync`". Build: display names through `UserService:GetUserInfosByUserIdsAsync` (`Rewards.luau:209`), as GDD G5 asks.
5. Consequences (`:149`): "Garden keeps its own `UiKit.luau` until a Garden release moves it". Build: Garden's `UiKit.luau` is a 77-line shim over the kit since LANTERN-005.

**Architecture `docs/architecture/lantern.md`**
6. 1, reused files (`:26`): "Garden keeps its own file until a Garden release moves it" (as 5).
7. 3.1 (`:95`): `WAVES = { ..., speed = 8, ... }`. Build: `speed = { 6, 7, 8, 8 }`.
8. 3.1 (`:96`): `DIM = { 6, 4.5, 3.5, 3 }`. Build: `{ 4.5, 3.5, 3.5, 3 }`.
9. 3.5 (`:189-195`): no `WispRules.speed(n)`; spawned wisps take `speed(n)` at their wave (`WispRules.luau:103-105`, `:212`).
10. 4.6 (`:354`): "Where `Saves.start` does not pass that option on yet, the server's `sanitize` throws...". `Saves.start` passes `newer` (LANTERN-005), so `kitNewer` is true and the guard and `readOnly()` (`LanternServer.server.luau:95-127`) are dead code; its own shortcut comment says to delete it.
11. 6, `TrainFx.client.luau` row (`:398`): "followers (hop behind their owner at the Depot, ride on the seat arm during runs)". Not built (m6).
12. 9, sounds and icons (`:461`): "20 icon decals ... album, locker, rewards, board, settings, coal, parts, oil, lantern, ticket, four roles, six pings (glyph fallback until uploaded)". Build: the 20 are album, board, close, coal, crate, critter, depot, lamp, lantern, locker, mend, oil, parts, ping, rewards, settings, stoke, ticket, train, xp, uploaded with ids in `LanternIcons.luau`; roles and pings use aliases in `ClientState.luau:33-51`.

**Art bible section 3 (`docs/game-design/game6-art-bible.md`)**, against `TrainFx.client.luau:33-89` and `World.luau:385-428`:
13. Dusk row (`:54`): ClockTime 18.4, Brightness 1.6, Ambient (44, 38, 74), OutdoorAmbient (110, 100, 150), ColorShift_Top (255, 190, 150). Build: 17.35, 2.4, (84, 74, 116), (165, 145, 190), (255, 170, 120), plus ExposureCompensation 0.35.
14. Ride into night (`:55`): "18.4 to 0.5, 1.6 to 0.6". Build: 17.35 to 0.5, 2.4 to 0.8.
15. Night row (`:56`): Brightness 0.6, Ambient (34, 30, 64), OutdoorAmbient (64, 60, 110). Build: 0.8, (44, 40, 82), (86, 82, 140), exposure 0.25.
16. Dawn row (`:57`): Brightness 2.0, Ambient (60, 52, 80), OutdoorAmbient (150, 130, 150). Build: 2.2, (70, 60, 92), (160, 140, 160), exposure 0.3.
17. Atmosphere (`:59`): dusk Color Fog Lilac, Decay (96, 84, 150), Density 0.42, Offset 0.25, Glare 0.3, Haze 1.8; night Density 0.5, Decay (40, 36, 80). Build: dusk Color Horizon Peach (246, 168, 140), Decay (86, 104, 168), Density 0.3, Offset 0.1, Glare 0.5, Haze 2.6; night Density 0.42, Decay (48, 44, 96), Haze 1.6. The "about 250 studs of view" figure was for density 0.42 and is not re-measured.
18. Post effects (`:73`): ColorCorrection Saturation 0.08, Tint (255, 246, 240). Build: 0.12, (250, 240, 255).
19. Missing from the bible: Terrain `Clouds` (cover 0.5 dusk, 0.3 night, 0.45 dawn; density 0.6; colour (255, 186, 160)).

**GDD**
20. S, assumption (`:522`): "wisps drift at 8 studs/s". Build: 6 / 7 / 8 by crew size.
21. H1 table, UI kit row (`:229`): "Garden keeps its file until a Garden release moves it" (as 5).

**Checkpoint `docs/checkpoints/LANTERN-V01.md`**: items 6, 8, 9, 10, 14 and the evidence line, as in M5.

## Verified clean

### The owner's hard rules (Read unless marked)

| Check | Result | Evidence |
|---|---|---|
| No stealing or taking between players | Pass | `CarryRules.canPick` refuses a carried item ("taken"); `canHelp` only adds a second handle; the first carrier keeps the crate when the helper lets go, sits, leaves or is caught; a carrier who leaves drops the crate free at their spot (Computed: pick by B refused, help, A leaves, B leaves). No request names another player; `profileRequest` and every `Rewards.pay` change the caller's or the member's own save only |
| No combat, Mild fear | Pass | Beams only puff wisps into pastel sparkles (`LampFx.client.luau:340-353`); nothing damages a player; the Lampeater exists only when `leg >= 3` (`WispRules.luau:278`), i.e. after the first Depot, with "Something big is coming..." 3 s ahead (`LampFx.client.luau:518-525`); the caught overlay is lilac at 75% and fades (`TrainFx.client.luau:290-324`). Meshes were not inspected for teeth (Not checked) |
| Nothing earned is lost | Pass, see M4, m5 | Loads pay at the train (`TrainRules.luau:430-461`, `Rewards.load`); a crate loaded at stop 1 stays paid when the run then ends by the lantern (crews 1 to 3, 275 to 303 s with no beams) or by coal (solo, 300 s), and the end payload counts it (Computed); the last player leaving at hub, ride, stop, night or Depot ends the run "empty" with nothing undone (Computed); no `LanternProgress` function lowers Tickets, XP, album, rescues, owned cosmetics, milestones, stats or bests except a Locker purchase (Computed: 60 x 300 random operations); a quest completed and unclaimed is paid at the next day, once, by `join` or by the first load (Computed); five weekly sign-ins left unclaimed pay 40 + 60 + 80 + 100 and the livery at the week rollover, once (Computed). BindToClose finishes every open session (`Saves.luau`, kit) |
| No paid randomness, no purchases | Pass | No `MarketplaceService` in `src/lantern`, `src/lantern-client` or the kit's UiKit; critter rolls happen in `LootRules.build` when a stop is built; login and album cosmetics cannot be bought or equipped unless owned (Computed: `buy midnight/aurora/mossback/moonlit` refused with 100,000 Tickets) |
| No countdown pressure | Pass | The HUD shows a bar, never a number, for the bell, the Depot and the hub (`Hud.client.luau:356-392`); REWARDS says "Earned rewards are never lost" (`Menu.client.luau:350`); the run-end card leads with what was earned and never says "lost" (`Hud.client.luau:653-686`) |
| No free text | Pass | No `TextBox` anywhere in Lantern or the kit's UiKit; pings are an id checked against `LanternConfig.PINGS` (`LanternServer.server.luau:575-581`) and drawn from the fixed phrases (`PingWheel.client.luau:200-208`); announcements, the crew list, pings, the Depot board and the weekly boards use display names only |

### Server authority and exploits (Read unless marked)

| Check | Result | Evidence |
|---|---|---|
| Aim | Pass | Vector3 only, finite components, magnitude 0.5 to 1.5, sender in a turret seat by `Seat.Occupant`, burst 4 at 12 a second, `clampAim` (`Night.luau:36-56`); a beam counts only while its seat's occupant is the sender and the aim is under 0.5 s old (`:69-82`); exposure grows by the tick's `dt`, so a 100 Hz stream puffs nothing extra (WispRules spec); puff credit only to beams that lit the wisp on server positions (`:139-152`) |
| Requests | Pass | Every action through the kit Router (loading, rate burst 6 at 4 a second, ping costs 2, known action, `Payload` with arity: an extra argument is refused); enums for `sit`, `buy`, `vote`, `badge`, `claimLogin`; `^%w+$` up to 32 bytes for ids; ping pattern (`LanternServer.server.luau:573-774`); no request handler yields between reading and writing the run |
| Prompts | Pass, see M1, M2 | Crew membership and the server distance (reach 8 + 2) before `TrainRules.pick` or `help` (`:242-261`); a caught player cannot pick (`TrainRules.luau:749-757`) |
| Seats | Pass | A non-crew occupant is stood up and stepped off (`:790-796`); `stand` refused while moving; seat swaps while moving use strict kinds; the seated rule re-seats within one tick (Computed: zero violations over full runs for crews 1 to 6) |
| Fx targeting | Pass | `new`, `payout`, `notice` and `runEnd` go to the one player (`Rewards.luau:70`, `:94`, `:186`); the server never reads `Fx.OnServerEvent` |
| Joining mid-run | Pass | `TrainRules.join` places by phase (I4); a seventh player is refused "full"; a respawn is placed by phase (`:800-806`) |

### Saves (Computed unless marked)

| Check | Result | Evidence |
|---|---|---|
| One player's save per write | Pass (Read) | `saves.apply(player, ...)` with the member's own player in every payout; no code writes two records |
| Flush once through failures | Pass | A Rare rescue applied, the first flush fails, the second stores it: 25 Tickets and one `teapotcat`, nothing doubled; an autosave adds nothing; `finish` releases the lock. (A write that lands but reports failure would re-apply, as in every kit game: Not checked) |
| Newer save read-only | Pass | A `schemaVersion = 2` record with an unknown field loads offline; a payout and `finish` write nothing; the field survives |
| Sanitize round trip | Pass | 18,000 live profiles from the random run: `sanitize(snapshot(p))` equals `p` field for field (the default `weekBest.week = -1` normalised to this week is the only change) |

### Run state machine and seeds (Computed)

| Check | Result | Evidence |
|---|---|---|
| Seated rule, 1 to 6 players | Pass | Full runs to Dawn for each crew size: after every moving tick, every member sits or is in the fog |
| Someone leaves at each phase | Pass | hub, ride, stop, night, Depot: the run carries on; the last one out ends it "empty" (at the hub nothing ends) |
| Empty server | Pass | 60 s after the last leave the run rests at the hub with `d = 0` and never departs |
| Hub return | Pass | 12 s after `end`, a fresh hub run keeps the crew in order |
| Seeds | Pass | `LootRules.build` is deterministic; two servers voting the Line of the Week an hour apart get the same seed |

### Balance (Computed)

| Check | Result | Evidence |
|---|---|---|
| Config against GDD C, C6, F, H | Pass | Every C1 to C5 value, the C6 table row by row (counts, waves, dim, Lampeater need), upgrade prices, Tickets, XP, the 14 cosmetics, both login tracks |
| Odds | Pass | 100,000 seeded rolls per row within 0.5 points of H4; `LootRules.odds` sums to 10,000 for every tile, line, leg and band; over 7,200 built stops (400 seeds, every leg, line and stop, crews 1 to 6) no Moon Hare outside leg 3 far crates, no Mist Fawn on the Lake, no Bell Turtle on the Forest, no Ember Kit |
| Specs, pacing script and GDD agree on the retune | Pass | `WispRules.spec` and `LanternConfig.spec` pin 6 7 8 8 and 4.5 3.5 3.5 3; `game6-pacing.py` uses the same tables (`:36-37`); its output equals GDD P |

### Client and kit (Read unless marked)

| Check | Result | Evidence |
|---|---|---|
| Highlights | Pass | At most 8 loose-item outlines plus the Lampeater's one (`TrainFx.client.luau:444`, `LampFx.client.luau:441`) |
| Music loop | Pass | Three looped tracks crossfaded by phase and the menu (`TrainFx.client.luau:413-437`); every music and SFX id is in `docs/assets/register.md` (Computed) |
| LanternIcons | Pass, see m11 | 20 ids, each with a register row (Computed); fed to the kit with aliases |
| 12 px text | Engineer | LANTERN-007 measured 12.0 px at 844 x 390; client sizes are 16 px and up on the kit's scaled root |
| Reduced Motion | Pass, see m9 | float text, stoke pulse, sway, caught fade, wisp swell, Lampeater flaps, menu orbit, lighting blend and emitters check `ClientState.still()` |
| Egg Garden unchanged by the shared UiKit | Pass | Diff of Garden's `UiKit.luau` at `214314d` against the kit at `4efd021`: only injection (fonts, icons, sound, short, rarity, species, previews, accent, menu); every new token falls back to Garden's old value and Garden's theme defines none of them; the `close` icon branch added by LANTERN-015 needs `icons.close`, which `GardenIcons` lacks; `eggDisc` and the egg preload moved to Garden's shim unchanged. The other Garden diffs since `214314d` are GARDEN-058's own |

## Not checked

- Anything in a Studio play session or on staging (rule 13): the two-client checks (help-carry, joins, pings, votes, cruise jitter), the phone fps and 12 px measurement, the MicroProfiler frame time with 6 players and 34 wisps, leave-and-rejoin persistence with real DataStores, and whether `MouseBehavior.LockCenter` blocks the HUD clicks exactly as m7 reads.
- The meshes and contact sheets (teeth, faces, the Lampeater's dive framing near a turret camera).
- Fog wall particle cost on phones (smoke at 70 and 30 a second, sizes 22 and 16, `TrainFx.client.luau:195-204`).
- A DataStore write that commits but reports failure (re-applied ops), as for every kit game.
- Whether the ProximityPrompt `Triggered` distance from an exploit client is enforced beyond the server's own reach check.
