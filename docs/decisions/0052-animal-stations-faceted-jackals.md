# 0052: Animal Stations: the jackals go faceted, and a Sphinx Jackal

Status: accepted by SHANNON on 2026-11-15 (the three looks, and the jackals going into the game)
Date: 2026-11-15. Builds on 0050 (the faceted lions) and 0051 (the elephants, the textured hide). Tasks STATION-037, STATION-038.

## Decision

SHANNON asked for the same for the hyenas, and chose the Jackals when asked which animal that meant:
a restyle of the Jackal and the Pharaoh Jackal, and one new variant to propose.

- The Jackal, the Pharaoh Jackal and a new Sphinx Jackal are built in
  `tools/blender/stations/assets/jackals.py`: a lean body with a deep chest and a tucked waist on long
  thin legs, a long narrow muzzle, big pointed ears, a dark saddle over the back, small dark paws and a
  bushy tail of leaf shards. The head is carried low (the head and neck nod 14 degrees about the neck).
  The hide has the elephants' facets. About 1,400 to 1,900 triangles each.
- Jackal: sandy, a dark brown saddle, a pale lower jaw, dark paws and tail tip, amber eyes.
- Pharaoh Jackal (legendary, as now): black, with gold collars, anklets, ear tips and tail tip,
  turquoise glowing eyes and a glowing gem on the brow.
- Sphinx Jackal (new, proposed mythic, twist speed): sandstone, in a pharaoh's blue and gold striped
  headdress with its two lappets and a cobra, a glowing sun disc between the ears, a striped false beard,
  a gold and blue collar, a blue saddle, a folded wing of gold and blue feathers down each flank, a gold
  tail tip and glowing gold eyes. Mythic is the free tier: the Pharaoh Jackal is the legendary one.
  A first proposal, a silver Moon Jackal, was dropped: SHANNON asked for a sphinx instead.
- The faceted helpers the three families share now live in `tools/blender/stations/facet.py`; the
  lions and the elephants build exactly as before the move.
- Each is scaled to the length of the model it replaces (7.4 and 9.1 studs; the Sphinx Jackal 9.6).

## Into the game (STATION-038)

- The Jackal and the Pharaoh Jackal get the new models: built, exported to `assets/stations` and
  uploaded by the Upload Blender assets workflow; `StationAssets` and the manifest carry the new rig.
- The Sphinx Jackal is the Jackal's second variant (`sphinx_jackal` in `StationConfig`), mythic with
  twist speed as proposed. What changes for players: a mythic roll on a Jackal (1 in 20,000 Jackal
  hatches) now gives a Sphinx Jackal, where it gave a plain Jackal before. Nothing else in the odds
  moves, and no save changes.
- The Sphinx Jackal uses the Jackal's clips until it gets its own.

## Not done

The Sphinx
Jackal's wings are part of the body and its headdress part of the head: they move with those pieces
and do not flap or sway.
