# Egg Garden v0.1: QA and security review (GARDEN-006)

Reviewer: A15 (did not write GARDEN-003, GARDEN-004 or GARDEN-005). Date: 2026-10-26. Branch `game3/concept`. Commits reviewed: `66fd84e` (architecture, decision 0008), `f9a89f8` (pure rules and client), `9a6a0f1` (server).

Scope: `src/shared/{GardenConfig,WorldRules,GardenRules,HatchRules,GardenProgress}.luau` and the `MetaRules` changes, `src/garden/*`, `src/garden-client/*`, `garden.project.json`, the Garden entries in `src/relay/Models.luau` and the rows in `docs/assets/register.md`. Checked against `docs/game-design/game4-gdd.md`, `docs/architecture/garden.md` and `docs/decisions/0008-egg-garden.md`.

Line numbers refer to `9a6a0f1` (the files have not changed since).

This is a code review only. **Nothing was run or playtested in Studio by this reviewer.** The GDD section O playtests are still to do: timings, rejoin after 10 minutes, the two-client test, MicroProfiler and the screenshot.

## Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 2 |
| Minor | 12 |

### Tool runs (local, 2026-10-26, at `071a764`)

- `lune run tests/run`: **298/298 passed, 0 failed, 0 load errors**. Garden-related suites: GardenConfig 9, GardenRules 21, HatchRules 16, WorldRules 8, GardenProgress 24, MetaRules 13. Relay's ProgressRules (21) and Night's suites (NightProgress 17, RunRules 32, CombatRules 26, WaveRules 16, BossRules 9, BlessingRules 9) all pass. `test-results.json` (gitignored) was deleted afterwards.
- `selene src`: 0 errors, 0 warnings, 0 parse errors. `stylua --check src`: clean.
- `rojo build`: `default`, `garden`, `night` and `relay` `.project.json` all build (outputs went to a scratch folder).
- `node tools/validate-tasks.mjs`: 24 task files valid. `tools/scan-secrets.sh`: no secrets found.

### Checked and working as specified (from reading the code and running the tests)

- **Request router** (`GardenServer.server.luau:157-198`) applies the 0008 checks in order. It checks for a loaded session and plot, a string `action`, an `arg` that is nil or a string of at most 32 characters, and the shared 0.35 s limit (refusals inside the cooldown do not reset it). Then come the action table, the arg/no-arg rule and `^%d+$` for ids. `buyEgg` checks 25 studs (horizontal) from the cart on the server root. Every action is then decided on the server's own profile (`Profiles.request`, `Profiles.luau:304-323`). The client never sends amounts, prices, outcomes or positions.
- **Bed prompts** (`GardenServer.server.luau:262-283`): same session and rate limit, 12 studs on the server root. Only the owner can hatch. Water re-checks `canWater` on the owner's current profile after the friend lookup has yielded.
- **Hatch rolled once, applied once:** `HatchRules.roll` runs once with a fresh `Random.new()` seed (`GardenServer.server.luau:207`). The queued op is `GardenProgress.hatch` with that fixed `outcome`, and `HatchRules.apply` re-checks that the bed is ripe, the egg is the same and the garden is not full. Re-applying never re-rolls.
- **Saves** (`Profiles.luau`): a session is online only after `GetAsync` succeeds, so a failed load never writes defaults. Every write is one `UpdateAsync` of `sanitize(old, now)` + queued ops + `snapshot(unbanked, now)`. `ops` and `unbanked` are captured together before any yield. Writes are coalesced to one per 7 s, with a 60 s autosave and a final write on leave and in `BindToClose`. A failed flush puts its ops back at the front. The leave path banks every pad and then writes `unbanked = 0`. Within one server, `coins + unbanked` stays consistent through crashes, failed flushes and leave (traced by hand).
- **Sanitising** follows H7 and 0008 (`GardenProgress.luau:93-223`). NaN, infinity, negatives, non-numbers, unknown ids and duplicate creature ids are handled through `MetaRules.count`/`dayNumber`.
- **Published odds and pity:** the ODDS card (`Menu.client.luau:454-527`), the Index and the EGGS panel read the same `GardenConfig` tables that `HatchRules`/`WorldRules` roll from. They format with `HatchRules.percent` and show a checked total. The Lucky Meter text (`pity / meter`, "guaranteed by hatch meter") matches `rollSpecies` (forced at `pity >= meter - 1`). The single-egg card shows the current weather's mutation table, and the server reads the weather at acceptance. Every row in `GardenConfig` matches the 0008 tables (eggs, odds, mutations, sizes, weather, bed and pen costs, cosmetics, quests).
- **Client names vs server builds:** every name the client looks up exists. That covers `Workspace.Garden.Plots.Plot<n>` (`Owner`, `Gate`), `Beds.Bed<i>` (`Egg`, `Planted`, `Ready`, child `Soil` with prompts `Hatch`/`Water`, child part `Egg`), `Pads.Pad<i>` (a Part), `Creatures.<id>` (`Id`, `M`), `Sign` (parented to the plot model, `Plots.luau:503-504`), the cart prompt `Shop`, the light parents `Lamp` and `HangingEgg`, the Model `Sails`, `GardenStatus`, `GardenRemotes.Request/Fx`, and the attributes `Profile`, `ProfileOnline`, `Coins`, `Income`, `Plot`, `LastReward` and `OfflineCoins`. `GardenClientFx` is created by `HatchFx` and waited for by `CreatureFx`. Fx payloads match on both sides.
- **MetaRules changes are safe for Relay and Night:** `wins` is written only when the target profile has it, and both `ProgressRules.defaults` and `NightProgress.defaults` set `wins = 0`. `maxCoins` defaults to `MAX_COINS`. `reward` returns the base without `scale`. No file under `src/relay`, `src/relay-client`, `src/night` or `src/night-client` was changed by the Garden commits except the 10 new `Models.luau` entries. Relay and Night specs pass, and both projects build.
- **Child safety:** no `MarketplaceService`, `TextBox`, purchase prompts, trading or gifting in `src/garden`, `src/garden-client` or the Garden shared modules. The only cross-player effects are a helper's water and a like. The reveal never shows other creatures. Display names are used in announcements.
- **Assets:** all 10 new meshes have register rows. Client audio IDs (`87416512611152`, `9117060347`, `9125585534`, `9114630316`, `9114373663`, `9125442175`) all have rows (see m12 for the "used in" column).
- **Performance (assessment, not profiled):** the 5 Hz loop is per player: accrual over at most 80 creatures, 20 pad checks, and the gate guard (36 pair checks at 6 players). The 1 Hz loop refreshes 6 plots, and every refresh uses change keys. None of this is a concern at 6 players. Network is the real cost (m3).

---

## Major

### M1. No session lock: a server hop can pay `unbanked` twice and re-roll a hatch
- **Where:** `src/garden/Profiles.luau:185-219` (load reads with `GetAsync`, no lock), `120-147` (flush), `src/shared/GardenProgress.luau:228-248` (`login` pays the stored `unbanked` as an absolute amount; `snapshot`/`leave` set `unbanked` and `lastSeen` to absolute values).
- **What happens:** the re-apply pattern is safe for ops that re-check their own preconditions. `unbanked` is different: it describes coins that only the old server's memory holds, as pending pad coins. Suppose the player leaves server A with `U` unbanked (saved by A's last periodic flush) and joins server B, and B's first flush (about 1 s after B loads) lands before A's leave flush. Then B's `login` op pays `U` plus offline time from A's last flush and sets `unbanked = 0`. A's leave flush then re-applies `bank(all pads)`, which includes the same `U`, on top of B's record. `U` is paid twice, plus up to 60 s of offline income. Pending pad coins have no cap, so `U` can be hours of income for a player who never walks over their pads. The same race lets a hatch be re-rolled. A hatches (bad roll, not yet flushed), the player hops, and B still sees the bed ripe and hatches it again. If B's write lands first, A's hatch op is refused on the stored record, so the player keeps B's roll. GDD K and 0008 say the re-apply pattern covers "two servers at once", but it does not cover these two fields.
- **Likelihood:** low in normal conditions. A's leave flush starts at disconnect and usually lands well before B finishes a teleport. It becomes likely when A's write is delayed: `finish` waits up to 25 s for an in-flight write (`Profiles.luau:381-383`), and retries back off 2 s and 4 s. This happens exactly when DataStores are degraded.
- **Reproduce (Studio, two servers or a published test place):** throttle or fail A's `UpdateAsync` for about 10 s (for example with a temporary `task.wait(10)` in `flush` before the call). Stand off the pads for 2 minutes, then leave and join B at once. Coins after both writes exceed `coins_before + all pad coins`.
- **Fix:** add a session lock to the record, as in the ProfileService pattern. The load is an `UpdateAsync` that claims `lock = { job = game.JobId, at = now }`. If another job's lock is newer than about 90 s, wait and retry before running `login`. Every flush refreshes the lock, and the leave flush clears it. A smaller fix: store `unbankedJob = game.JobId` in `snapshot`, and have `login` pay `unbanked` only after that job's leave has cleared it. This is a schema change, so it needs a 0008 note and a `GardenProgress` spec case.

### M2. A player who gets no plot has a dead session with no message
- **Where:** `src/garden/GardenServer.server.luau:421-425` (no free plot: warn and return before `Profiles.load`), `454-464` (`onLeave` frees the plot only after `Profiles.finish` returns), `src/garden/Plots.luau:925-935`.
- **What happens:** with no free plot, the player never gets `State.live`, a profile or a plot. Every Request and prompt is refused, and the HUD shows `defaults(0)`. Nothing tells the player, and nothing retries. Two ways in. (a) The place's Max Players is above 6: it is a game setting, not set anywhere in the repo, and GDD K relies on it. (b) In a full 6-player server, a replacement joins while a leaver's `Profiles.finish` is still yielding. That is normally under 1 s, but up to 25 s plus retries when DataStores are slow. During that time the leaver's plot still has `Owner` set.
- **Reproduce:** Studio, Test > Players 7 (or set Max Players 7). The seventh client gets no plot and no profile, and the server logs `[GardenServer] no free plot`.
- **Fix:** in `onLeave`, call `Plots.free(live.plot)` before `Profiles.finish`. The final write does not need the plot view, and `State.live` is already cleared. When `Plots.assign` returns nil, wait for a `Plots` freed signal and retry, or kick with a friendly message. Set Max Players to 6 in the place settings and record it in the GARDEN-004 notes.

---

## Minor

### m1. "Buy" then "equip" in the Locker always fails to equip (same as Night m6)
- **Where:** `src/garden-client/Menu.client.luau:855-857`.
- **What happens:** `equipCosmetic` is sent one round trip after `buyCosmetic`, inside the server's 0.35 s cooldown. It is refused silently, so the bought fence or can is not worn.
- **Fix:** `task.wait(0.4)` before the equip (Night's fix).

### m2. A hatch reveal hides every creature with the same id on every plot
- **Where:** `src/garden-client/ClientState.luau:47`, `54-57` (`hidden` is keyed by creature id only), `src/garden-client/CreatureFx.client.luau:207`, `src/garden-client/HatchFx.client.luau:327`.
- **What happens:** creature ids are per profile (every player's first creature is `1`), and the display gardens on free plots use ids 1 to 5. When anyone hatches creature `n`, every client hides creature `n` in every garden for the 1.5 s reveal.
- **Fix:** key `hidden` by `owner .. ":" .. id`. CreatureFx can get the owner from the plot model's `Owner` attribute.

### m3. The full profile JSON is re-sent to every client about once a second per player while banking
- **Where:** `src/garden/Profiles.luau:91-114` (`publish` encodes the whole profile into the replicated `Profile` attribute), `166-170` and `331-334` (quiet bank ops set `dirty`, which republishes at 1 Hz), `src/garden/GardenServer.server.luau:304-308`.
- **What happens:** bank ops change only coins and quest progress, but each one re-sends the whole record. Every accepted request does too, up to 2.85 a second. With 6 full gardens (about 9 KB each, GARDEN-004's estimate) and everyone walking over their pads, each client receives about 6 × 9 KB = 54 KB/s of profile JSON. That is above the usual per-client budget and hard on phones. This is a hypothesis from reading the code, not measured.
- **Fix:** for quiet bank ops, update only the `Coins` attribute and republish `Profile` on the next non-coin change. Or send the full profile only to its owner (`FireClient`) and a small public view (beds, gate, `penSlots`, creature count, likes, can) to the others. Measure with the Network stats during the 6-client test.

### m4. Cross-player pairs are not atomic
- **Where:** `src/garden/GardenServer.server.luau:133-155` (`like`), `243-257` (helper water).
- **What happens:** `like` checks `GardenProgress.like` on the profile captured before `gateAllows(..., true)` yields on `IsFriendsWith`. Two `like` requests 0.35 s apart, while the first friend lookup for a `friends` gate is still running, both pass that check. The liker's second op is then refused by the rule, but `receiveLike` is applied unconditionally, so the owner gets +2 from one liker. In the same way, the helper's XP op is queued even if the owner's `water` op is later refused on the stored record.
- **Fix:** re-check `GardenProgress.like` on `Profiles.get(player)` after the yield (as `water` already does). Treat the counterpart op as best effort, and document that.

### m5. Mesh load failures are not cached, so creature builds can yield the 1 Hz tick
- **Where:** `src/relay/Models.luau:131-136`, `src/garden/Plots.luau:684` (`makeCreature`), `src/garden/GardenServer.server.luau:359` (`slowTick` calls `Plots.refresh`).
- **What happens:** if a creature mesh fails to load (for example a place owned by a group rather than the account that generated the meshes, see the register's "same owner" terms), every new creature model tries `CreateMeshPartAsync` again. The 1 Hz `slowTick` refresh then yields, which delays `Profiles.step` and the status write. Night fixed the same issue with a `warmed` gate (Night m8). Garden did not.
- **Fix:** in Garden, build the fallback at once unless the warm-up in `Plots.build` has loaded that species (keep a `warmed` set), as Night does.

### m6. Meadow Eggs are a positive-value buy, hatch and release loop (design, for SHANNON)
- **Where:** `src/shared/GardenConfig.luau:70-80`, `GardenRules.releaseValue` (`GardenRules.luau:95-97`).
- **What happens:** the expected release value of a Meadow hatch is 53.1 coins for the species, × 1.049 for Clear mutations, × 1.13 for sizes, which is about 62.9 coins for a 50-coin egg (+26%). It is about +85% in Sunbeam and +140% in a Rainbow Shower. Each loop also pays 10 XP and progress on `hatch5`, `hatch15` and `release3`. With 12 beds this is a free coin faucet that does not need a garden. No other egg is profitable to release.
- **Fix (design):** decide if this is intended. If not, raise the Meadow price or lower `RELEASE_SECONDS`. That needs a new decision record (0008 Consequences).

### m7. `collect50` completes in about 10 s of standing on one pad
- **Where:** `src/garden/GardenServer.server.luau:288-309`, `src/shared/GardenProgress.luau:250-257`.
- **What happens:** each 5 Hz bank of a pad with at least 1 coin counts as one collect. A single creature earning 5 coins/s or more completes the quest in 50 ticks while the player stands still. This matches the H5 wording ("pads banked with at least 1 coin"), but the quest becomes a non-task.
- **Fix (design):** count a pad only once per visit (when the root steps onto it), or raise the goal.

### m8. `BindToClose` can go past its 30 s budget
- **Where:** `src/garden/Profiles.luau:375-385`, `393-406`.
- **What happens:** `finish` waits up to 25 s for an in-flight write. It then runs a flush whose retries can wait another 2 s + 4 s, and `finishAll` waits up to 27 s. A slow write at shutdown can be cut off.
- **Fix:** derive the deadlines from one start time: wait at most about 10 s for an in-flight write, and pass a "no retry waits after 25 s" deadline to `withRetries`.

### m9. Bank ops are queued one per 0.2 s and never merged
- **Where:** `src/garden/GardenServer.server.luau:304-308`, `src/garden/Profiles.luau:152-171`.
- **What happens:** 0008 says "the 0.35 s request limit already bounds queue growth; banking is merged into the queue like any op". Banking is not rate-limited, though: it adds up to 5 ops a second, and each one runs a full `sanitize` plus deep copy when replayed. During a DataStore outage the queue grows without bound, and every retry replays it all inside the `UpdateAsync` transform.
- **Fix:** when the last queued op is a bank op, replace it with one combined bank (sum the coins and the pad counts). Or keep a per-session `pendingBank` that is folded into one op at flush time.

### m10. Open panels are rebuilt every second, so gamepad selection is lost
- **Where:** `src/garden-client/Menu.client.luau:1301-1308` and `1329-1333`.
- **What happens:** `GardenStatus` changes every second (`weatherLeft`, `stockLeft`), and the Odds panel is fully rebuilt on each change. Any open panel is also rebuilt on every `Profile` change, which is 1 Hz while banking (m3). A gamepad user's `SelectedObject` is destroyed each time.
- **Fix:** rebuild the Odds panel only when `weather` changes, and update labels in place on profile changes (or restore the selection by `LayoutOrder` after rebuilding).

### m11. The world forecast board does not show the mutation tables
- **Where:** `src/garden/World.luau:745-770`.
- **What happens:** GDD E6 and the 0008 child-safety section say "the forecast board and the Index show every weather's table". The board shows only the three windows. The Index and the ODDS card do show the tables, so the odds are still published.
- **Fix:** add the four mutation rows to the board's SurfaceGui (or get SHANNON to accept the Index and ODDS card as enough).

### m12. GDD audio and can items are missing, and reused audio rows do not list Garden
- **Where:** `src/garden-client/Menu.client.luau:1336-1352`, `src/garden-client/ClientState.luau:305-312`, `docs/assets/register.md` lines 13, 17-20 and 36.
- **What happens:** H6 asks for two bright acoustic tracks, a dreamy Moonfall track and stingers. The build reuses Relay's lobby track ("Serenity Through Shadows") with an EQ for Moonfall, and gong hits as stingers. GDD R leaves the music picks to SHANNON. H4's "watering can is held while watering" is not built (only the splash colour is). It is first on the M cut list. The register rows for the reused track and SFX still list only Relay and Night under "used in". Also, `LastReward` toasts (`Profiles.luau:316-318`) do not show when two claims or releases in a row pay the same amount (the attribute value does not change).
- **Fix:** add Garden to the "used in" column, and get SHANNON's music picks. Set `LastReward` to `""` before the new text, or append a counter.

---

## Not defects / accepted risks (for SHANNON)

- The weather stinger toast says "Rainbow chance is 10.00% for 5 minutes" (`HatchFx.client.luau:736-739`). The numbers are honest and come from the published table. G4.7 allows countdowns only on the restock and weather boards, so please confirm that this time-limited wording is acceptable for under-18 players.
- Distance checks are horizontal and use the client-owned root (0008 Consequences). A teleporting exploiter can buy from anywhere and bank their own pads faster, but cannot touch another profile.
- The Top Gardens board uses `GetNameFromUserIdAsync` (usernames, as H6 says), with 10 uncached web calls a minute (`Profiles.luau:411-432`). Caching names per UserId would be cheaper.
- A failed final write (3 tries) on leave loses that session's ops. The stored record stays consistent: the next login pays the last snapshot's `unbanked` plus offline time.
- Lamp lights are switched by both the server (`World.forecast`, `Enabled`) and the client (`HatchFx`, `Enabled = true` plus brightness tweens). This only affects looks.

## GDD section O status

| Item | Status |
|---|---|
| Unit tests in N pass in CI | Local 298/298. No CI link attached yet |
| Hatch odds, pity, mutations, sizes (incl. 100,000-roll test) | Pass (`HatchRules.spec`) |
| Income, pads, offline, release check values | Pass (`GardenRules.spec`, `GardenProgress.spec`) |
| Buying, stock, watering, hatching | Pass (unit tests) |
| Weather and restock schedules | Pass (`WorldRules.spec`, incl. Friday 23:59 / Saturday 00:00 and 20,000 windows) |
| Rewards, quests, likes, gate, sanitising | Pass (unit tests) |
| Relay `ProgressRules` tests | Pass, unchanged |
| New player: starter hatched within 15 s, Meadow bought within 60 s | **Not run** (Studio) |
| Sunset Egg within 25 minutes | **Not run** (Studio) |
| Leave and rejoin after 10 minutes pays offline and keeps everything | **Not run**. Code is correct for a single server. See M1 for server hops |
| Two clients: water, like, closed gate blocks both and moves the visitor | **Not run**. Code reviewed and correct (`GardenServer.server.luau:133-155`, `232-260`, `328-344`) |
| Every ODDS panel matches `GardenConfig`, totals 100% | Code review: the panel reads the same tables and shows a total row. Visual check not done |
| Server frame time under 8 ms with 6 full gardens | **Not run** (MicroProfiler). Also watch network (m3) |
| Start-menu screenshot test | **Not run** |
| Register rows; no Robux, paid items or trading | Rows exist (m12: "used in" column). No monetisation or trading code found |

## Still to do for GARDEN-006 acceptance

- Every Studio item above, including a client-side exercise of each Request action and both prompts with refusals (wrong owner, distance, gate, rate limit), the two-client test and the 10-minute rejoin with DataStores on.
- Re-review after fixes for M1 and M2.

---

## Fixes

Fix engineer (did not write the review), 2026-10-26, on `game3/concept` after `bd6a07b`. Studio Director rulings applied for m6, M1 and M2. Checks (local): `lune run tests/run` **304/304 passed**, 0 failed, 0 load errors (298 before, plus 1 economy and 5 session-lock cases; `test-results.json` deleted); `stylua --check src tests` clean; `selene src tests` 0 errors, 0 warnings; `rojo build` of `default`, `garden`, `night` and `relay` `.project.json` all succeed; `node tools/validate-tasks.mjs` 24 valid; `tools/scan-secrets.sh` no secrets. Relay and Night specs pass and no file under `src/relay`, `src/relay-client`, `src/night` or `src/night-client` changed; `MetaRules` is unchanged. **Nothing was run in Studio.** Line numbers are in the fix commit.

| Finding | Fix |
|---|---|
| M1 | Session lock on the stored record, `lock = { session, at }` (decision 0008 amendment 2026-10-26). Pure rules `GardenProgress.LOCK_STALE` = 120 s, `canClaim`, `holds`, `locked` (`GardenProgress.luau:254-288`), 5 spec cases (`GardenProgress.spec.luau:158`), including the server-hop case. Load is one `UpdateAsync` that claims the lock, retried 2 s and 4 s, else offline with a notice (`Profiles.luau:247-296`). Every flush writes only while `holds`, refreshes the lock, and the final write releases it. A flush that finds the lock gone or taken writes nothing, and the session goes offline with `ProfileOnline` false and a notice (`Profiles.luau:148-174`). A player who leaves during the load is finished at once, so the lock is released (`Profiles.luau:289-292`). |
| M2 | `onLeave` frees the plot before `Profiles.finish` (`GardenServer.server.luau:481`). With no free plot, the player gets a notice every 10 s and the assignment is retried every second (`GardenServer.server.luau:430-443`). `Plots.COUNT` is exported (`Plots.luau:25`), and the server warns when `Players.MaxPlayers` is above it (`GardenServer.server.luau:493`). Max Players = 6 cannot be carried by a place file, so it is in the publish checklist (`docs/architecture/garden.md:414`, `publish.yml` header). |
| m1 | 0.4 s wait between `buyCosmetic` and `equipCosmetic` (`Menu.client.luau:857`), as Night m6. |
| m2 | `ClientState.hidden` is keyed `"<owner>:<id>"` (`ClientState.luau:55`). HatchFx passes `data.owner` (`HatchFx.client.luau:327,332,389`), and CreatureFx builds the key from the plot's `Owner` (`CreatureFx.client.luau:139`). |
| m3 | Pad banks go through `Profiles.bank` (`Profiles.luau:212`), which publishes only `Coins`. The full `Profile` attribute goes out with the next other change or write, about every 7 s while banking instead of 1 Hz. Not measured: the 6-client Network stats check is still to do. |
| m4 | `like` re-checks `GardenProgress.like` on the liker's current profile after the friend lookup (`GardenServer.server.luau:145`). The counterpart ops (`receiveLike`, helper XP) are documented as best effort (0008 amendment, `garden.md` 4.3). |
| m5 | A `warmed` set is filled by the warm-up (`Plots.luau:210`, `925`). `makeCreature` uses a mesh only when its species is warmed, otherwise the part fallback at once (`Plots.luau:688`). The creature key includes the warmed flag (`Plots.luau:712`), so early fallbacks become meshes on the next 1 Hz refresh. |
| m6 | Director ruling: `RELEASE_SECONDS` 30 → 6 (`GardenConfig.luau:215`). The expected buy, hatch and release return is at most 54.5% of the price (Meadow in Rainbow Shower), 28.6% in Clear. A test asserts at most 60% for every sold egg in all 4 weathers, with a Lucky Meter upper bound (`GardenRules.spec.luau:98`). Release check values are updated (Big Golden Berry Cat 324). Recorded as the dated amendment in `0008-egg-garden.md:195`, and GDD C4/E1/N are updated. |
| m7 | A pad counts for `collect50` once per visit (`live.visits`, `GardenServer.server.luau:302`). Banking is unchanged. 0008 amendment, GDD H5 note. |
| m8 | `finish` waits at most 10 s for a running write (`Profiles.luau:466`). Then it writes with a deadline 25 s after it started (`Profiles.luau:469`), and `withRetries` skips any retry wait that would pass the deadline (`Profiles.luau:96`). |
| m9 | Consecutive same-day banks merge into the last queued op (`Profiles.luau:222-233`), so a DataStore outage queues one bank op instead of 5 a second. |
| m10 | The Odds panel is rebuilt only when the weather changes (`Menu.client.luau:1359`). Panel rebuilds go through `rerender`, which puts a gamepad selection back on the button at the same place (`Menu.client.luau:1303`). |
| m11 | The forecast board shows the four weathers' mutation tables from `GardenConfig`, formatted with `HatchRules.percent` (`World.luau:369`). The board is 11 studs tall instead of 8. |
| m12 | Partly fixed. The register's "used in" column now lists Garden for the 6 reused audio rows (`docs/assets/register.md`). `LastReward` carries a `#n` suffix, so equal rewards in a row toast again; the client strips it (`Profiles.luau:401`, `Menu.client.luau:104`). **Not fixed (design):** SHANNON's music picks (GDD R), and the held watering can, which is first on the GDD M cut list. |

**Still needs Studio:** a two-server hop with a delayed final write. It should run offline with the busy notice, and the coins after both writes should equal the coins before plus the pad coins. Also: a lock left by a stopped Studio session (it is free after 120 s). Test > 7 players: the seventh gets the waiting notice, then gets a plot when someone leaves. Locker buy-then-equip. Two players hatching creature 1 at once: only the hatcher's creature hides. Fallback-to-mesh swap after the warm-up. The forecast board text size at 11 studs. Gamepad selection during banking and weather changes. Network stats with 6 full gardens. The repeated reward toast. Plus every GDD section O item listed above.
