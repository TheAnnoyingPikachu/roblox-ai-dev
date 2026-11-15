# 0053: Animal Stations: the cheetahs go faceted, and a Fire Cheetah

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 to 0052 (the faceted lions, elephants and jackals). Task STATION-040.

## Decision

SHANNON asked for the cheetahs next, with a lightning and a fire cheetah.

- The Cheetah, the Lightning Cheetah and a new Fire Cheetah are built in
  `tools/blender/stations/assets/cheetahs.py`: a slender body with a deep chest and a high tucked waist
  on very long thin legs, a small head with a short muzzle, round ears and tear marks, spots as small
  flat diamonds on the hide (body, neck, legs), and a very long tail with two dark rings. The hide has
  the facets of the elephants and jackals. About 2,400 to 2,500 triangles each (the spots are most of it).
- Cheetah: golden, black spots and tear marks, a pale chin and tail tip, amber eyes.
- Lightning Cheetah (mythic, as now): a storm-dark coat with electric blue spots, a glowing jagged bolt
  down each flank behind the shoulder and before the haunch, a glowing crest on the neck, a zigzag
  tail with a glowing tip, glowing eyes.
- Fire Cheetah (new, proposed legendary, twist strength): a red-hot coat with ember-yellow spots and
  scorched dark legs, a glowing ridge of flame down the spine, a crest of flame between the ears, a tail
  that ends in flame, glowing eyes. Legendary is the free tier: the Lightning Cheetah is the mythic one.
- Each is scaled to the height of the model it replaces (4.65 and 6 studs; the Fire Cheetah 5.6), so
  the animal is the size it was; it is longer overall (10.9, 13.9 and 13 studs) because the tail is.
- The small paw the jackals and cheetahs share moved to `facet.py`; the jackals build exactly as uploaded.

## Open for SHANNON

- Approve the three looks, or ask for changes.
- The Fire Cheetah: its tier (legendary) and its twist (strength).

## Not done

Concepts only: nothing is uploaded, `StationConfig`, `StationAssets` and the manifest are unchanged,
and the game still shows the old cheetahs. The clips have not been seen on the new shapes.
