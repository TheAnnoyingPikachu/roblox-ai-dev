# Animal Stations (game 7): handoff for the fight presentation pass

Written 2026-11-14 at the end of a long session, for a new session that starts the work in
`studio/tasks/STATION-031.json`. Read this, then `CLAUDE.md`, `src/stations/CLAUDE.md` and the task
file. Facts are labelled: **Fact** (checked), **Assumption**, **Idea** (a suggestion, not decided).

## 1. The ask

SHANNON (solo dev, uses they/them) said the arena looks amazing and wants the fights to be more
entertaining to watch: "making the animal fight animations look better". I proposed four items, and
SHANNON asked for this handoff so a new session can begin them:

1. **Impact, not just motion.** A hit-stop (about 60 ms freeze) on the attacker and target, a spark and
   shockwave at the point of impact, a small camera punch, a bigger flinch on the target. Power attacks
   get a charge-up glow and a proper landing effect.
2. **Ranged attackers fire something.** Archers and mages stand and "shoot" nothing today. Add an arrow in
   flight and a spell bolt (display only: the rules have no range and must not get one).
3. **Per-species attacks, a win pose and a defeat reaction.** Today every animal shares one attack clip
   and one "magic" clip (lion pounce, rhino charge, flamingo wing strike, tortoise slam are the ideas).
4. **Fight rhythm.** A slow-motion beat on the killing blow, a camera cut-in on a power attack or boss,
   and a **skip button** so a player can leave a fight without watching it.

The **smaller option** I named is items 1 and 2 plus the skip button (about one task). SHANNON said
"these 4 items", so plan all four, in the order above, and ship in slices (see section 7). Also named
and not yet done: a private test publish and a phone measurement (section 8). Both need SHANNON's
approval (publishing) or a device.

## 2. Where the repo is

- **Fact.** Worktree `C:\Users\pikachud\rad-game7`, branch `game7/foundation`, last commit `7c2f2a8`
  ("STATION-030: the Breach portal ..."), pushed. No PR is open (open one PR when the game is playable;
  SHANNON merges PRs). Nothing is published. Tests: `lune run tests/run.luau` is 677/677.
- **Fact.** Studio place `stations.rbxl` (studio id `b530253d-6a9d-4d0d-bf9b-ad13bc283839`) is open and
  synced to the repo as of that commit. A sync server on port 8765 may or may not be running (it was
  stopped).
- **Fact.** Next free task number is `STATION-031` (this task, status `planned`); the next after is 032.
- Standing rules (also in `CLAUDE.md`): every change belongs to a task file in `studio/tasks/`; decisions
  in `docs/decisions/` (next number **0048**); the server is authoritative; pure rules live in
  `src/shared` with Lune specs; never put secrets in code, prompts, memory, logs or chat; never publish,
  spend money, change credentials or migrate player data without SHANNON's approval; external assets
  need a `docs/assets/register.md` row; commit messages end with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, PR bodies with
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- SHANNON's preferences: build autonomously and ask only before publishing; ponytail "lite" (build what
  was asked, name the smaller option, end every reply with one or two lines on what was skipped or not
  checked and any risk); **no PvP in mind** ("dont do anything with pvp in mind"); stats only affect
  waves; no stealing mechanics, no paid randomness; own names and art, no copies; the user now wants
  finished detail on approved pieces, not frameworks.

## 3. How a fight works today (read before touching it)

**Fact.** A fight is decided on the server, paid at once, and then replayed for show.

1. Client `Hud.client.luau`: the Waves sheet's Fight button calls `request:InvokeServer("wave", n)`
   (`fight` function, then `announce(n)` shows a title banner). The admin menu's "Test wave" buttons call
   `testwave` (wave, team `starters` / `mythics` / `mine`): **the best way to look at a fight, because it
   needs no eggs, pays nothing and is admin-only (Studio counts as admin).**
2. Server `StationsServer.server.luau` `waveFight`: `StationProgress.canFight`, `LevelRules.fight`
   (pure, deterministic, `BattleRules.battle`), `StationProgress.payout`, then `WaveShow.run(player, wave,
   team, report)`; a win is paid with `StationProgress.clear` after `run` returns true. `readyAt[player]`
   (fight time + 4 s) stops a second fight early, so skipping a replay cannot make farming faster.
3. `src/stations/WaveShow.luau` `run`: spawns both teams (`Creatures.spawn`, `Creatures.spawnFoe`), team on the
   dais (tag `WaveStand`), enemies walk out of the Hexbound's gate (tag `ArenaGate`) at `WALK_SPEED`
   13 studs/s, sets the player's `CamFocus` and `CamRadius` attributes, then **replays the log**:
   `BattleRules.battle(team, foes, log)` gives `Hit = {t, side, slot, tside, tslot, dmg, hp, power, heal?}`.
   Each hit runs in its own `task.spawn`: waits to `start + e.t - lead` (`lead` 0.45 s, or 0.92 s for a
   power attack), plays `attack` or `magic` on the actor (`Creatures.play` sets the `Anim` and `AnimAt`
   attributes), lunges the actor (a tween of `Root`, skipped for `RANGED` = `foe_archer`, `foe_mage`), then
   at `e.t` sets the target's `Hp` attribute, plays `hit` (or `fall` when `hp <= 0`) and, if `e.heal`,
   updates the healed one's `Hp` a beat later (guarded by a per-slot `version` counter). The result report
   fires `seconds + 0.4 + 1.6` after the start (`pending[player]`, called once; `WaveShow.clear` also
   fires it). `WaveShow.active()` allows one show at a time.
4. Client `Creatures.client.luau`: every model tagged `Creature` is posed each `PreSimulation` from its
   `Anim` / `AnimAt` attributes by writing `Motor6D.Transform` (joints: body, head, leg_fl, leg_fr, leg_bl,
   leg_br, tail, wing_l, wing_r; biped foes use the same names: arms are `leg_fl`/`leg_fr`, legs
   `leg_bl`/`leg_br`, cape `tail`). Clips are tables of keyframes (`ATTACK`, `MAGIC`, `BIPED_ATTACK`,
   `ARCHER_ATTACK`, `MAGE_ATTACK`, `BIPED_MAGIC`, `HIT`, `DIE_QUAD`, `DIE_BIPED`); `sample(clip, t)`. Effects:
   `charge(model, colour, seconds)` and `impact(model, colour, molten)` (a ground shockwave at the
   *actor's* feet when a `magic` clip reaches `MAGIC_IMPACT` = 0.92 s), `floatNumber` (damage and heal
   numbers) and `watchHealth` (health bars) driven by the `Hp` / `MaxHp` / `Side` attributes.
5. `src/stations-client/ArenaCamera.client.luau`: takes the camera while the player has `CamFocus` and
   `CamRadius` (Scriptable, 55 degrees, pitch 31, yaw 34 plus a slow sway; framing from
   `UiLayout.fightDistance`); gives it back when they are cleared. `ArenaMood.client.luau` fades the local
   light to dusk by position. The result panel and wave title live in `Hud.client.luau`.
6. `wave_done` (server) clears the show and teleports the player to the arena's entrance; `home` does the
   same to the ranch. These are the existing "leave the fight" paths: **the skip button is a client button
   that calls `wave_done` (and shows the result), nothing more.**

Animation lengths: `Creatures.LENGTH = {attack 0.95, magic 1.6, hit 0.4, die 1.2}` (server) must match the
clips (client).

## 4. Rules you must not break

- **Display only.** A fight's result comes from `BattleRules`/`LevelRules` and is already paid before the
  replay shows. Nothing you add may decide, delay or change a result, a payout or the log. `BattleRules`
  logging must stay "never changes the result" (there are specs). If a new effect needs data (a hit's
  point, a projectile's flight time), put it in the replay, not in the rules.
- Keep new pure helpers (curves, timings, easing) in `src/shared` with a Lune spec, like `UiLayout.luau`
  and its spec. Roblox-side code is checked in Studio.
- **Particles and parts: cheap.** The arena is already about 1,800 parts, about 30 lights and emitters,
  and each Hexbound has an aura (smoke emitter plus one light). **Not measured on any phone.** Budget the
  new effects: short-lived emitters (`Emit(n)` bursts, not `Rate`), parts destroyed with `Debris`, no new
  `PointLight` per hit (one shared flash at most). Use only `rbxasset://textures/particles/*.dds`
  (`smoke_main`, `fire_main`, `sparkles_main`) or plain neon parts: **no new uploaded assets** (those need
  the Blender pipeline, the `Upload Blender assets` workflow and a register row).
- No PvP assumptions. Nothing here is about fights between players.

## 5. Where each item hooks in (Ideas)

1. **Impact.** The client only sees attribute changes today, so it cannot know a hit's strength or point.
   **Idea:** have `WaveShow` also set short-lived attributes on the *target* model (for example `HitAt`
   (server time), `HitPower` (0 normal, 1 power), `HitDmg`) next to the `Hp` change, and let
   `Creatures.client` react (spark burst at the model's `Hit` box, flinch scaled by power). Attributes
   reach the client one at a time and in no fixed order (this bit us: `ArenaCamera` once stopped itself
   because `CamFocus` arrived before `CamRadius`): **read them tolerantly, never stop on a missing one.**
   Camera punch: a player attribute such as `CamPunch` (a timestamp plus strength) read by
   `ArenaCamera`, added to the camera's CFrame and decayed. Hit-stop: do it client-side per model (hold
   the pose by freezing the model's clip time for about 60 ms), never by pausing the server replay.
2. **Ranged.** `WaveShow` already knows `RANGED`. **Idea:** at `e.t - lead + (the clip's release time)`
   spawn a short-lived anchored part (arrow: a thin box; mage bolt: a neon ball with a trail) and tween it
   from the actor's hand height to the target's `Hit` box over the time left to `e.t`, then destroy it.
   Archer release is near the end of `ARCHER_ATTACK`; mage near the thrust in `MAGE_ATTACK`: check the
   keyframes. Spawn it on the server (`Workspace`, replicated) or fire a client event; the tween is on the
   server today for lunges, so keep it consistent.
3. **Per-species attacks.** Clips are keyed only by `biped` and `Asset` (`foe_archer`, `foe_mage`).
   **Idea:** a table `Asset -> clip` for the eight animals and the eight variants (`creature_lion`,
   `creature_lion_sun`, ...; `StationRules.assetOf`), falling back to `ATTACK` / `MAGIC`. Animals have
   body, head, four legs and a tail (no wings or arms), so poses are pitch/yaw/roll and offsets of those.
   Sizes differ a lot (tortoise to elephant Titan); poses scale with the model's `Scale` attribute.
   Defeat reaction exists (`DIE_QUAD`); a win pose is new: the server must tell the client who won
   (the show's `report` already carries `won`; set an `Anim` of `"win"` on the survivors at the end).
4. **Rhythm.** Fights run 17 to 28 s in tests; `MAX_SECONDS` is 300. The replay is scheduled by
   `os.clock` waits against the log, so **slow-motion must not stretch the server timing**: do it as a
   camera/FX beat (FOV push-in and slowed particle speed) around the final hit, or add a fixed pause
   before the last `e.t` and add it to the report timer. A skip button: show it in the fight panel
   (`Hud.client.luau`, `result` / `buttons`) and call `wave_done`; the pay is already committed and
   `readyAt` already protects farming. A cut-in camera on a power attack: `ArenaCamera` blends to a
   closer target for about a second when it sees a power-hit attribute.

## 6. How to work in this repo on this machine

- **Tools.** `lune run tests/run.luau`; `stylua src tests`; `selene src`; `node tools/validate-tasks.mjs`;
  `node tools/check-scope.mjs origin/main`. Rojo build: `~/.rokit/tool-storage/rojo-rbx/rojo/7.7.1/rojo.exe
  build stations.project.json` (the rokit shim is blocked by Windows App Control).
- **Studio sync loop (the fast one).** Start `python -m http.server 8765 --bind 127.0.0.1` in `src`. Stop
  Play, then in **Edit** mode `execute_luau`: `HttpService:GetAsync` each file and
  `ScriptEditorService:UpdateSourceAsync` into the matching script (create a missing ModuleScript or
  LocalScript first; map: `src/shared` to `ReplicatedStorage.Shared`, `src/stations` to
  `ServerScriptService.Stations`, `src/stations-client` to
  `StarterPlayer.StarterPlayerScripts.StationsClient`). Destroy `workspace.Hub` and `Terrain:Clear()` if the
  world changed. Press Play and verify with `execute_luau` (Client or Server datamodel) and `screen_capture`
  (`camera_position` / `look_at_position` work in Play). HttpService does not work in Play. Stop the server
  afterwards (`Get-NetTCPConnection -LocalPort 8765 -State Listen`, `Stop-Process`). The profile resets
  every Play (offline), so buying eggs costs a 60 s wait: **use admin test waves instead.**
- **Fight test recipe.** In the Client datamodel: `game.ReplicatedStorage.StationsRemotes.Request:InvokeServer(
  "testwave", 10, "starters")` (wave 10 has the first dragon; "mythics" is a maxed team that wins in about
  1 s, too fast to watch); wait about 12 s; `screen_capture`. `wave_done` ends it. The camera tool resets
  the camera type once after an `execute_luau` (harmless, logged in the console).
- **Testing UI at other sizes.** Set the player's `UiSize` (Vector2) and `UiOpen` (a sheet name)
  attributes. `user_mouse_input` clicks by `instance_path` (buttons are named by their text, for example
  `LocalPlayer.PlayerGui.StationsHud.Root.Nav.Home`); pixel coordinates are off by the 58 px top inset.
- **Traps learned.** A ProximityPrompt must stay enabled on the server and only the nearest one shows (stand
  on its part, face it). Long shell heredocs with quotes fail in Git Bash: write patch scripts with the
  Write tool, assert each replacement matches once, and match short unique markers (stylua re-wraps long
  lines). A statement starting with `(` is read as a call: bind to a local first. A `UIScale` scales its
  parent too. `Instance.new("ColorCorrectionEffect")` is named "ColorCorrection": find effects by class.
  Attributes replicate one at a time. `Props.part` takes a `CFrame` or a `Vector3`.

## 7. Suggested plan

1. **Slice 1 (the smaller option, one PR-sized task):** impact effects (item 1), ranged projectiles
   (item 2), skip button. Verify with admin test waves 1, 6 and 10 as stills and in motion, and watch the
   wave-10 whelp and ogres (big models) and a wave with archers (from wave 3) or mages (from wave 6; the foes of a wave are drawn by a fixed seed, so look at the enemy names in the wave title).
2. **Slice 2:** per-species attacks, a win pose, tuning the defeat reaction (item 3).
3. **Slice 3:** slow-motion beat and the power-attack cut-in (item 4).
4. After each slice: decision record (0048 onwards), task file, update `docs/game-design/game7-gdd.md`
   "Built" and `src/stations/CLAUDE.md`, commit and push. Keep each task to about ten files (rule 11);
   split if needed, and update `STATION-031` as slices land (or open 032, 033).

Acceptance (all slices): no script errors in the console; a fight still ends with the same result and
payout as before (compare `won` and `seconds` for the same wave and team); frame time on a desktop
no worse than before with 3 plus 3 fighters (measure `RunService.Heartbeat` average over a fight; before
numbers do not exist, so measure with and without the new effects); effects are cleaned up (count
`Workspace` children after a fight).

## 8. Known gaps and risks (carry these forward, do not hide them)

- **Not measured on a phone or tablet.** The arena (about 1,800 parts, about 30 lights and emitters) and
  the UI are only seen on a desktop. A private test publish would show real devices; it needs SHANNON's
  approval (Max Players must be set to 3 in the place settings, and the save shape would be frozen
  before real players). First trims if it is heavy: the Breach's floating rock, the columns' flutes, the
  small gargoyles (decision 0047).
- Not seen yet: a Drake (wave 30) or the big Dragon (wave 60) in the new arena frame; two players
  (the arena-busy refusal and the shared dais); the `mine` team option of the test wave; a very wide
  fight against the gallows and banners (the camera can be crossed by one).
- The hover card (mouse only) keeps its old look; touch players cannot read an enemy's stats outside the
  wave list.
- Archers and mages have no range in the rules and must not get one; the projectile is only show.
- The `Max Players 12 is above the 3 ranches` warning in the Studio console is expected (it is a place
  setting).
- Waves above 2 were fought only through the admin test wave, never through the player flow with a hatched
  team beyond wave 2; drop numbers (coins, XP, samples) are first guesses (decisions 0043, 0046).
- Not built and not part of this task: gear, daily/weekly/monthly login tracks, the egg overhaul, quests,
  cosmetics, leaderboard, music, co-op teams, saving to Roblox (deferred: "we'll do saving later").

## 9. Where to look

| What | Where |
|---|---|
| Fight replay | `src/stations/WaveShow.luau` (`run`, `fall`, `busy`, `clear`) |
| Fight rules and log | `src/shared/BattleRules.luau` (`battle`, `Hit`), `src/shared/LevelRules.luau` |
| Fight request, pay, leave | `src/stations/StationsServer.server.luau` (`waveFight`, `wave_done`, `home`, `testwave`) |
| Poses, effects, health bars, numbers | `src/stations-client/Creatures.client.luau` |
| Camera and dusk | `src/stations-client/ArenaCamera.client.luau`, `ArenaMood.client.luau` |
| Fight UI (banner, result, skip goes here) | `src/stations-client/Hud.client.luau` (`announce`, `fight`, `result`, `buttons`) |
| Models and attributes | `src/stations/Creatures.luau` (`spawn`, `spawnFoe`, `play`, `describe`, `LENGTH`) |
| The arena | `src/stations/Arena.luau`, `ArenaKit.luau`, `Breach.luau`, `World.luau` |
| Decisions to read | 0040 to 0047 (enemies, test wave, real fights, UI, arena, Breach) |
| Game design | `docs/game-design/game7-gdd.md`, `game7-enemies.md`, `game7-animals.md` |
