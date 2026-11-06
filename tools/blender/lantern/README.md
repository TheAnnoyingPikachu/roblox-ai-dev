# Lantern Express: Blender assets

Procedural Blender Python models for Lantern Express (game 6). The look is
`docs/game-design/game6-art-bible.md`; names, sizes and how code uses each asset are
`docs/architecture/lantern.md` section 9. The game reads them through `src/shared/LanternAssets.luau`
(LANTERN-011); until the ids are uploaded every asset there is nil and the game keeps its part
fallbacks.

## Build (one Blender at a time: memory is tight)

PowerShell, from the repo root:

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/lantern/build.py
```

Name assets after `--` to rebuild only those (skips the style test):

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/lantern/build.py -- train_engine critter_emberkit
```

The other scripts run the same way: `style_test.py` (the dusk thumbnail render) and
`compare.py -- <asset> [...]` (the HD check sheet).

## Outputs (`build/` is ignored)

- `build/blender/lantern/<asset>.fbx` and `.png`: meshes and the 1024 baked colour texture.
- `build/blender/lantern/previews/<asset>.png` (dusk preview, glow parts lit) and `contact_sheet.png`.
- `build/blender/lantern/style_test.png`: the three style-test assets together under the art bible's
  dusk lighting, framed as a 16:9 thumbnail, rendered from the exported files.
- `build/blender/lantern/hd_compare.png`: from `compare.py`: old (committed) and new close up, new
  from behind, old and new at 20 studs as a 1080p player sees them.

`manifest.json` (committed, rewritten by each build) holds measured `size_studs` (Roblox x, y, z),
`tris`, per-part tris, `glow` Neon colours, budget and notes.

## Layout

- `kit.py`: imports the Garden kit (which imports the Night kit), so every Garden and Night helper is
  `k.<name>`: primitives (`box`, `cyl`, `lathe`, `tube`, `surface`, `poly`, `ring`, `displace`), `paint`,
  the HD creature standard (`fuse`, `face`, `eye`, `lens`, `mouth`, `capsule`, `blob`, `texel`,
  `CREATURE_BUDGET`, `HD`) and `finalize`. Adds the art bible palette, `hull` (convex wedges),
  `brick` (baked brick bond for flat or round walls), `brass`, and the dusk preview.
- `build.py`: runner, manifest, contact sheet; warns when an asset is over budget **before**
  finalize, because finalize then silently decimates everything, eyes included.
- `assets/*.py`: `ASSETS = [dict(name, build, budget, size, priority, order, replaces, notes, glow,
  finalize=k.HD)]`; `build()` returns a list of objects, or a dict of part name to objects when the
  asset has glow meshes. File owners (architecture section 2): `train.py` LANTERN-008, `tiles.py`
  LANTERN-009, `critters.py` LANTERN-010.

## Conventions (the Garden ones)

- 1 unit = 1 stud; origin at the base centre; **front on Blender -Y** (arrives facing Roblox -Z at
  yaw 0); one baked 1024 full-RGB texture per asset, `finalize=k.HD` (192-sample AO).
- **Glow meshes:** a part named `<asset>_<x>_glow` (or `<asset>_glow`) is left untextured and the
  game sets it to Neon in its `glow` colour from the manifest (`Models.luau` already skips `_glow`
  meshes when texturing). Use them for lantern glass and lit windows on props; critters stay one mesh
  with their lantern baked bright and a PointLight from code.
- Build props at stud scale. Scale critters uniformly after building (`stand` in `critters.py`),
  then swap in the paints that depend on position (`paint` marks, gradients), as Garden's v0.5
  `settle` does. Markings with a clean edge are `paint` marks (a sphere round a point), not
  separate pieces: a separate piece cuts a ragged line through the decimated `fuse` body.
- Critters follow `tools/blender/garden/README.md` "Creature standard (HD pass)" in full, and the
  architecture's bounds: 2.0 to 3.5 tall, footprint within 3 x 3.

## Checklist before committing an asset

1. Build it alone. The log must show no `DECIMATES` line, tris under budget, and a size within
   2% of architecture section 9.
2. Open its preview. Critters: run `compare.py -- critter_<id>` and check the HD standard's step 3
   (both eyes and catchlights at 20 studs, nothing floating, the back finished).
3. Run `style_test.py` when the hero look changes and read `style_test.png`: would a player stop
   scrolling for it?
4. `python tools/blender/lantern/export_assets.py <asset>`, then commit the script,
   `manifest.json` (only your entries) and `assets/lantern/<asset>.fbx` and `.png`.

## Style test (2026-11-06)

`train_engine`, `critter_emberkit` and `house_cottage` (the stop_village house set's style-test
house; not in the upload list on its own: LANTERN-009 builds the 120 x 160 `stop_village` tile from
its build function on a ground plate).
