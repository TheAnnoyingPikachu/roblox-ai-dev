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
