# 0102: Animal Stations: whole ForgeGUI models, skinned to our rig

Status: accepted (SHANNON, 2026-11-19: "try forge gui auto rig ... just do it for the lion for now", then
"go ahead with your idea"); built by STATION-109.
Date: 2026-11-19. Task STATION-109.

## Context

- SHANNON wants the ForgeGUI lion working in game without the model being cut into pieces in Blender.
- **ForgeGUI's auto-rig was tried first** (one paid rig call, job 6dabe42b). Its 3D provider (Meshy) only
  rigs humanoids:
  - It put a human skeleton (hips, spine, arms, two legs) into the lion, with one "thigh" bone moving 35%
    of the mesh.
  - Its clips are human (walking_man, slash, shoot, climb).
  - Its file carried a stray "Icosphere" object.
  - It is not usable for a four-legged animal.

## What

- The ForgeGUI model stays one whole mesh, every face where ForgeGUI made it.
  `tools/blender/stations/skin_forge.py` adds a skeleton with our joints' names (`body` the root, `head`,
  `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`, `tail`), each bone standing where that piece turns.
- **The skin:**
  - Each vertex's weights come from where it is, blending across a band at each joint, so long pieces
    (the torso, the tail, the legs) bend there.
  - A small loose island (the faceted mane's shards, under 0.06 of the model's size) takes its average
    weights, so it moves whole and never stretches.
  - Checked in Blender renders of bent poses.
- **In game:**
  - The asset is marked `skinned` (with `root`, where its `body` bone stands).
  - `Creatures.build` welds the one mesh to the Root and makes no Motor6Ds.
  - `Creatures.client` drives the bones' `Transform` with the same poses it gives Motor6Ds, turned from
    the Root's axes into each bone's. So every clip, the fight timings, hit-stop and slow motion work
    unchanged.
  - The feet-on-the-ground correction works only on jointed models; a skinned model goes without it.
- The asset is `creature_lion_forge`: the ForgeGUI (Meshy) lion, scaled to the old lion's length (13
  studs). It has its own rainbow coat. Once it was checked in Studio it became the lion
  (`StationRules.assetOf`); the old jointed `creature_lion` stays uploaded as the fallback.

## Facts

- The source is in `assets/stations/sources/creature_lion_forge.glb` (ForgeGUI job 01398b24, Meshy).
- 10,210 triangles, one 1024 texture, 3,585 islands, 2,670 of them moving whole.
