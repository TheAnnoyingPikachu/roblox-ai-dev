# Animal Stations: rolling back a bad update

What to do when a published update breaks the game (decision 0121, answer 35). Publishing still needs
SHANNON's approval (CLAUDE.md rule 7); this says what to publish.

## The one rule: roll forward, never back past a save version

- Fact: every save carries `StationProgress.VERSION`. A server whose VERSION is lower than a save's never loads
  or writes that save; it kicks the player with "A new update is out" (`tooNew`, decision 0111).
- So publishing an older build would lock out everyone who played the newer one. Never publish an old commit or
  an old place version from the Creator Hub's version history once the bad update raised VERSION.
- A rollback is a new commit on main that undoes the bad change and keeps VERSION where it is (or raises it).

## Steps

1. **Stop the damage.** If players are losing progress, SHANNON shuts the servers down from Creator Hub >
   the experience > Servers. Saves already written stay as they are.
2. **Find the change.** `git log --oneline origin/main` and the publish run's build stamp (corner label
   `build <sha>`, or `[Build] <sha>` in the F9 server log).
3. **Undo it on a branch.** `git revert <sha>` for the bad squash commit. If the revert would lower
   `StationProgress.VERSION`, put VERSION back to the newest number by hand. If it removes content (a species,
   egg, coat, upgrade or station), don't remove it: keep the ids in `StationConfig` so saves holding them stay
   valid, and hide them instead.
4. **Check.** `lune run tests/run` (the content-version test fails if VERSION and content disagree), a pull
   request, CI green.
5. **Publish** with the Publish workflow to the same environment, after SHANNON approves.
6. **Restart servers** so nobody stays on the bad build: the workflow does it when `ROBLOX_RESTART_SERVERS` is
   `true`, otherwise Creator Hub > Servers > restart.
7. **Write it down** in the task of the fix: what broke, the build stamps before and after, and whether any save
   needs repair.

## Repairing saves

- Never edit a player's save by hand or by script without SHANNON's approval (rule 7: migrating player data).
- Saves are in the DataStore `StationsProfile` (plus `_staging` until a production universe id is set), key
  `player_<UserId>`. Trades in `StationsTrades`, same key.
- A repair is code: a `sanitize` change that fixes the bad field on load, shipped like any other update.
