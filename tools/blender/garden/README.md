# Egg Garden: Blender assets

Procedural Blender Python models for the eggs and the Splash Dash kit (plan:
`docs/assets/garden-blender-plan.md`, task `studio/tasks/GARDEN-020.json`). The game reads them
through `src/shared/GardenAssets.luau`; until the ids are uploaded every asset there is nil, and no
game code uses them yet.

## Rebuild everything (one command)

PowerShell, from the repo root:

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/garden/build.py
```

Name assets after `--` to rebuild only those (skips the lineup render):

```
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/garden/build.py -- egg_moon dash_arch
```

Render the lineup alone with `--python tools/blender/garden/lineup.py`.

## Outputs (`build/` is ignored)

- `build/blender/garden/<asset>.fbx` and `.png`: meshes and the 1024 baked colour texture.
- `build/blender/garden/previews/<asset>.png` and `contact_sheet.png`.
- `build/blender/garden/eggs_lineup.png`: all seven eggs, rendered from the exported files.

`manifest.json` (committed, rewritten by each build) holds measured `size_studs` (Roblox x, y, z),
`tris`, per-part tris, `glow` colours, budget and notes.

## Layout

- `kit.py`: imports the Night kit and adds the bright preview, `paint` (gradients, polka dots,
  bands), egg-shell helpers (`shell`, `stick`, `ridge`) and toy parts (`flower`, `star`, `leaf`,
  `mushroom`, `facet`).
- `build.py`: runner, manifest, contact sheet. `lineup.py`: the lineup render.
- `assets/eggs.py`, `assets/dash.py`: `ASSETS = [dict(name, build, budget, size, priority, order,
  replaces, notes, glow)]`. `build()` returns a list of objects, or a dict of part name to objects.

`finalize` silently decimates anything over budget, down to 97% of it, which breaks fine relief.
A count of exactly `budget * 0.97` means it fired: trim the model instead.

## Conventions

- 1 unit = 1 stud; origin at the base centre; one baked 1024 texture per asset.
- **Front is Blender -Y, unlike Night.** NIGHT-010 measured in Studio that a Blender +Y front
  arrives on Roblox +Z at yaw 0, which is why Night needs a half turn. A -Y front arrives on -Z, the
  LookVector of an unrotated CFrame, so `yaw = 0` faces forward. This follows from that measurement
  and has not been seen in Studio for Garden: check it on the first upload.
- Roblox's FBX importer comes in about 100x too big, so size comes from the manifest. Scale each
  model to the manifest height as `Models.night` does. The manifest height is measured, not the
  target, so a tall egg stays taller than a short one.
- Moving pieces are separate meshes: `dash_sweeper_arm` and `dash_pendulum_hammer`.

## Glow meshes

Each `<asset>_glow` mesh stays untextured; code sets it to Neon in the colour under `glow` in
`manifest.json`. `GardenAssets.luau` keeps the NightAssets shape, so it does not carry those colours.

| Mesh | Colour (sRGB) | Notes |
|---|---|---|
| `egg_moon_glow` | 255, 245, 190 | stars |
| `egg_star_glow` | 255, 226, 120 | core, seen through star pockets front and back |
| `egg_celestial_glow` | 255, 214, 110 | halo, constellations, moonlets, crown star |
| `dash_arch_glow` | 120, 255, 190 | strip inside the arch; tint per role |

`egg_shell_fragment` uploads without a texture, so code can tint it per egg from `EGG_COLOURS`.

## Export, upload, wire

1. `python tools/blender/garden/export_assets.py` copies each FBX and a 256-colour PNG into
   `assets/garden/` (committed). Needs Pillow.
2. After merge, the Director runs the **Upload Blender assets** workflow with `game: garden`. It
   publishes `tools/blender/garden/uploaded.json` and `src/shared/GardenAssets.luau` as the artifact.
3. Commit both (or run `node tools/blender/write-assets-module.mjs garden`), fill the ids in
   `docs/assets/register.md`, open a PR.
