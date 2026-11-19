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

## The second lion (same day)

- **What was wrong with the first lion:** the first ForgeGUI lion (job 01398b24) looked fractured in game.
  - It was 3,585 loose shards, and about a third of its faces pointed inward (Roblox draws only fronts,
    so those showed as holes).
  - Its texture was a mosaic of about 3,600 tiny pieces, each with its own painted light and dark. At
    Roblox's 1024 texture size their edges blur into cracks.
- **The replacement:** SHANNON made a new one on the ForgeGUI site ("Low poly, Game-ready, Stylized
  roblox lion with NO baseplate", artifact 4fffb41e). It is 2,961 faces, one object, no baseplate, and
  joins into a single closed piece. It replaces the first as `creature_lion_forge`.
- **`tidy` in skin_forge.py:**
  - Joins the vertices ForgeGUI exports loose.
  - Turns each face outwards (rays from both sides).
  - Sets the shading: flat for a low-poly model.
- `Creatures.build` draws a skinned mesh two-sided (`MeshPart.DoubleSided`) in case a thin piece remains.
- ForgeGUI's own animation (the paid route) stays the fallback if this rig is not good enough.

## The jackal and the tortoise (same day)

- SHANNON asked for as many animals as the credits allowed, base animals first, then varieties, then
  enemies, and to see each model before it was rigged.
- Each model at high quality costs 4,000 credits. Three were made (jackal, tortoise, meerkat) before the
  account ran out (3,476 left). The other prompts were not charged.
- SHANNON saw them on a preview page and chose the jackal and the tortoise. The meerkat was left out: its
  dark back bands came out as scattered black triangles in its texture.
- Both are single pieces with no baseplate. Each has its own weights (`jackal_weights`,
  `tortoise_weights` in skin_forge.py, from measured leg and tail columns) and smooth shading.
- The tortoise is thinned to 5,000 triangles. The jackal stays at full detail (14,103): thinned, its
  smooth shading showed dark patches.
- The jackal's faces are not re-turned (`turn: False`): they already face out, and the ray test misread its
  thin ears and neck.
- `StationRules.FORGE` now lists the jackal, the lion and the tortoise. Their varieties keep the Blender
  models.

## The Pharaoh Jackal (same day)

- SHANNON made three more jackals on the ForgeGUI site.
- "anubis jackal" (artifact 4f9138bf) is one jackal: black with purple crystal shards, solid all round, no
  baseplate, 5,130 triangles. SHANNON chose it as the Pharaoh Jackal ("Pharaoh Jackal (Recommended)").
  It replaces the black-and-gold Blender look. Its weights are `anubis_weights`, shading flat (the lion's
  style).
- The other two held three jackals in a row (plain, Pharaoh, Sphinx) in one model: one on rock bases,
  one only an eighth as deep as it is long. Neither can be rigged. They are to be made again one jackal
  per model.
- `StationRules.FORGE` takes a variant's id as well as a species', so a variant can have a ForgeGUI
  model: `pharaoh_jackal` is `creature_jackal_pharaoh_forge`.
- The tortoise's first texture never loaded in Studio (the rainbow coat from the same upload did); a
  second upload loaded.

## Facts

- The sources are in `assets/stations/sources/creature_<animal>_forge.glb`: the lion (ForgeGUI artifact
  4fffb41e), the jackal (job c93507d6) and the tortoise (job bfdcf1b3).
- 2,961 triangles, 1,484 vertices once joined, one piece; one 1024 texture.
