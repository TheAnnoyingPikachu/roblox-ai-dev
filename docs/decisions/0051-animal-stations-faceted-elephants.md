# 0051: Animal Stations: the elephants go faceted, and a War Elephant with a cannon

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 (the faceted lions). Task STATION-035.

## Decision

SHANNON asked for the elephants in the style of the final lions, and for the second variant to be a
war elephant with a cannon on it.

- The Elephant (the Titan), the Frost Mammoth and a new War Elephant are built in
  `tools/blender/stations/assets/elephants.py` with the lions' faceted helpers: a boxy body on four
  pillars of legs with pale toenails, a tall head with flared plate ears, a trunk of tapering blocks,
  curved four-sided tusks, a short tail. About 1,700 to 2,100 triangles each.
- The hide is textured with facets, not paint: every big face is broken into triangles round a slightly
  raised middle, each its own tone and darker towards the ground, with folds of skin at the shoulders
  and hips, creases at the knees and ankles, and a ringed trunk (SHANNON asked for more texture).
- Elephant: blue-grey, amber slit eyes, pale tusks.
- Frost Mammoth (mythic, as now): icy blue with a hump, small ears, a shaggy fringe down both flanks,
  huge curved tusks of glowing ice, ice spikes down the back, glowing eyes.
- War Elephant (new, proposed legendary, twist strength): dark, in war gear: a red blanket with a gold
  hem, a wooden deck carrying a cannon that points forward over the head, a steel plate and a gold
  spike on the brow, gold caps on the tusks, ember eyes, a glowing muzzle and fuse.
- The rig is the usual set of pieces; the cannon rides on the body. Each is scaled to the length of the
  model it replaces (24.5 and 30 studs; the War Elephant 27).

## Open for SHANNON

- Approve the three looks, or ask for changes.
- The War Elephant as a variant: 0050 allows an animal one variant of each tier and the Elephant has
  only its mythic one, so legendary is free. Its twist is proposed as strength. The basic Elephant is
  itself legendary, so a legendary variant of it is new ground: say if it should be mythic instead
  (then the Frost Mammoth would have to move, as one tier holds one variant).
- The base Elephant was described as a war elephant; with this variant it becomes a plain elephant.
- The same hide on the lions: `docs/concepts/lion-retexture-example.png` shows the three lions as they
  are in the game and with the faceted hide on the body, legs and skull (the mane is unchanged). It is
  an example only, behind the `LIONS_HIDE` switch in `lions.py`, which is off: the lions build as
  uploaded. Approving it means turning the switch on for good, a rebuild and a new upload of the lions.

## Not done

Concepts only: nothing is uploaded, `StationConfig`, `StationAssets` and the manifest are unchanged,
and the game still shows the old elephants. The clips have not been seen on the new shapes; the
cannon does not fire.
