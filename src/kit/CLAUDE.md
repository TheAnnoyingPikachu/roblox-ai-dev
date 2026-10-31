# Kit: reusable building blocks (decision 0011)

Use these in every new game instead of copying another game's `Profiles.luau` or `Remotes.luau`.

| Module | Use it for | Tested in |
|---|---|---|
| `SaveStore` | Session-locked, coalesced saves. Inject `defaults`, `sanitize`, `snapshot`. | `tests/SaveStore.spec.luau` |
| `SaveLock` | The lock on a stored record (`canClaim`, `holds`, `stamp`). | `tests/SaveStore.spec.luau` |
| `Router` | Server request routing: loading, rate, unknown, payload, handler, in that order. | `tests/Kit.spec.luau` |
| `Payload` | Argument validators: `string`, `int`, `number`, `boolean`, `enum`, `optional`, `check`. | `tests/Kit.spec.luau` |
| `RateLimit` | Token buckets per player (`new`, `every`, `take`, `reset`). | `tests/Kit.spec.luau` |
| `Format` | Text players see: `short` (1.2K), `commas`, `clock`, `ago`, `plural`. | `tests/Kit.spec.luau` |
| `BuildStamp` | Parse and print the build stamp. | `tests/Kit.spec.luau` |

Roblox adapters in `src/kit-roblox/modules` (not unit-tested, keep them thin):
`Saves.start{...}` (DataStore, PlayerRemoving, BindToClose, 1 Hz flush), `Remotes.create(name, router)`,
`Ui` (screen, panel, label, button, toast, `setTheme`).

Rules:
- Everything in `src/kit` is pure: no Roblox globals (`Purity.spec` enforces it). Services are injected.
- A change to a kit module changes every game that uses it: keep the API backwards compatible,
  add a test for the new behaviour, and note it in decision 0011.
- Changes passed to `SaveStore.apply` must be pure and capture their own inputs; they run twice.
- Game rules stay in `src/shared`; the kit holds mechanisms, never game values.
