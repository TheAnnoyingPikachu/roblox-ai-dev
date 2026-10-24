# Studio operating rules for Claude threads

This repo is the single source of truth for the AI Roblox studio. Chat is not. Read this
before changing anything.

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

## Commands

```
rokit install                 # install pinned tools
lune run tests/run            # unit tests, writes test-results.json
stylua src tests              # format
selene src tests              # lint
rojo build -o build/place.rbxl
rojo serve                    # live-sync into Studio
node tools/validate-tasks.mjs # task file check
```

## Adding a test

Create `tests/<Module>.spec.luau` and register it in `SPECS` in `tests/run.luau`. The runner
fails if a spec file exists but is not registered.
