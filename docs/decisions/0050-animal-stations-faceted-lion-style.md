# 0050: Animal Stations: the lions are faceted low-poly

Status: proposed (for SHANNON at the next Animal Stations checkpoint)
Date: 2026-11-15. Amends 0033 (animal models). Task STATION-033.

## Decision

SHANNON shared a reference card of the Sun Lion (chunky, faceted low-poly, a mane of broad crystal
shards, big cream paws, a sun on the haunch) and asked for all the lions to look like it, then asked
for another try with the earlier limits taken off (triangle budget, the shared smooth body kit, the
plain preview).

- The Lion, the Sun Lion and the new Shadow Lion are built from scratch in
  `tools/blender/stations/assets/lions.py`, no longer on the predator body in `animals.py`: lofted
  long blocky bodies, compact paws with three short toes, a boxy face with slit eyes, a mane of about 30 big
  crystal shards with a bib down the chest, and a fan of six shards for the tail tuft.
- Nothing is smooth and nothing is painted with gradients. Every face has one colour (the `lp`
  colour attribute), picked from three tones by which way the face points plus a little chance, and
  that bakes straight into the texture. Shards lighten from root to tip.
- Sun Lion: golden, a star of a sun on each haunch, glowing eyes. Shadow Lion: ink black, a bone
  mask, spine and fangs, glowing green ribs, eyes and a few shards. No lion has claws, and the Lion
  and the Sun Lion have no fangs, as on the reference.
- Kept plain on purpose. A first version (about 75 shards, bevelled sections, a nose bridge, cheek
  tufts, a mouth line, an eight-rayed sun, claws) was too detailed for SHANNON; this one has fewer,
  bigger faces. Add a piece only if it reads from across the arena. A squat version with long flat
  feet was also wrong, and so was a taller one: SHANNON wants the body long, the hind legs standing
  well behind the front ones (`HIND` in lions.py), not more height.
- The rig is the same set of pieces (body, head with the mane, four legs, tail, glow pieces); the
  joints moved a little and are recorded per build as before. Each lion is scaled to about the length
  of the model it replaces (13, 16 and 15 studs), so the arena spacing holds.
- About 1,200 to 1,300 triangles each. The budget is no longer a design limit for these models.
- `build.py --beauty` renders a presentation card of an asset (a hero shot on a pedestal with bloom,
  and front, side and back views) to `build/blender/stations/beauty`; the cards in `docs/concepts`
  come from it. The pedestal, rings and bloom are render dressing, not part of the model.
- The other animals are unchanged. Whether they follow this style is for SHANNON to say.

## Not done

Nothing is uploaded and `StationAssets` and the manifest are unchanged, so the game still shows the
old models until they are rebuilt and uploaded by the workflow. The clips were written for the old
shapes and have not been seen on the new ones. The aura of the reference in the game would be an
effect (particles or a light), which is not built.
