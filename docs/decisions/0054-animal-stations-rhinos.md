# 0054: Animal Stations: the rhinos, rounder and textured, and a Crystal Rhino

Status: proposed (second round of concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 to 0053 (the lions, elephants, jackals and cheetahs). Task STATION-042.

## Decision

With the cheetahs' go-ahead SHANNON asked for concepts for the next animal set, and said the models
do not have to be low-poly, only not very detailed, with no self-imposed limits. The next set is the
rhinos (my pick: the heaviest animal still on its old model; the tortoise, meerkat and flamingo remain).

SHANNON on the first round: the snout was far too long; the Crystal Rhino was liked but should be more
crystalline, with gemstones of many colours and a body more like rock; all three need textures; go all
out. This is the second round.

- The Rhino, the Lava Rhino and a new Crystal Rhino are built in
  `tools/blender/stations/assets/rhinos.py`, rounder than the families before: a massive barrel of
  twelve-sided sections with a high shoulder hump, slung low on short round pillar legs under sleeves
  of armour, three rounded nails on each foot, a short deep head (two thirds of the first round's
  length) with a blunt muzzle, nostrils, a line of a mouth and a heavy brow, small ears, a scimitar of
  a horn on the nose and a short one behind it, and two raised plates of armour (shoulders and rump)
  with a fold of bare hide between.
- Surface textures (new, `facet.material(surface=...)`): over its flat face colours a piece can carry
  a procedural texture that bakes into the same 1024 texture: `hide` (a few deep folds, a fine
  pebbling, blotches), `rock` (blocks of stone each its own shade, cracks, grit), `crust` (rock with
  glowing lava in some cracks), `gem` (clouds of depth and sparks) and `horn` (rings and streaks). The
  texture is placed by where a point was modelled, so the card and the bake show the same pattern.
  Pieces that name no surface are built exactly as before: the lions, elephants, jackals and cheetahs
  were rebuilt and their manifest entries are unchanged.
- Rhino: slate hide and armour, bone studs on the shoulder plate, bone horns, three claw scars across
  the right flank, amber slit eyes. 3,016 triangles.
- Lava Rhino (mythic, as now): obsidian plates over dark red rock, lava baked into the plates' cracks,
  Neon lava in the folds between the plates, in jagged cracks across them and round each knee, molten
  horns, a crown of two rock horns, rock spikes with hot tips down the back, a burning tail, glowing
  eyes. 3,352 triangles.
- Crystal Rhino (new, proposed legendary, twist defence): living grey rock, hewn (every point knocked
  in or out, bigger chips), grown through with gemstones of nine colours (ruby, citrine, topaz,
  emerald, aqua, sapphire, amethyst, rose, diamond): six-sided crystals in great clusters on the
  shoulder hump and the rump with rubble round their roots, a ridge down the spine, clusters on each
  shoulder, haunch and knee, small ones through the hide, thin veins of gem in the plates, lumps of
  rock along the plates' edges and over the eyes, crystal nails, a great crystal horn with small ones
  round its root and a rose one behind it, a mace of crystals for a tail. Seven crystals are Neon,
  each in its own colour (the horn and eyes cyan, the hump's tallest violet, the tail's green, one on
  each knee in red, blue, amber and pink). 6,440 triangles. Legendary is the free tier: the Lava Rhino
  is the mythic one.
- Each is scaled to the length of the model it replaces: 5.4 wide x 7.8 tall x 13.9 long studs,
  6.9 x 11.3 x 18.5, and the Crystal Rhino 7.7 x 11.5 x 16.0 (the old ones were 8.4 and 12.6 tall).
- The cards show each `_glow` piece in its own colour, as the game does (`kit.beauty`).
- `facet.py` also has rounder sections (`oval`, `round_z`). The old rhino build (`assets/creatures.py`,
  on the smooth body kit) is removed.

## Open for SHANNON

- Approve the three looks, or ask for changes.
- The Crystal Rhino: its tier (legendary) and its twist (defence). The Gemshell Tortoise also carries
  crystals (pink, one on every plate); when the tortoises are redone the two should be told apart.
- Whether the textures should go onto the families already in the game (the lions, elephants, jackals
  and cheetahs have flat face colours only).

## Not done

Concepts only: nothing is uploaded, `StationConfig`, `StationAssets` and the manifest are unchanged,
and the game still shows the old rhinos. The clips have not been seen on the new shapes. The Crystal
Rhino is the first model with seven Neon pieces in seven colours; that has been seen on its card but
not in Studio.
