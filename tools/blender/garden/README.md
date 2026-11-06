# Egg Garden: Blender assets

Procedural Blender Python models for the eggs and the Splash Dash kit (plan:
`docs/assets/garden-blender-plan.md`, task `studio/tasks/GARDEN-020.json`). The game reads them
through `src/shared/GardenAssets.luau`; until the ids are uploaded every asset there is nil and the
game keeps its part-built fallbacks.

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
  bands), egg-shell helpers (`shell`, `stick`, `ridge`), toy parts (`flower`, `star`, `leaf`,
  `mushroom`, `facet`) and the creature standard below.
- `build.py`: runner, manifest, contact sheet. `lineup.py`: the lineup render. `compare.py`: the
  before/after creature sheet. `refcompare.py`: the reference-vs-remake sheet (below).
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
- The model contract is `docs/architecture/garden.md` section 9 (on branch `garden/v2` until it
  merges): names, sizes and how code places each model. `tests/GardenAssets.spec.luau` pins it.
- **Pivots are not kept.** `loadNight` rebuilds each asset into a new Model whose pivot is its
  bounding box centre, and `DashFx` moves the whole Model. So moving pieces are one mesh, nothing
  static goes in them, and the bounding box centre is where code expects it: the hub on all three
  axes for `dash_sweeper`; for `dash_pendulum`, the hinge is the top face centre and the Model hangs
  half its height below it.
- **Eggs are one mesh** of about 2.2 x 3 x 2.2 and at most 2.8 wide, because `Models.nightPart` keeps
  a single MeshPart and destroys the rest, and the v0.2 cart spaces eggs 2.8 apart. `fit` in
  `assets/eggs.py` enforces the size. Their glowing pieces are baked bright, not Neon.

## Creature standard (HD pass)

Every `creature_*` is remade to this so all 26 look like one family. The reference builds are
`creature_bunny` and `creature_fox` in `assets/creatures_a.py` (remade from Roblox AI references,
see "Reference remakes" below), and `creature_dragon` for a winged species: read them first, copy
their shape. Helper docstrings in `kit.py` have the details.

### Helpers

| Use | For |
|---|---|
| `k.fuse(elements, skin, tris=2600..3400)` | Head, body, snout, arms, feet, ears and fused tail as **one** smooth metaball shape. Elements: `(loc, r, scale, rot)` ellipsoids (r = visible radius) and `("capsule", a, b, r)`; `k.pair(...)` mirrors one through x = 0. Never stack separate spheres for the body: hard intersections and hidden insides are what made v0.5 look cheap. |
| `k.face(body, head_centre, R, skin=...)` | Eyes, blush, nose and mouth, cast onto the real surface so nothing floats. R = the head's radius. Marks the face for 2x texels. |
| `k.lens(target, centre, direction, r, mat, scale, thick, sink, up)` | Anything set into a surface: inner ears, nostrils, belly patches and plates, spots. |
| `k.mouth(target, centre, direction, half_width, mat, kind)` | A mouth on a snout (`face(..., mouth_kind=None)`). |
| `k.capsule(a, b, ra, rb, mat)` | Separate horns, stems, limbs: rounded ends; small `rb` is a soft point. |
| `k.blob(r, loc, mat)` | Separate round pieces in another colour (tail puffs, buds). |
| `k.leaf(..., n=8, steps=10)` | Petals, wings, leaves. |
| `k.texel(parts, 0.5)` | Big plain parts (wings, petals, shells) get half the texels so the face gets more. |
| `k.paint(..., rest=True)` + `k.zone(m, rgb, centre, radii, soft, jag)` | Fur markings painted on the one fused body: white muzzles and cheek ruffs, bibs, dark paws and ear tips, tail tips. A zone is a soft-edged ellipsoid in build-time coordinates (`fuse` stores them as the `rest` attribute, so `fit` cannot move the paint); `jag` 0.2 gives a tufted fur edge. No triangles, no seams: prefer it to `k.lens` for anything flat. |

Banned on creatures: `k.cyl` cones, spheres under 20 segments, `tube`/`leaf` with `n` under 8
(except hair-thin veins), separate googly eyes.

### Shape and face rules (R = head radius)

- **Proportions:** head at least as wide as the body, about half the height without ears and
  horns. Chubby, round seat, body narrower than the head.
- **Eyes:** the `face` defaults: a dark glossy dome (`EYE_INK`), 0.24 R half height, 0.8 as wide,
  34 degrees each side of the front, 6 below the head's middle (wide apart and low: big forehead).
  **No white of the eye.** Big catchlight at the viewer's upper left, small one lower right, the
  same on both eyes (one light for the family): never mirror them. Only `iris` may change colour,
  and only to another very dark tone.
- **Snouted species** (dragon, fox, lion, pup, deer, kirin, otter...): eyes just above the snout
  line, `eye_phi=6..10, spread=36`; `nose=None, mouth_kind=None`, then nostrils as `k.lens` and the
  mouth as `k.mouth(body, snout_centre, k.outward(0, -32), ...)` on the snout.
- **Mouth:** `"w"` for small-muzzle animals, `"smile"` on snouts, `"o"` only for a surprised species.
- **Blush:** always: ovals at 54 degrees round, 25 below, the skin mixed 55% to `BLUSH_PINK`.
- **Nose:** small (0.075 R), pink on pale fur, `NOSE` plum on dark fur.
- **Ears:** fuse elements tilted 10 to 20 degrees outwards. Long ears `scale (0.4, 0.2, 1.0)`,
  round ears a ball about 0.3 R, pointed ears `(0.5, 0.25, 1.0)`. Inner ear: `k.lens` on the ear's
  front, `scale=(0.34, 1)`, `thick=0.2, sink=0.6, up=` the ear's axis.
- **Paws:** fused flat beans, `k.pair((x, y, 0.2), 0.3, (0.9, 1.45, 0.62))`, resting on z = 0;
  arms are small stubs at the sides (r 0.17 to 0.26). No toes, fingers or claws.
- **Tails:** a fused capsule chain with short segments (about 4 per stud, or a thin tip turns into
  beads), or a separate `k.blob` puff in a second colour.
- **Colour:** one `k.paint` gradient for the skin, darker at the bottom; pastel palette as before.
  Markings that must sit in an exact place are geometry (`k.lens`), not `paint` marks: `fit`
  scales the model after the paint coordinates are fixed.

### Reference remakes (match the Roblox AI references)

The owner prefers the Roblox AI look (`docs/production/ai-reference-pipeline.md`). Remake each
creature from its `assets/garden/refs/<id>_*.jpg` shots; these override the defaults above:

- **Head 55 to 60% of the height** with ears, wider than tall (`scale` about `(1.1..1.4, 0.9, 0.9..1.0)`);
  a small pear or bean body, chunky stubs. For width, add a `k.pair` of cheek elements low on the head.
- **Face:** `k.face(..., eye_r=0.24..0.27, eye_wide=0.9, spread=29..31, eye_phi=-12..-24, sheen=True,
  blush_theta=44..46, blush_phi=-24..-34, mouth_w=0.1..0.12, nose_r=0.06..0.1)`: eyes big, round,
  low and wide, the nose at eye level, the mouth just under it. The references have almost no
  snout, so use the plain face (nose and mouth on the head), not `snout_face`.
- **Paint the body with `rest=True`:** `face` then paints the blush as a soft zone (the plush look)
  instead of a lens, and every marking is a `k.zone`. `skin` is the colour under the blush.
- **Workflow:** build, then `... --python tools/blender/garden/refcompare.py -- frog duck` and open
  `build/blender/garden/refcompare/<id>_vs_ref.png`: each Studio shot over a render from the same
  camera (70 degree field of view, same offsets, scaled to the reference height), so a part that
  looks smaller in the remake is smaller. Repeat until they read as the same character. Set the
  `ASSETS` size to the model's own proportions (an even `fit scale` on all three axes), keeping
  the height. The frog to cat references came out turned 45 degrees towards +X, so their "34"
  shot is the true front; `TURN` in refcompare.py records each reference's turn.

### Budget, texture, export

- **Triangles:** `k.CREATURE_BUDGET` = 6,000; aim 4,500 to 6,000 (fuse 2,600 to 3,400, face about
  600, props the rest). Stay under it: `finalize` silently decimates anything over. At 120
  creatures that is at most 720k triangles before Roblox's automatic MeshPart LOD, which drops
  distant ones; do not go higher.
- **Bake:** `finalize=k.HD` in the `ASSETS` entry: 192-sample AO blurred 0.8 texels, AO floor 0.35
  (`col * (0.35 + 0.65 ao)`), a baked top light (crown lighter, belly and feet darker), 6 px gaps
  between UV islands, 10 px bake margin, texel weights (face 2x). Night keeps its defaults.
- **Texture:** one 1024 PNG. Roblox scales uploaded images down to 1024, so a 2048 bake gains
  nothing in game; the face gets more texels from the weights instead. Bunny: face 205 px per stud
  (old 127), dragon 82 (old 74); at 10 studs a 1080p screen shows about 77 px per stud. Below
  that, mark more plain parts 0.5.
- **Export:** `export_assets.py` keeps creature and egg textures full RGB (500 to 750 KB); the
  palette dithered the soft AO into grain.

### Checklist before committing a creature

1. `ASSETS` entry: `budget=k.CREATURE_BUDGET, finalize=k.HD`; same name and target size; front -Y,
   one mesh (`fit` and `finalize` keep origin and size).
2. Build it alone: `... --python tools/blender/garden/build.py -- creature_<id>`. One Blender at a
   time on a shared machine (memory). The log must show tris under 6,000 and a `fit scale` within
   about 0.9 to 1.2 on every axis: a bigger stretch squashes the round shapes, so move the shapes.
3. `... --python tools/blender/garden/compare.py -- creature_<id>` and open
   `build/blender/garden/hd_compare.png` (old close up, new close up, new back, old and new at 20
   studs as a player sees them). At 20 studs: both eyes and both catchlights read, blush and mouth
   visible. Close up: nothing floats or pokes through, no facets on the silhouette, no beads on
   tails, no dark seams. The back is as finished as the front.
4. `python tools/blender/garden/export_assets.py creature_<id>`.
5. Commit the assets file, `manifest.json` (only your entries should change) and
   `assets/garden/creature_<id>.fbx` and `.png`.

## Glow meshes

`dash_arch_glow` is the only glow mesh: it stays untextured and code sets it to Neon, tinted per
role (default colour under `glow` in `manifest.json`, 120, 255, 190). `GardenAssets.luau` keeps the
NightAssets shape, so it does not carry that colour.

`egg_shell_fragment` uploads without a texture, so code can tint it per egg from `EGG_COLOURS`.

## Export, upload, wire

1. `python tools/blender/garden/export_assets.py` copies each FBX and PNG into `assets/garden/`
   (committed): full RGB for `creature_*` and `egg_*`, a 256-colour palette for the rest. Needs
   Pillow.
2. After merge, the Director runs the **Upload Blender assets** workflow with `game: garden`. It
   publishes `tools/blender/garden/uploaded.json` and `src/shared/GardenAssets.luau` as the artifact.
3. Commit both (or run `node tools/blender/write-assets-module.mjs garden`), fill the ids in
   `docs/assets/register.md`, open a PR.
