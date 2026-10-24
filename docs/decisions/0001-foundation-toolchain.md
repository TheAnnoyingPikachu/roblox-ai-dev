# 0001: Foundation toolchain

Date: 2026-10-24
Status: Proposed (pending SHANNON's repo setup)

## Decision

- Rojo for filesystem to place sync and builds.
- Luau, strict mode; gameplay rules in pure `src/shared` modules.
- Lune runs unit tests headless in CI, with a dependency-free runner that writes `test-results.json`.
- StyLua and Selene for format and lint; tool versions pinned in `rokit.toml`.
- GitHub Actions for the merge gate and a manual, environment-gated Open Cloud publish.
- Task tracking as JSON files in `studio/tasks/` validated in CI, instead of a separate task database.

## Why

The blueprint asks for a reproducible, auditable pipeline before any agents or games. These are
the standard open-source Roblox tools, run without Studio, and keep every record in Git.

## Consequences

- Headless tests cannot cover DataStores, physics or replication; those need Studio or Open Cloud Luau execution later.
- Some instance types cannot be published through Open Cloud and may need a Studio publish.
