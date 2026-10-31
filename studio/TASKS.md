# Writing a task a thread can finish without re-reading the repo

A good task lets a thread open four things (CLAUDE.md, the task, the one-page architecture, the
game's CLAUDE.md) and start work. Every task not in `studio/legacy-unscoped.txt` needs:

| Field | Write |
|---|---|
| `objective` | One outcome, one PR. If it says "and" three times, split it. |
| `inputs` | Doc **sections**, not whole docs: `docs/architecture/garden.md §4.2`, not `garden.md`. |
| `files` | Every file the PR may change: paths or globs (`src/kit/*.luau`, `src/spire/**`, `docs/qa/` for a folder). Roughly ten files at most. CI fails changes outside the list (`tools/check-scope.mjs`). The task file itself, its specs and `tests/run.luau` are always allowed. |
| `tests` | The spec files that must pass, e.g. `["SaveStore.spec.luau"]`. Run them alone with `lune run tests/run SaveStore`. `[]` only for docs-only tasks. Once the task is `in_review` they must exist and be registered. |
| `acceptance_criteria` | Checkable statements. Name the test or command that proves each one. |
| `verification` | Who or what checks it: CI, a QA thread, a playtest note with the build stamp. |

Example:

```json
{
  "task_id": "SPIRE-004",
  "files": ["src/shared/Spire*.luau", "src/shared/TowerRules.luau", "src/shared/PlazaRules.luau", "src/shared/MarketRules.luau"],
  "tests": ["TowerRules.spec.luau", "PlazaRules.spec.luau", "SpireBalance.spec.luau"]
}
```

When a task turns out to need a file it does not list, add the file to `files` in the same PR and
say why in `notes`; the reviewer sees the scope change in the diff.
