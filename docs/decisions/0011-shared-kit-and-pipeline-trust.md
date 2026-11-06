# 0011: Shared kit for saves and remotes, build stamp and publish verification

Date: 2026-10-31
Status: Proposed for SHANNON (CLAUDE.md rule 8); SHANNON approved the six pipeline changes on
2026-10-31, this record fixes the contracts they introduce. Tasks: PIPE-003, SPIRE-002.

## Decision

### Kit (`src/kit`, `src/kit-roblox/modules`)

- New games use `SaveStore` + `Saves.start` for player data and `Router` + `Payload` + `RateLimit` +
  `Remotes.create` for client requests. Games 1 to 4 keep their own `Profiles.luau` and
  `Remotes.luau` (fact: they passed QA; migrating them would need new playtests).
- **Save contract** (same as Egg Garden after GARDEN-006): key `player_<UserId>`; store
  `<name>_studio` in Studio, `<name>_staging` on live servers until a production universe id is passed
  (SHANNON approves that, rule 7), then `<name>`. Record = the game's sanitised profile plus
  `lock = { session: string, at: number }`. Lock stale after 120 s. Load claims the lock (3 tries,
  2 s and 4 s apart) or runs offline without writing. Writes: one coalesced `UpdateAsync` at most
  every 7 s while changes are queued, 60 s autosave, a final write on leave and in `BindToClose` that
  clears the lock. A write that finds another session's lock writes nothing and the session goes offline.
- **Remote contract:** `ReplicatedStorage.<Game>Remotes` with `Request` (RemoteFunction,
  `(action: string, ...args) -> (ok: boolean, code: string?)`) and `Fx` (RemoteEvent, server to
  client, display only). Refusal codes: `loading`, `rate`, `unknown`, `payload`, `error`, `refused`,
  or a game code from the handler. Default limit: burst 6, 4 requests per second per player; malformed
  and unknown requests spend tokens.
- Each game still records its own schema fields, actions and economy values in its own decision.

### Build stamp

- `build-info/BuildInfo.txt` is committed as `dev`. CI and `publish.yml` overwrite it before
  `rojo build` with `sha=<40 hex>;time=<UTC>;ref=<git ref>;run=<run id>.<attempt>`.
- Every project maps it to `ReplicatedStorage.BuildInfo` (StringValue), `ServerScriptService.BuildStamp`
  (prints `[Build] <short sha> ...` at server start, sets the Workspace attribute `BuildStamp`) and
  `StarterPlayerScripts.BuildStamp` (corner label `build <short sha>`).

### Publish verification

- Before upload: `tools/check-place.mjs` checks the built file has every node of the project tree,
  at least as many scripts as each mapped folder has `.luau` files, and this commit's stamp.
- After upload: `tools/verify-publish.mjs` runs the same check on the published version through Open
  Cloud Luau execution and fails the run on any mismatch. Needs the scope
  `universe.place.luau-execution-session:write` on the environment's key (SHANNON adds it).
- Optional: with the environment variable `ROBLOX_RESTART_SERVERS=true` and scope `universe:write`,
  the run restarts servers after a verified publish; otherwise the run summary lists it as a manual step.

## Why

- Fact: the Bake Rush staging publish returned version 5 but SHANNON saw a baseplate (handoff
  2026-10-24). A green run did not prove the right build was live, so every playtest needed manual
  checks. The stamp and both checks make "which build is this?" a CI answer.
- Fact: games 2 to 4 each copied and adapted the previous game's Profiles and Remotes, and each copy
  needed its own QA round (GARDEN-006, NIGHT-006 found save and remote issues). A tested shared module
  is reviewed once.
- Assumption: Luau execution sessions can read `ServerScriptService` and `ReplicatedStorage` of the
  published version (they run in a server context). To be confirmed by the first verified publish.
- Assumption: the `restartServers` Open Cloud endpoint behaves as documented; it is opt-in and only warns on failure.

## Consequences

- Publishes fail until the key has the Luau execution scope. That is intended: an unverified publish
  is reported as a failure, not as a success.
- A change to a kit module affects every game that uses it: backwards-compatible API, tests first,
  note here.
- Place files now carry two small extra scripts and the kit modules (a few KB).

## Notes

- **2026-11-06 (LANTERN-005), `UiKit` joins the kit.** `src/kit-roblox/modules/UiKit.luau` is Egg Garden's UI kit (architecture garden 6.4) with every Garden dependency injected through `UiKit.configure{ tokens, fonts, icons, sound, short, rarity, species, previews, accent, menu }`. Same widgets, numbers, Reduced Motion and 12 px rules. `eggDisc` stays in Garden. Garden now uses the kit too: `src/garden-client/UiKit.luau` configures it with the Garden theme and adds `eggDisc`, so every Garden caller is unchanged (one copy of the kit, as the studio lessons ask). Additive optional tokens (`CHIP`, `CHIP_TEXT`, `CHIP_LINE`, `RING_FILL`, `ROW_LINE`, `BAR_BACK`, `SILHOUETTE`) default to Garden's old literals; `coinPill.set` takes the income as optional. The older `Ui.luau` stays for the games that use it.
- **2026-11-06 (LANTERN-005), `SaveStore` option `newer`.** `newer: ((record) -> boolean)?`: when it returns true for the stored record at load, the session runs offline on that record sanitised in memory and never claims the lock or writes (no flush, no autosave, no final write), so a save written by a later build survives a rollback. Without the option nothing changes (every earlier `SaveStore.spec` case passes unchanged); `Saves.start` passes it through. Backwards compatible.

## Amendment (2026-11-07, LANTERN-016)

`SaveStore` keeps every change while a session cannot claim the save (a lock still held after a crash, or a DataStore outage), retries the claim every 15 s and once more on leave, and on success re-applies the kept changes to the stored record, so nothing earned is lost. Callers must tell the player that saving is paused and never report a reward as saved while it is only kept. Lantern Express uses this; Egg Garden keeps its own `Profiles` and is unchanged. See decision 0018 amendment 2 and `tests/SaveStore.spec.luau`.

LANTERN-017 (QA r4, r5): when such a session ends (leave or shutdown) before it could claim, `finish` still stores its kept changes in one `UpdateAsync`: a free or stale lock is claimed and released, and a fresh lock of another session (a crashed server's, for up to 120 s) is kept exactly as it was while the changes are re-run on the stored record under it, as any other writer's would be. The holder's next write and the next claim re-read that record, so they keep the changes and never re-run them; only a record from a newer schema is never written. A busy session now plays on the stored record it read instead of defaults, and `reclaim` returns that stored record so a game can show what the session added once it is claimed.
