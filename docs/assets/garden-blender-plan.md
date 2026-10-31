# Egg Garden: Blender asset plan

Task `GARDEN-020`. Fifteen custom models: seven eggs, the hatch shell fragment and the Splash Dash
obstacle kit. Scripts live in `tools/blender/garden/` (how to rebuild: its `README.md`); reviewed
files in `assets/garden/`; previews in `build/blender/garden/` (not committed). The upload is a later
step run by the Director, and engineers wire the models in after it. No game code changes here.

## Conventions

Facts:

- 1 Blender unit = 1 stud, origin at the base centre, lowest point at y = 0.
- One baked 1024 PNG per asset, one smart UV atlas. Glowing pieces are a separate `<asset>_glow` mesh
  that code sets to Neon; moving pieces are a separate mesh (`dash_sweeper_arm`,
  `dash_pendulum_hammer`).
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

Target about 2.2 x 3 x 2.2 studs (today's `Plots.egg` size), budget 800-2.5k tris.

| Asset | Silhouette and theme | Glow mesh |
|---|---|---|
| `egg_starter` | Speckled shell with a zigzag crack; the lid sits ajar over a warm yolk, a leaf sprout on top | none |
| `egg_meadow` | Grass skirt round the waist, daisy crown, flowers on stems, a fat ladybug on the shell | none |
| `egg_forest` | Reads as an acorn: bumpy cap and stem over a bark shell, moss dripping from the cap, red mushrooms at the foot | none |
| `egg_sunset` | A sun on top with a collar of wedge rays, tapered beams down an orange-pink shell, wind-stroke clouds in relief, a cloud nest at the base | none |
| `egg_moon` | Deep blue cratered shell cradled in a big crescent, stars on the horns and shell | stars |
| `egg_star` | Cut gold gem with wide crystal points; star-shaped pockets, front and back, show the glowing core | core |
| `egg_celestial` | New top tier, deliberately larger: a pearl and gold Faberge egg on a pedestal with a blue enamel band, feathered gold-tipped wings, a tilted orbit ring with moons | halo, constellations, moonlets, crown star |

`egg_shell_fragment` is one curved shard with a zigzag break, under 200 tris. It uploads without a
texture so code can tint it per egg from `EGG_COLOURS`.

## Splash Dash kit

Same toy style. Budget 500-3k tris, `dash_island` up to 5k.

| Asset | Size target (studs) | Use |
|---|---|---|
| `dash_sweeper` | arm 24 long | Post, plus `dash_sweeper_arm`, symmetric, so its bounding box centre is the spin axis |
| `dash_ball` | 12 across | Spotted ball with raised dots on all sides; roll it as a Ball part with the mesh welded |
| `dash_pendulum` | 19 tall, 22 span | Gantry, plus `dash_pendulum_hammer` swinging along X from the axle at the top of its mesh |
| `dash_platform` | 16 across | Flower with a flat walkable top; use an invisible cylinder for collision |
| `dash_arch` | 28 x 21 | Rainbow balloon arch with a blank board for START, CHECKPOINT or FINISH; tint `dash_arch_glow` per role |
| `dash_ready_pad` | 14 across | Plaza pad with chevrons and a flower; sign post with a blank board facing front |
| `dash_island` | 80 x 80 | Floating garden island, flat grass 30 studs above the lowest rock, decoration on the rim, pond and waterfall at the front |

Measured sizes and tris are in `tools/blender/garden/manifest.json`, and each entry's `notes` say how
to wire it.
