# Neon Spire: Blender assets

Procedural Blender Python models for the Neon Spire visuals (plan: `docs/assets/spire-blender-plan.md`,
task `studio/tasks/SPIRE-012.json`). Same pipeline as Night (`tools/blender/night/README.md`): the
kit here loads `tools/blender/night/kit.py` and only changes the output folder and the palette.
The game reads the models through `src/shared/SpireAssets.luau`; while an id is nil the game keeps
its current part-built visual.

## Rebuild (one command, PowerShell, repo root)

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/spire/build.py
```

Name assets after `--` to rebuild only those. About 3 minutes on CPU. Then
`python tools/blender/spire/export_assets.py` copies each FBX and a 256-colour PNG into
`assets/spire/` (committed, what CI uploads).

Outputs in `build/blender/spire/` (ignored): `<asset>.fbx/.png`, `previews/<asset>.png`,
`contact_sheet.png`. `manifest.json` (committed) has per asset the measured `size_studs`
(Roblox x, y, z), tris, mesh parts, `glow` colours, budget, priority, what it replaces and notes.

## Neon glow meshes

Every neon piece is a separate mesh `<asset>_glow` (and `_glow2`, `_glow3` for more colours). The
game leaves them untextured and sets them to `Neon` in the manifest colour, so bloom makes them
glow; code may recolour them (department or brand colour). Everything else shares one baked 1024
colour texture.

## Upload and wiring

The **Upload Blender assets** workflow (`.github/workflows/upload-assets.yml`, input `game: spire`)
uploads `assets/spire/` and publishes `tools/blender/spire/uploaded.json` and
`src/shared/SpireAssets.luau` as the run artifact (or run
`node tools/blender/write-assets-module.mjs spire` with the uploaded.json). Fill
`docs/assets/register.md` and open a PR.

In game the server (`SpireServer` calls `Models.preloadSpire`) loads each uploaded Model with
InsertService, applies the texture, sets glow meshes to Neon, fits the manifest height and copies
the template to `ReplicatedStorage.SpireModels`. Server code places them with `Models.spire`;
client views clone them with `Kit.model` (nil until the template exists, so the old visual stays).
