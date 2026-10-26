# Hundred Demon Night v0.1: QA and security review (NIGHT-006)

Reviewer: A15 (did not write NIGHT-003, NIGHT-004 or NIGHT-005). Date: 2026-10-25. Branch `game3/concept`, commits `a2e160a` (pure rules) and `731fd33` (server and client).

Scope: `src/shared/{Rng,CombatRules,WaveRules,BossRules,BlessingRules,RunRules,MetaRules,NightProgress,ProgressRules,StyleRules}.luau` and their specs, `src/night/*`, `src/night-client/*`, against `docs/game-design/game3-gdd.md`, `docs/architecture/night.md`, `docs/decisions/0007-hundred-demon-night.md` and `CLAUDE.md`.

Line numbers refer to commit `731fd33`. During this review, the game 4 thread had uncommitted edits in the working tree to `src/shared/MetaRules.luau` (Garden fields, decision 0008) and `src/night-client/Menu.client.luau` (hide the menu on becoming a participant). Those edits are not reviewed here. Because `MetaRules` is shared, Relay's and Night's specs must be run again after they land.

This is a code review only. Nothing here was run in Studio. The GDD section M playtests, including the two-client test, are still to do.

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 4 |
| Minor | 12 |

Checked and working as specified (facts, from reading the code and running the tests):

- `lune run tests/run`: 207/207 passed, 0 load errors. `selene src/night src/night-client src/shared`: 0 errors, 0 warnings.
- The F2 check value holds: a solo tier-1 night at rank D gives XP 315 + 150 = 465 and souls 190 + 100 = 290 (`NightProgress.waveRewards`, `victoryRewards`).
- Relay is unaffected: `tests/ProgressRules.spec.luau` was not touched and passes; the only file changed under `src/relay` is `Models.luau` (new entries).
- `Request` follows the 0007 checks in order: loaded session, action is a string, `arg` is nil or a string of at most 32 characters, a 0.35 s cooldown that refused requests do not reset, the action table, and arg present only for actions that take one. `equipWeapon` is refused while the player is in a run. Run actions are checked by `RunRules`, meta actions by `NightProgress`/`MetaRules` on the server's own profile. No action takes an amount, price or result from the client.
- `Combat` refuses a second argument, unknown actions, non-participants, downed players and wrong states. Refused events count toward the rate limit. Damage, gauge, style, kills and rewards are all decided on the server.
- Profiles: no session exists until the load finishes; a failed load (after 3 attempts) runs offline and writes nothing; every write is an `UpdateAsync` that re-applies the same pure change to the sanitised stored record. So a failed or slow load cannot write defaults over saved progress. Sanitising clamps every number and drops unknown `owned` ids and locked weapons, blades and masks.
- Fx payloads match between the server senders and the client handlers for all 13 kinds. Clients skip their own `swing` and `dash`. Every handler runs inside a `pcall` and type-checks its fields.
- Child safety: no custom chat, no `TextBox`, no data collected beyond the game profile, no Robux. The leaderboard shows Roblox usernames only. The theme (yokai, skulls, a "Blood" moon tier, demon masks) is fantasy violence with no gore. It needs the matching answers in the experience questionnaire.

---

## Major

### M1. The teleport guard can be bypassed: attacks are hit-tested at a position the guard never checked
- **Where:** `src/night/Combat.luau:196-218` (`onCombat` reads `rootOf(player)` when the event arrives), `src/night/Combat.luau:288-306` (the guard only compares the 10 Hz samples).
- **What happens:** the guard sets `guardUntil` only when it sees two *samples* more than 12 studs apart. The hit test uses the root position *when the event arrives*, between samples, and that position is never compared with the last sample. An exploiting client can move its root next to a target, send `attack` or `skill`, and move back before the next sample. The guard never fires, and if a sample does catch the move, the swing has already been accepted. Downed players have the same gap: `WalkSpeed = 0` is only a server property on client-owned physics, so a downed exploiter can move onto an ally to start an ally revive.
- **Reproduce:** on a local server, run a client script that does `root.CFrame = enemyCFrame; Combat:FireServer("attack"); task.wait(); root.CFrame = old` every 0.3 s against a far enemy. The hits register and `guardUntil` stays at `-inf`.
- **Fix:** in `onCombat`, before `attack` and `skill`, refuse when `CombatRules.flatDistance(entry.sample, vec(root.Position)) > GUARD.distance + allowance`. Thunder Dash path ends need a similar check (m2). Add a pure `CombatRules` helper and a spec case.

### M2. Repeating an equip or setTier writes to the DataStore every time, so one player can use up the server's whole write budget
- **Where:** `src/shared/MetaRules.luau:309-317` (`equip` returns `true` when the item is already equipped), `src/shared/NightProgress.luau:238-254` (`setTier`, `equipWeapon` the same), `src/night/Profiles.luau:247-262` (every accepted request calls `apply`, which calls `UpdateAsync`).
- **What happens:** the 0.35 s cooldown allows about 2.85 accepted requests per second. Because equipping the current item or setting the current tier is "accepted", each one is an `UpdateAsync` on the player's key. With 6 players the server's write budget is 60 + 10 × 6 = 120 a minute (2 a second), and one player sending `equipCosmetic("steel")` in a loop goes over it alone. The other players' wave-clear and victory writes are then throttled. After 3 failed tries they are dropped, and m1 then rolls them back in memory too. The same-key limit (one write per 6 s) also fills that player's own queue.
- **Reproduce:** from a client, loop `Request:InvokeServer("equipCosmetic", "steel")`. Watch the DataStore budget warnings (`DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)`) drop to 0 while a second player clears a wave.
- **Fix:** have `equip`, `setTier` and `equipWeapon` return `false` (no change) when the value is already set, and refuse no-op changes before `apply`. Also consider coalescing meta writes per player (at most one `UpdateAsync` in flight per key, with later changes queued into it).

### M3. Leaving and rejoining mid-run resets a downed player to full HP with a fresh charm
- **Where:** `src/shared/RunRules.luau:139-165` (`play` always creates a `newParticipant`), `src/night/NightServer.server.luau:201-212`.
- **What happens:** in a party, a downed player with no charm sends `leaveRun` and then `play` 0.35 s later. They come back alive at 100% HP with a new charm and catch-up blessings, at the shrine steps. In co-op, downs and charms stop mattering and Defeat can only happen if everyone goes down in the same tick. Each rejoin also resets `clears`, so the next clear counts `runs +1` again. That farms the `nights3` quest and inflates the `runs` stat. (GDD B2 allows joining mid-run but does not cover rejoining. Leaving by opening the menu makes this two clicks.)
- **Reproduce:** two clients. Client A gets downed with no charm while B is alive. A presses MENU twice (leave), then START. A is alive at full HP. Clearing the wave adds 1 to A's `runs` again.
- **Fix:** needs a design decision (rule 8 or a GDD note). Suggested rule: the run remembers leavers (`left[userId] = { downed, charms, hp, stacks }`) and a rejoin in the same run restores that record, and `first` stays false. A smaller version: refuse `play` for a player who left this run while downed.

### M4. A general's summon crashes the server tick about half the time (table modified while it is being iterated)
- **Where:** `src/night/Enemies.luau:1288-1300` (`for id, mob in mobs` with `spots[id]`), called through `stepMob`, then `summon`, then `spawnMob` (`Enemies.luau:1044-1055`, `615`).
- **What happens:** the Oni General's summon adds new keys to `mobs` while `Enemies.step` is iterating `mobs`. When the loop then visits a new wisp, `spots[id]` is nil and `flat(here - there)` throws "attempt to perform arithmetic on nil". The `pcall` in the Heartbeat handler catches it, but the rest of that tick is lost. Hurts already collected from attacks that landed this tick are dropped (their `pending` was already cleared, so those attacks just vanish). Mobs later in the iteration don't move. `Combat.step`, `RunRules.tick` and `publish` are skipped. A Lune check of the same insert pattern visited a new key in 97 of 200 trials. This happens every 10 s on wave 5.
- **Reproduce:** play to wave 5 and watch the server output for `[NightServer] tick failed: ... arithmetic` every few summons.
- **Fix:** iterate over a snapshot, e.g. `for id, here in spots do local mob = mobs[id]; if mob then ... end end`, or queue summons and spawn them after the loop.

---

## Minor

### m1. A write that fails after 3 tries is lost, and the next successful write rolls it back in memory too
- **Where:** `src/night/Profiles.luau:111-122`.
- **What happens:** `apply` changes `session.profile` at once. If the `UpdateAsync` fails 3 times, only memory has the change. The next successful write adopts the stored record, which never had it, so the souls or XP the player saw disappear. More likely together with M2.
- **Fix:** on final failure, keep the pending change and re-apply it inside the next `UpdateAsync` (a per-session queue of pending changes). At least log it.

### m2. A Thunder Dash path has no length limit and ignores the teleport guard
- **Where:** `src/night/Combat.luau:226-233`, `386-403`.
- **What happens:** the path runs from the root at dash time to the root 0.35 s later, both positions owned by the client. Resolution 3 exempts dashes from the guard, so a client that moves its root across the arena hits every enemy along a line of any length, once every 0.95 s.
- **Fix:** clamp the end point to `from + dir * maxDashDistance` (about 95 × 0.25 + walk distance, roughly 30 studs), or skip the path when it is longer than that.

### m3. The Combat rate-limit history grows with every event, so spam gets quadratically slower to process
- **Where:** `src/shared/CombatRules.luau:124-136`.
- **What happens:** every event in the last 1 s is kept and the list is cloned and rebuilt on each event. At N events a second that is O(N²) work per second for one client. A client sending thousands of `Combat` events a second (each refused) takes server CPU from everyone.
- **Fix:** keep only the newest `RATE.count` timestamps (a 20-slot ring). The rule "refused events count" still holds. Add a spec case for 1,000 events.

### m4. The teleport guard fires on legitimate dashes when the server lags
- **Where:** `src/shared/CombatRules.luau` `guard` (fixed 12 studs), `src/night/Combat.luau:288-306`, `src/night-client/Movement.client.luau:21` (dash at 95 studs/s).
- **What happens:** a dash covers 9.5 studs per 0.1 s. When the gap between samples goes above about 0.126 s (Heartbeat hitches, a long tick from m8, or replication bursts), an honest dash passes 12 studs and attack and skill are blocked for 1 s.
- **Fix:** pass the real time between samples to `guard` and allow `distance <= max(12, maxSpeed × elapsed)`.

### m5. Two participants can share a `joinIndex` after someone leaves, so they get identical blessing offers and spawn on the same spot
- **Where:** `src/shared/RunRules.luau:152`.
- **What happens:** `joinIndex = #participants + 1`. With [A1, B2, C3], B leaves and D joins as 3, the same as C. The offer and catch-up seed is `Rng.seed(run.seed, joinIndex, w)`, so C and D always get the same offers, and `placeAtSpawn` stacks them.
- **Fix:** use `max(joinIndex) + 1` (or a run-level counter). Add a spec case.

### m6. "Buy" then "equip" in the Locker always fails to equip
- **Where:** `src/night-client/Menu.client.luau:664-666`.
- **What happens:** `ask("equipCosmetic")` is sent as soon as `buyCosmetic` returns, which is one round trip, well under the server's 0.35 s cooldown. The equip is refused without a message, so the item is bought but not worn.
- **Fix:** wait out the cooldown before the equip (`task.wait(0.4)`), or have the server equip a bought cosmetic as part of `buyCosmetic` (a contract change: 0007 note).

### m7. No `BindToClose`, so pending writes can be lost when the server shuts down
- **Where:** `src/night/Profiles.luau` (no `game:BindToClose`).
- **What happens:** writes run in `task.spawn` with retries that wait 2 to 4 s. When the last player leaves, or the server shuts down for an update, writes still in flight (often the wave-10 and victory writes) can be cut off.
- **Fix:** count in-flight writes and add `game:BindToClose` that waits until the count is 0 (up to about 25 s). The same gap exists in `src/relay/Profiles.luau`.

### m8. Lantern, general and boss meshes load during the server tick, and a failed load is retried on every spawn
- **Where:** `src/relay/Models.luau:80-92` (`CreateMeshPartAsync` yields and failures are not cached), called from `src/night/Enemies.luau:123-125` and `486` inside `Enemies.step`.
- **What happens:** if the warm-up at `Enemies.luau:1311-1320` has not finished, or has failed, each lantern or general spawn yields inside the tick. Heartbeat skips ticks while `busy`, and the tick then finishes with an old `t`. If the asset fails, every later spawn tries the HTTP load again and stalls again.
- **Fix:** in Night, cache a failure (`cache[name] = false`) so later calls fall back to parts at once, or spawn models outside the tick (only the record inside it).

### m9. The wave-10 clear and the victory write hit the same key in the same tick
- **Where:** `src/night/NightServer.server.luau:135-158` → `Profiles.recordWave` then `Profiles.recordVictory`.
- **What happens:** two `UpdateAsync` calls on one key at once. The second waits in the same-key queue (about 6 s). It is still written, but this is the write most likely to be cut off by m7 when players leave after a win.
- **Fix:** have `recordVictory` include the wave-10 result in one `UpdateAsync` (a combined pure function `NightProgress.applyFinal`).

### m10. Client: the telegraph table keeps destroyed parts until the enemy is killed, and never clears them after a Defeat
- **Where:** `src/night-client/CombatFx.client.luau:751-766` (`telegraphs[e]` is only cleared by the `kill` handler at `841`).
- **What happens:** every telegraph adds 1 to 3 part references. Enemies removed by `Enemies.clear()` (Defeat, the last player leaving) never get a `kill` event, so their lists stay. That is a small but unbounded leak over a long session.
- **Fix:** remove destroyed parts in `remember`. Also clear all of `telegraphs` when the state changes to Countdown or Idle, where the markers are already cleared (`1265`).

### m11. Client: the downed spirit flame stays when a downed player leaves the run
- **Where:** `src/night-client/CombatFx.client.luau:1090-1134` (markers are cleared on `revive`, Countdown, Idle and PlayerRemoving), `src/night/NightServer.server.luau:170-181` (`leave` sends no Fx).
- **What happens:** a downed player who opens the menu (leaves the run) keeps a blue flame and light pillar over their head on every client until the next Countdown.
- **Fix:** clear markers for user ids no longer in `NightStatus.ids`, or send `Fx("revive", { u })` from `leave` when the player was downed.

### m12. Character reset is not disabled during a run
- **Where:** `src/night/NightServer.server.luau:340-355`, client (no `SetCore("ResetButtonCallback", false)`).
- **What happens:** a participant can use Esc → Reset. For the respawn time they have no root, so enemies ignore them and the defeat check counts them as alive. They come back at the entrance and the teleport guard blocks their attacks for 1 s. It cannot be used for much, but it breaks the server-owned HP model (C8 says the Humanoid stays alive).
- **Fix:** `StarterGui:SetCore("ResetButtonCallback", false)` while a participant (wrapped in `pcall` with retry). Or treat a participant's character death as a down on the server.

---

## Not defects / accepted risks (for SHANNON)

- Hurt `key` (night.md 4.1) is never read on the server (`NightServer.server.luau:291`). Each attack removes its own duplicates (`dash.hit`, `act.hit`, a projectile ends on its first hit, contact once a second). This works but differs from the doc. Contact "dodges" score 15 style points each second per enemy, which lets a player farm style in a crowd. That is a design call.
- 0007 already accepts that facing and walking (under 12 studs per sample) are client-owned. There is no vertical or fly check either. A flying client can sit in narrow height bands where it can hit enemies but cannot be hit (hypothesis, not tested).
- Performance (assessment from reading the code, not profiled): the separation loop does about 1,000 pair checks per tick at 32 enemies; mob models are at most 15 parts (32 × 15 = 480); attribute and `NightStatus` writes happen only on change. Nothing here is a concern at 6 players. The boss creates two tweens per tick during slams; they are garbage-collected.

## Still to do for NIGHT-006 acceptance

- The GDD section M Studio playtests, the two-client mid-wave join, revive and catch-up test, and a client-side exercise of every Request and Combat refusal (only reviewed here, not run).

---

## Fixes

Gameplay Engineer, 2026-10-25, on `game3/concept` after `731fd33` (uncommitted). Checks: `lune run tests/run` 298/298 passed; `stylua --check` and `selene` clean on every touched file; `rojo build night.project.json -o build/night.rbxl` succeeds. Nothing was run in Studio, so the section M playtests are still to do.

| Finding | Fix |
|---|---|
| M1 | New `CombatRules.nearSample(sample, current)`: `attack` and `skill` are refused when the root is more than 12 studs (horizontal) from the latest 10 Hz sample, or when there is no sample yet. Nothing is extrapolated from the client. While a player is downed, `Combat.sample` holds their position where they fell, so ally revives cannot be started by moving a downed root. Spec cases added. |
| M2 | `Profiles.apply` compares a canonical (key-order-independent) encoding before and after a change and skips both the write and the publish when nothing changed. Writes are queued per player: at most one `UpdateAsync` is waiting or in flight per key, changes made meanwhile join the next one, and a key is written at most once every 6 s, so one player makes at most 10 writes a minute. `MetaRules` and `NightProgress.setTier` are unchanged (Director ruling). |
| M3 | `Run.left` keeps each participant who leaves during Countdown, Wave or Break. A `play` in the same run restores that record: HP, downed state, pending charm revive, charms, blessings and `clears`. So `first` (the `runs +1`) is true only once per player per run. This break's offer and pick are kept only on a rejoin in the same break. The record is dropped when a new run starts. The server shows the spirit flame again for a player who comes back downed. Five spec cases added. **GDD note needed:** B2 says a joiner gets full HP and one charm; this adds "a rejoin in the same run restores your state (no catch-up blessings)". |
| M4 | `Enemies.step` iterates the `spots` snapshot and looks up `mobs[id]`, so summons added mid-loop wait until the next tick. |
| m1 | A write that fails 3 times keeps its changes at the front of the queue. The next write, the player leaving or `BindToClose` writes them again. A warning is logged. |
| m2 | The Thunder Dash path is created only from a trusted origin (as M1). Its end is clamped to `CombatRules.DASH.path` = 30 studs (`CombatRules.clampPath`). Spec case added. |
| m3 | `allowRequest` keeps only the newest 20 times. Spec case with 1,000 events added. |
| m4 | `guard` takes the real time between samples and allows `max(12, 120 × elapsed)`. This is the GDD C10 rate of 120 studs/s, so the rule is unchanged. Spec case added. |
| m5 | `joinIndex` is the highest live index + 1, and a restored player also gets a fresh one. `placeAtSpawn` wraps the index onto the 6 spots. Spec case added. |
| m6 | The Locker waits 0.4 s between `buyCosmetic` and `equipCosmetic`. There is no contract change. |
| m7 | `game:BindToClose` flushes every queue and waits up to 25 s for in-flight writes. `Profiles.release` also flushes. Relay's copy is not touched (out of scope). |
| m8 | Night spawns a mesh in the tick only after the warm-up has loaded it (`warmed`). Otherwise the enemy is built from parts at once, so a slow or failed load never yields the tick or retries. `src/relay/Models.luau` is unchanged. |
| m9 | The queue starts its write with `task.defer`, so the wave-10 clear and Victory (same tick) go out in one `UpdateAsync`. There is no new `NightProgress` function. |
| m10 | `remember` drops destroyed parts, and every telegraph list is cleared on Countdown or Idle. |
| m11 | The client clears spirit-flame markers for user ids missing from `NightStatus.ids`, checked on each status update. |
| m12 | The HUD turns `ResetButtonCallback` off while you are fighting (polled at 2 Hz, so it retries until SetCore is ready). This is client-side only: the server does not treat a character death as a down. |

Follow-ups outside this change: `docs/architecture/night.md` 3.2 and 3.6 need the new signatures (`guard(..., elapsed?)`, `nearSample`, `clampPath`, `DASH.path`, `GUARD.speed`, `Run.left`). The H7 wording "saved after each … equip" now means "queued at once, written within about 6 s". A no-op equip saves nothing.
