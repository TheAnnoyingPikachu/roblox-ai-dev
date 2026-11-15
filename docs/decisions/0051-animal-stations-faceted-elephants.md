# 0051: Animal Stations: the elephants go faceted, and a War Elephant with a cannon

Status: accepted by SHANNON on 2026-11-15 (the textured elephants go forward; the lions keep their plain hide)
Date: 2026-11-15. Builds on 0050 (the faceted lions). Tasks STATION-035, STATION-036.

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

## Into the game (STATION-036)

- The Elephant and the Frost Mammoth get the new models: built, exported to `assets/stations` and
  uploaded by the Upload Blender assets workflow; `StationAssets` and the manifest carry the new rig.
- The War Elephant is the Elephant's second variant (`war_elephant` in `StationConfig`), legendary with
  twist strength as proposed below; SHANNON saw the open points and asked to continue. What changes
  for players: a legendary roll on a Titan (1 in 2,000 Titan hatches) now gives a War Elephant, where
  it gave a plain Elephant before. Nothing else in the odds moves, and no save changes.
- The War Elephant uses the Elephant's clips; its cannon is for show and does not fire.
- SHANNON looked at the same hide on the lions and left them as they are.
- The elephants' clips fit the new shapes as they were (walk, attack, power attack, defeat, win).
- Vertex colours. The faceted models carry their face colours as a colour attribute. Exported with
  it, Roblox multiplies the texture by those colours again, and every colour comes out darker and
  harsher (the Elephant navy, its ear purple). `tools/blender/stations/kit.py` now drops colour
  attributes after the bake, and the elephants were uploaded a second time without them; in the game
  they match the concept cards. **The lions of 0050 were uploaded with the fault** and are darker and
  more saturated in the game than the approved renders: they need a rebuild and a new upload, which
  waits for SHANNON's word.

## Raised with SHANNON

- The three looks: taken forward with the textured hide.
- The War Elephant as a variant: 0050 allows an animal one variant of each tier and the Elephant has
  only its mythic one, so legendary is free. Its twist is proposed as strength. The basic Elephant is
  itself legendary, so a legendary variant of it is new ground: say if it should be mythic instead
  (then the Frost Mammoth would have to move, as one tier holds one variant).
- The base Elephant was described as a war elephant; with this variant it becomes a plain elephant.
- The same hide on the lions: `docs/concepts/lion-retexture-example.png` shows the three lions as they
  are in the game and with the faceted hide on the body, legs and skull (the mane is unchanged). It was
  an example only, behind a switch in `lions.py`; SHANNON left the lions as they are, and the switch
  was removed with decision 0052.

## Not done

The cannon does not fire: a power attack of its own for the War Elephant is future work.
