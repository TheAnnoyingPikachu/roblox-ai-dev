# Hundred Demon Night: Blender assets

Procedural Blender Python models for every Night visual asset (plan:
`docs/assets/night-blender-plan.md`, task `studio/tasks/NIGHT-007.json`). Nothing here is wired
into the game yet: upload and `Models.luau` / `register.md` changes are a later step.

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

## Upload notes

- Import each FBX with the Roblox 3D importer at stud scale; multi-part FBX become a Model.
- Roblox recentres a MeshPart on its bounding box; `Models.spawn` already places by the bottom
  face, so set `size` in `Models.luau` from `size_studs` in the manifest.
- Every uploaded mesh and texture needs a `docs/assets/register.md` row before use (CLAUDE.md rule 9).
- VFX meshes (`slash_arc`, `demon_wing`) and weapon blades are meant to be used untextured and
  tinted by code.
