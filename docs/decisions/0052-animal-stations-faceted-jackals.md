# 0052: Animal Stations: the jackals go faceted, and a Moon Jackal

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 (the faceted lions) and 0051 (the elephants, the textured hide). Task STATION-037.

## Decision

SHANNON asked for the same for the hyenas, and chose the Jackals when asked which animal that meant:
a restyle of the Jackal and the Pharaoh Jackal, and one new variant to propose.

- The Jackal, the Pharaoh Jackal and a new Moon Jackal are built in
  `tools/blender/stations/assets/jackals.py`: a lean body with a deep chest and a tucked waist on long
  thin legs, a long narrow muzzle, big pointed ears, a dark saddle over the back, small dark paws and a
  bushy tail of leaf shards. The head is carried low (the head and neck nod 14 degrees about the neck).
  The hide has the elephants' facets. About 1,400 to 1,550 triangles each.
- Jackal: sandy, a dark brown saddle, a pale lower jaw, dark paws and tail tip, amber eyes.
- Pharaoh Jackal (legendary, as now): black, with gold collars, anklets, ear tips and tail tip,
  turquoise glowing eyes and a glowing gem on the brow.
- Moon Jackal (new, proposed mythic, twist speed): silver-white with a deep blue saddle and socks, a
  glowing crescent on the brow and on each haunch (as the Sun Lion has its sun), glowing eyes, ear tips
  and tail tip. Mythic is the free tier: the Pharaoh Jackal is the legendary one.
- The faceted helpers the three families share now live in `tools/blender/stations/facet.py`; the
  lions and the elephants build exactly as before the move.
- Each is scaled to the length of the model it replaces (7.4 and 9.1 studs; the Moon Jackal 9.6).

## Open for SHANNON

- Approve the three looks, or ask for changes.
- The Moon Jackal: its name, its tier (mythic) and its twist (speed, the Jackal's best stat).

## Not done

Concepts only: nothing is uploaded, `StationConfig`, `StationAssets` and the manifest are unchanged,
and the game still shows the old jackals. The clips have not been seen on the new shapes. The Moon
Jackal's crescents on the haunches are glow pieces that ride on the hind legs, which no model in the
game has had before; the rig allows it, but it has not been seen in the game.
