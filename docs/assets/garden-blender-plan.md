# Egg Garden: Blender asset plan

Task `GARDEN-020`. Fifteen custom models: seven eggs, the hatch shell fragment and the Splash Dash
obstacle kit. Scripts live in `tools/blender/garden/` (how to rebuild: its `README.md`); reviewed
files in `assets/garden/`; previews in `build/blender/garden/` (not committed). The upload is a later
step run by the Director, and engineers wire the models in after it. No game code changes here.

## Conventions

Facts:

- 1 Blender unit = 1 stud, origin at the base centre, lowest point at y = 0.
- One baked 1024 PNG per asset, one smart UV atlas.
- Names, sizes and placement follow `docs/architecture/garden.md` section 9 (branch `garden/v2` until
  it merges), pinned by `tests/GardenAssets.spec.luau`.
- Pivots are not kept on import: each asset becomes a Model pivoted at its bounding box centre, and
  `DashFx` moves the whole Model. Moving pieces are one mesh with that centre where code expects it.
- `Models.nightPart` keeps one MeshPart, so eggs are one mesh and their glowing pieces are baked
  bright. `dash_arch_glow` is the only Neon mesh.
- Roblox's FBX importer comes in about 100x too big, so size comes from the manifest.
- NIGHT-010 measured in Studio that Night models, built with their front on Blender +Y, arrive
  facing Roblox +Z at yaw 0.

Assumption, to check on the first upload:

- Garden models put their front on Blender -Y, so by that measurement they arrive facing Roblox -Z,
  the LookVector of an unrotated CFrame, and `yaw = 0` faces forward. If one shows its back, turn it
  180 in code.

## Style

Bright, pastel, toy-like, matching the existing creatures and `src/garden/Plots.luau`. Chunky round
forms, flat clean colour, hard polka dots, no realistic texture. Colours follow `EGG_COLOURS` and
`EGG_LOOKS` so a model and today's card or display egg agree. Players walk round the beds, so every
egg has its silhouette from all sides, not a decal on the front.

## Eggs

Target about 2.2 x 3 x 2.2 studs (today's `Plots.egg` size), at most 2.8 wide for the v0.2 cart,
budget 800-2.5k tris.

| Asset | Silhouette and theme |
|---|---|
| `egg_starter` | Speckled shell with a zigzag crack; the lid sits ajar over a warm yolk, a leaf sprout on top |
| `egg_meadow` | Grass skirt round the waist, daisy crown, flowers on stems, a fat ladybug on the shell |
| `egg_forest` | Reads as an acorn: bumpy cap and stem over a bark shell, moss dripping from the cap, red mushrooms at the foot |
| `egg_sunset` | A sun on top with a collar of wedge rays, tapered beams down an orange-pink shell, wind-stroke clouds in relief, a cloud nest at the base |
| `egg_moon` | Deep blue cratered shell cradled in a big crescent, stars on the horns and shell |
| `egg_star` | Cut gold gem with wide crystal points; star-shaped pockets, front and back, show the bright core |
| `egg_celestial` | New top tier: a pearl and gold Faberge egg on a pedestal with a blue enamel band, gold-tipped wings swept upward, a halo, constellations, a tilted orbit ring with moons |

`egg_shell_fragment` is one curved shard with a zigzag break, under 200 tris. It uploads without a
texture so code can tint it per egg from `EGG_COLOURS`.

## Splash Dash kit

Same toy style. Budget 500-3k tris, `dash_island` up to 5k.

| Asset | Size (studs) | Use |
|---|---|---|
| `dash_sweeper` | 40 long, 12 tall | One mesh, posed whole. Two padded arms on a spindle, mirrored so the hub is the bounding box centre on all three axes; arm along X at angle 0 |
| `dash_ball` | 10 across | Spotted ball with raised dots on all sides; bounding box centre is the ball centre |
| `dash_pendulum` | 30 tall, bob 8 wide | One mesh, posed whole: a padded mallet on a rod. The hinge is the top face centre, the bob centre 26 below it. Its static beam is not in the model |
| `dash_platform` | 12 x 2 x 12 | Flower with a flat walkable top; `CanCollide` true |
| `dash_arch` | 28 x 18, walk-through | Rainbow balloon arch with a blank board for START, CHECKPOINT or FINISH; tint `dash_arch_glow` per role |
| `dash_ready_pad` | 12 wide, low | Plaza pad with chevrons and a flower; a flat part carries the prompt and label |
| `dash_island` | 300 x 160 from above | Floating garden island with a basin for the water plane, long axis X, decoration on the rim under 18 tall, a waterfall at the front. Never walked on |

Measured sizes and tris are in `tools/blender/garden/manifest.json`, and each entry's `notes` say how
to wire it.
