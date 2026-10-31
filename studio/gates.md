# Release gates

A failed mandatory gate stops progression. No agent can waive a gate; only fixing the cause or
removing the feature clears it.

| # | Gate | Type | Passes when | Enforced by |
|---|------|------|-------------|-------------|
| 1 | Merge | Automatic | Secret scan, task schema, task scope, StyLua, Selene, Lune tests (incl. purity), Rojo build, place check and tool tests pass; reviewed by a non-author | `ci.yml`, branch protection |
| 2 | Release candidate | Automatic | `v*` tag on main builds with the commit's build stamp; the file passes the place check before upload; manifest records commit, stamp, artifact hash, test counts | `publish.yml` |
| 3 | Staging | Automatic + check | Candidate publishes to the staging experience (separate DataStores); the published version passes the post-publish verification (stamp and scripts, via Open Cloud Luau execution); servers restarted | `publish.yml` (staging) |
| 4 | Playtest | Human | SHANNON or testers confirm the core loop on PC and mobile in staging | Decision card + note in `release/` |
| 5 | Production | Human | SHANNON approves the production environment run for the same tag | GitHub environment reviewers |

Always human-approved, regardless of gate: spending money, paid products, credential or
permission changes, player-data migrations.

## Milestone checkpoints

Human approvals are batched: one checkpoint per milestone, with every pending decision listed and a
recommendation for each (CLAUDE.md, "Milestone checkpoints"). Gates 4 and 5, design decisions and
the greybox feel gate are asked at their checkpoint, never skipped. Irreversible steps (publish,
spend, credentials, data migration) wait for the checkpoint answer; reversible work continues on the
recommended option.

## Not yet automated (planned)

- Luau strict type check with luau-lsp (M1)
- In-engine and multiplayer tests in Studio or via Open Cloud Luau execution (M3)
- Gameplay smoke test after publish (M4). The post-publish check verifies the build, not the game loop.
