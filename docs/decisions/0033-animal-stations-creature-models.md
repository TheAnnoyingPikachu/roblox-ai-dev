# 0033: Animal Stations creature models: dangerous, big, jointed, animated in code

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Adds to 0029 to 0032. Framework: the first two models; sizes are drafts.

## Decision

**The look** (from SHANNON: "make the animals less cute and more badass", "big animals should be
pretty big and their rare varieties should be even larger and cooler looking"):

- Animals are dangerous-looking beasts, not toys: real proportions, a heavy brow over small
  slanted eyes, a grim mouth, big horns, claws, dark skin with darker creases, scars.
- Big animals are big. The Rhino is about 14 studs long with its horn tip 8 studs up (a player
  is about 5 tall).
- A rare version is bigger and cooler than its basic one. The mythic **Lava Rhino** (it replaces
  the Thunder Rhino; its twist is now Strength) is 1.3 times the Rhino, with obsidian skin,
  glowing cracks, molten horns and eyes, rock spikes, a crown of two more horns and a burning tail.
- This replaces the toy look tried first the same day (SHANNON: "no house way, do it the best
  way you can").

**How a model is made**

- Built by script in Blender (`tools/blender/stations`), reusing the Egg Garden kit's fused
  bodies, painted skin and HD bake. One asset is several meshes: body, head, four legs, tail,
  and `_glow` meshes that the game sets to Neon.
- The build records where each piece turns (`joints`) and where each mesh sits (`centres`) in
  the manifest. Each asset has a `scale`: shapes are written at a handy size and built real size.
- Uploads go only through the Upload Blender assets workflow, which gained a `stations` game.
  The generated `src/shared/StationAssets.luau` carries ids, sizes, joints and glow colours.

**How it moves**

- `src/stations/Creatures.luau` loads a model once, joins the pieces with Motor6Ds at the
  manifest joints on a hidden Root, and tags it `Creature`. The server only moves the Root and
  sets two attributes: `Anim` (idle, walk, attack, magic) and `AnimAt`.
- Every client poses the joints each frame from those attributes
  (`src/stations-client/Creatures.client.luau`): idle sway, a trot, a horn attack (crouch, lunge,
  horn thrown up) and a magic attack (rear up while the horn gathers light, slam down, a ring of
  light and a line of rock spikes bursting from the ground). A glowing variant casts in its own
  colour. No animation assets and no uploads are needed for a new move.
- A model's `Scale` is its leg length over the length the poses were written for; poses, effects
  and walk speed grow with it, and bigger animals step slower.

**Not doing:** stat progress from clearing waves. SHANNON asked for it and then withdrew it
("never mind dont give stat increases on wave clear just training"). Training is the only way a
stat grows, and its progress is kept per animal per stat, so stopping never loses any.

## Why

- Code-driven joints suit a game with many species and variants: one set of moves fits every
  four-legged animal of any size, and a variant needs only a new skin and extra pieces.
- Clients animate, so movement is smooth for everyone and costs the server nothing.

## Costs and limits

- Stiff joints: no bending knees or spine. Good for heavy animals; a cat may want more joints.
- The moves assume four legs. The Flamingo will need its own.
- About 11,000 to 12,000 triangles an animal. Fine for a fight of eight; watch it on phones.
- The ranch showcase moves the animals from the server, which can look less smooth online than
  in Studio. It is a stand-in until owned animals live at the ranch.
- The first toy-style uploads (four assets) stay on the Roblox account unused.
