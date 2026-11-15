# 0054: Animal Stations: the rhinos, rounder, and a Crystal Rhino

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 to 0053 (the lions, elephants, jackals and cheetahs). Task STATION-042.

## Decision

With the cheetahs' go-ahead SHANNON asked for concepts for the next animal set, and said the models
do not have to be low-poly, only not very detailed, with no self-imposed limits. The next set is the
rhinos (my pick: the heaviest animal still on its old model; the tortoise, meerkat and flamingo remain).

- The Rhino, the Lava Rhino and a new Crystal Rhino are built in
  `tools/blender/stations/assets/rhinos.py`, rounder than the families before: a massive barrel of
  twelve-sided sections with a high shoulder hump, slung low on short round pillar legs with three pale
  nails, a long low head with a rounded muzzle, nostrils and a line of a mouth, small ears, a scimitar
  of a horn and a short one behind it, and two raised plates of armour (shoulders and rump) with a
  fold of bare hide between. The colours are still one flat tone a face. About 2,200 to 2,400 triangles.
- Rhino: slate, bone studs on the shoulder plate, bone horns, three claw scars across the right
  flank, amber slit eyes.
- Lava Rhino (mythic, as now): obsidian plates over dark red hide, glowing lava in the folds between
  the plates and in jagged cracks across them, molten glowing horns, a crown of two rock horns, rock
  spikes down the back, a burning tail, glowing eyes.
- Crystal Rhino (new, proposed legendary, twist defence): a dark violet-grey stone hide with clusters
  of amethyst growing through its armour (a great one on the shoulder hump, others on the rump,
  shoulders, haunches and brow, the tallest of each with a glowing heart), horns of glowing crystal,
  glowing violet eyes. Legendary is the free tier: the Lava Rhino is the mythic one.
- Each is scaled to the length of the model it replaces (13.9 and 18.5 studs; the Crystal Rhino 16).
  They stand lower than the old ones (6.7, 10.1 and 10.5 studs tall against 8.4 and 12.6): a rhino is
  slung low, and the old one had a taller horn.
- `facet.py` gains rounder sections (`oval`, `round_z`). The old rhino build (`assets/creatures.py`,
  on the smooth body kit) is removed.

## Open for SHANNON

- Approve the three looks, or ask for changes.
- The Crystal Rhino: the idea itself, its tier (legendary) and its twist (defence). The Gemshell
  Tortoise also carries crystals (pink, one on every plate); when the tortoises are redone the two
  should be told apart.
- Whether this rounder build is the look to carry on with, or the sharper facets of the cheetahs.

## Not done

Concepts only: nothing is uploaded, `StationConfig`, `StationAssets` and the manifest are unchanged,
and the game still shows the old rhinos. The clips have not been seen on the new shapes.
