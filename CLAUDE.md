# Studio operating rules for Claude threads

This repo is the single source of truth for the AI Roblox studio. Chat is not. Read this
before changing anything.

## Read first, in this order (and stop there)

1. This file.
2. Your task file in `studio/tasks/`: its `files` are the only files you change, its `tests` are the specs that must pass.
3. `docs/architecture/README.md` (one page) and the game's own `CLAUDE.md` (`src/<game>/CLAUDE.md`).
4. Only the doc sections the task's `inputs` name. Do not read whole GDDs or architecture docs.

## Rules

1. Every change belongs to a task in `studio/tasks/`. Create or update the task file in the same PR.
2. No thread approves its own critical work. Implementation PRs are reviewed by a separate QA thread; CI is the hard gate.
3. No task is `accepted` without evidence (CI run link, test-results.json, playtest notes).
4. Server is authoritative. Clients send requests only; never accept amounts, prices, rewards or outcomes from a client.
5. Game rules live in pure modules in `src/shared/` with no Roblox API calls, so they are unit-tested by Lune.
6. Never put secrets in code, prompts, memory, logs or chat. Credentials live only in GitHub environment secrets.
7. Never publish, spend money, change credentials or migrate player data without SHANNON's approval.
8. Changes to economy values, remote contracts or data schemas need a decision record in `docs/decisions/`.
9. External assets need an entry in `docs/assets/register.md` before use. Default to primitives and Roblox-owned assets.
10. Label facts, assumptions and hypotheses separately in design and research docs.
11. Tasks are scoped. A new task names its exact `files` (paths or globs) and the `tests` that must
    pass; CI fails a PR that changes a file outside the files of the tasks it changes. Keep a task
    to one PR and roughly ten files; split bigger work. See `studio/TASKS.md`.
12. New games use the kit (`src/kit`, `src/kit-roblox/modules`) for saves, remotes, rate limits and
    UI instead of copying another game's `Profiles.luau` or `Remotes.luau` (decision 0011).
13. A playtest note or staging check only counts when it records the build stamp it saw
    (corner label `build <sha>`, or the `[Build] <sha>` line in the F9 server log).
14. Batch SHANNON's approvals into one checkpoint per milestone (see below). Do not ask as things
    come up.

## Milestone checkpoints (approval batching)

SHANNON reviews once per milestone, not once per question.

- While a milestone runs, write each decision that needs SHANNON into that milestone's checkpoint
  list in the task file of the milestone's last task (`notes`, or a `docs/checkpoints/<GAME>-<M>.md`
  file for long lists), with your recommendation and what happens if it is rejected.
- Keep working on the recommended option when it can be undone (branches, PRs, docs, staging-only
  code). Never act early on something that cannot: publishing, spending, credentials, player-data
  migration, anything public (rule 7 still applies, it is just asked at the checkpoint).
- At the end of the milestone, ask once: one decision card, or one doc with every item, each with a
  recommended option. Include the evidence the milestone produced (CI run, test counts, build stamp).
- Ask straight away only for: a security or data-loss risk, a production incident, or a block where
  every way forward is irreversible.
- Gates do not change: SHANNON's approval on design decisions, the greybox feel gate before art,
  staging before production. They are simply asked at their checkpoint.

## Commands

```
rokit install                 # install pinned tools
lune run tests/run            # unit tests, writes test-results.json
lune run tests/run Kit Save   # only specs whose file name contains Kit or Save (fast loop; CI runs all)
stylua src tests              # format
selene src tests              # lint
rojo build -o build/place.rbxl
rojo serve                    # live-sync into Studio
node tools/validate-tasks.mjs # task file check
node tools/check-scope.mjs origin/main                            # PR stays inside its tasks' files
node tools/check-place.mjs garden.project.json build/garden.rbxl  # built place has every node and script
node --test tools/place-check/place-check.test.mjs                # tool tests
```

## Adding a test

Create `tests/<Module>.spec.luau` and register it in `SPECS` in `tests/run.luau`. The runner
fails if a spec file exists but is not registered.
