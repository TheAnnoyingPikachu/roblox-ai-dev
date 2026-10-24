# Release gates

A failed mandatory gate stops progression. No agent can waive a gate; only fixing the cause or
removing the feature clears it.

| # | Gate | Type | Passes when | Enforced by |
|---|------|------|-------------|-------------|
| 1 | Merge | Automatic | Secret scan, task schema, StyLua, Selene, Lune tests and Rojo build pass; reviewed by a non-author | `ci.yml`, branch protection |
| 2 | Release candidate | Automatic | `v*` tag on main builds; manifest records commit, artifact hash, test counts | `publish.yml` |
| 3 | Staging | Automatic + check | Candidate publishes to the staging experience (separate DataStores); smoke test passes | `publish.yml` (staging) |
| 4 | Playtest | Human | SHANNON or testers confirm the core loop on PC and mobile in staging | Decision card + note in `release/` |
| 5 | Production | Human | SHANNON approves the production environment run for the same tag | GitHub environment reviewers |

Always human-approved, regardless of gate: spending money, paid products, credential or
permission changes, player-data migrations.

## Not yet automated (planned)

- Luau strict type check with luau-lsp (M1)
- In-engine and multiplayer tests in Studio or via Open Cloud Luau execution (M3)
- Post-publish version verification and smoke test (M4)
