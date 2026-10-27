# Hundred Demon Night: Blender assets

Procedural Blender Python models for every Night visual asset (plan:
`docs/assets/night-blender-plan.md`, tasks `studio/tasks/NIGHT-007.json` and `NIGHT-008.json`).
The game reads them through `src/shared/NightAssets.luau`; until the ids are uploaded every
asset there is nil and the game keeps its older visuals.

## Rebuild everything (one command)

PowerShell, from the repo root:

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/night/build.py
```

Rebuild only some assets by naming them after `--`:

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/night/build.py -- shrine_hall wisp
```

A full build takes about 3 minutes on CPU. It exits non-zero if any asset fails.

## Outputs (not committed; `build/` is ignored)

- `build/blender/night/<asset>.fbx`: mesh(es), 1 unit = 1 stud, Y up, front = Roblox -Z,
  origin at the base centre (lowest point y = 0).
- `build/blender/night/<asset>.png`: 1024 baked colour texture (material colour x baked AO, plus
  emission) for the MeshPart `TextureID`.
- `build/blender/night/previews/<asset>.png`: Eevee 3/4 preview on a ground disc.
- `build/blender/night/contact_sheet.png`: all previews in one image.

`manifest.json` (committed, rewritten by each build) lists per asset: fbx, png, preview,
measured `size_studs` (Roblox x, y, z), `tris` and per-part tris, target size, budget, priority,
the code it replaces and wiring notes.

## Layout

- `kit.py`: palette, materials, primitives (box, cyl, lathe, tube, surface, poly, hip_roof, rope,
  shide, booleans) and `finalize` (join, decimate to budget, centre, UV, bake, export, preview).
- `build.py`: runner, manifest and contact sheet.
- `assets/*.py`: one file per asset family; each defines `ASSETS = [dict(name, build, budget,
  size, priority, order, replaces, notes)]`. `build()` returns a list of objects, or a dict of
  part name to objects for multi-mesh assets (e.g. `demon_gate_glow`, `katana_blade`).

## Export, upload, wire (after a rebuild)

1. `python tools/blender/night/export_assets.py` copies each FBX and a 256-colour PNG into
   `assets/night/` (committed; about 20 MB). Commit them with the script changes.
2. After merge, the Director runs the **Upload Night assets** workflow
   (`.github/workflows/upload-assets.yml`, environment `assets`: secret `ROBLOX_API_KEY`,
   variable `ROBLOX_CREATOR_USER_ID`). It uploads every FBX as a Model and every PNG as a Decal
   with `upload-assets.mjs`, polls each operation, resolves the decal's image id, and publishes
   `uploaded.json` and `NightAssets.luau` as the run artifact. CI uploads the committed files, not
   a fresh Blender build, so it ships exactly what was reviewed.
3. Copy both files into the repo (or run `node tools/blender/night/write-assets-module.mjs`
   with the `uploaded.json`), fill the asset ids in `docs/assets/register.md`, open a PR.

## How the game uses them

- `Models.night(name, parent, base, yaw?, scale?)` (`src/relay/Models.luau`) loads the Model with
  `InsertService:LoadAsset` (the creator must own the experience), applies the texture to every
  mesh except `*_blade` / `*_glow`, scales it uniformly to the manifest height and places it with
  its lowest point on `base.Y`. It returns nil while the id is nil, and callers keep their old
  meshes or parts. `Models.preloadNight` loads all in the background; `slash_arc`, `demon_wing`
  and `wisp` are also copied to `ReplicatedStorage.NightModels` for client VFX.
- Stage and bridges keep their part collision (made invisible); blades stay separate, Neon and
  tinted by the Blade Art; masks are scaled 0.72 to fit the head.

## Upload notes

- FBX uploads as assetType `Model` (a package of MeshParts); assetType `Mesh` only accepts
  Roblox mesh data, not FBX.
- Roblox recentres a MeshPart on its bounding box; `Models.night` places by the bounding box, so
  nothing sinks into the ground.
- Every uploaded mesh and texture needs a `docs/assets/register.md` row before use (CLAUDE.md rule 9).
- VFX meshes (`slash_arc`, `demon_wing`) are uploaded untextured and tinted by code; weapon
  blades and the gate glow are separate meshes left untextured.
