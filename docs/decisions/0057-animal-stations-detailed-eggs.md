# 0057: Animal Stations: detailed eggs

Status: accepted (SHANNON on 2026-11-16: "go on egg replace all egg things"); in the game
Date: 2026-11-16. Tasks STATION-046 (concepts), STATION-047 (in the game).

## What SHANNON asked

"make all the eggs very detailed".

## Decision

The four eggs get models built in Blender like the animals (`tools/blender/stations/assets/eggs.py`,
flat face tones under a surface texture), in place of the plain spotted shells the world builds from
parts today. Each keeps its two colours and is dressed for where its animals come from.

- Meadow Egg: a cream shell dappled green, in a nest of woven twigs, grass, clover, daisies and small
  flowers, two flowering vines climbing it, a ladybird on its side, a butterfly at its top. 5,224 triangles.
- Wild Egg: a leaf-green shell with bark-brown spots, stripes over its crown and claw marks, bound in
  two thorned jungle vines with orchids, broad leaves, ferns and roots at its foot, moss, and
  mushrooms with glowing caps (Neon). 4,490 triangles.
- Safari Egg: a sand-gold shell with a cheetah's spots, a painted band of zigzags edged in red with
  rows of dots and teeth, a paw print, roped twice round and strapped with leather and a brass
  buckle, a string of beads, charms hanging from the knot (feathers, a tooth, beads), three tall
  feathers behind, on cracked earth among dry grass and stones. 5,416 triangles.
- Golden Egg: a shell of beaten gold, three hoops, eight great cut violet gems (Neon) with bosses
  between them, smaller rose and violet gems above, a quilting of lozenges, pearls, swagged chains, a
  crown of points round a great glowing gem, a stand with three clawed feet. 6,548 triangles.
- One piece each (`body`), with a Neon `body_glow` on the Wild and Golden Eggs. Three studs tall
  before its dressing. `facet.py` gains a `shell` surface (speckles) and glowing `lump`s.

## In the game (STATION-047)

Everything that drew an egg now shows the models.

- An egg is a still prop: `Creatures.build` gives an asset with no head a Root on the ground and no
  joints, and `Creatures.still` stands a copy somewhere at a scale. A still prop has no head to
  read its facing from, so it takes the turn the importer gives every model of this build.
- `World.kit.eggModel` is the one way to stand an egg in the world: the model, at a size given by
  the height of its shell, with an unseen part the size of the shell that is there at once for a
  prompt, a light or sparkles (the first model of a kind has to load). The plain spotted shell is
  kept only as the fallback when a model is not uploaded or does not load; the trimmings built
  from parts are gone.
- Where: the six nests of the hatchery (shell 3 studs), the egg storage rack (1.5 studs, down from
  1.7 so a crowned egg clears the shelf above), the egg vendor's counter (1.9 studs, spaced
  wider) and the great egg on the hub's fountain, which is now a Golden Egg 13 studs tall.
- The egg pictures in the Eggs menu and the egg vendor are portraits of the models (the still
  copies the animals' portraits use).
- The hatching animation rocks the egg's own model about its foot, then bursts as before in the
  egg's two colours. `Ranch.nest` returns a CFrame, so the egg and the animal that steps out face
  out of the hatchery.

## Not done

- The eggs do not glow or move while they hatch, beyond the ready sparkle they had.
- A fifth, later egg.
