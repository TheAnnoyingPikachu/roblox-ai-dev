# 0050: Animal Stations: the lions are faceted low-poly

Status: accepted by SHANNON on 2026-11-15 (the look, and the lions going into the game)
Date: 2026-11-15. Amends 0033 (animal models) and 0037 (one variant an animal). Tasks STATION-033, STATION-034.

## Decision

SHANNON shared a reference card of the Sun Lion (chunky, faceted low-poly, a mane of broad crystal
shards, big cream paws, a sun on the haunch) and asked for all the lions to look like it, then asked
for another try with the earlier limits taken off (triangle budget, the shared smooth body kit, the
plain preview).

- The Lion, the Sun Lion and the new Shadow Lion are built from scratch in
  `tools/blender/stations/assets/lions.py`, no longer on the predator body in `animals.py`: lofted
  long blocky bodies, compact paws with three short toes, a face after the reference (a short deep
  muzzle, pale lips wrapped round its front, a dark wedge of a nose with a line down to the mouth, a
  chin, a brow ledge over slit eyes, rounded ears, a lighter stripe up the nose), a full mane of about
  60 broad leaves swept back so they overlap like feathers, with a wide bib down the chest, and a flame of seven shards for the tail tuft.
- Nothing is smooth and nothing is painted with gradients. Every face has one colour (the `lp`
  colour attribute), picked from three tones by which way the face points plus a little chance, and
  that bakes straight into the texture. Shards lighten from root to tip.
- Sun Lion: golden, a sun (a disc and twelve rays) on each haunch, glowing eyes. Shadow Lion: ink black, a bone
  mask, spine and fangs, glowing green ribs, eyes and a few shards. No lion has claws, and the Lion
  and the Sun Lion have no fangs, as on the reference.
- Kept plain on purpose. A first version (about 75 shards, bevelled sections, a nose bridge, cheek
  tufts, an eight-rayed sun, claws) was too detailed for SHANNON; a plainer one
  (30 shards) was then too far from the reference. The measure is the reference card: big flat faces,
  and a piece only if the reference has it. A squat version with long flat
  feet was also wrong, and so was a taller one: SHANNON wants the body long, the hind legs standing
  well behind the front ones (`HIND` in lions.py), not more height.
- The rig is the same set of pieces (body, head with the mane, four legs, tail, glow pieces); the
  joints moved a little and are recorded per build as before. Each lion is scaled to about the length
  of the model it replaces (13, 16 and 15 studs), so the arena spacing holds.
- About 1,600 to 1,800 triangles each. The budget is no longer a design limit for these models.
- `build.py --beauty` renders a presentation card of an asset (a hero shot on a pedestal with bloom,
  and front, side and back views) to `build/blender/stations/beauty`; the cards in `docs/concepts`
  come from it. The pedestal, rings and bloom are render dressing, not part of the model.
- The other animals are unchanged. Whether they follow this style is for SHANNON to say.

## Into the game (STATION-034)

- The Lion and the Sun Lion get the new models: built, exported to `assets/stations` and uploaded by the
  Upload Blender assets workflow; `StationAssets` and the manifest carry the new rig.
- The Shadow Lion is the Lion's second variant: legendary, twist speed (`shadow_lion` in `StationConfig`).
  0037 gave every animal one variant. Now an animal may have one of each tier, because a hatch rolls a
  tier and takes that animal's variant of it. What changes for players: a legendary roll on a Lion
  (1 in 2,000 Lion hatches) now gives a Shadow Lion, where it gave a plain Lion before. Nothing else in
  the odds moves, and no save changes: old saves have no `shadow_lion` and need none.
- The Shadow Lion uses the Lion's attack and power clips until it gets its own.
- The lions' clips were fitted to the new shape (`Creatures.client`): the crouch before a pounce splays
  the front legs far forward so the paws stay on the ground, and the tail is held up through the leap
  and the win pose, because the long tail flame dragged on the ground. The other clips fit as they were.

## Not done

Defeated, a lion lies on its side with the lower half of its mane in the ground (the mane is wider than
the body); left as it is. The aura of the reference in the game would be an
effect (particles or a light), which is not built.
