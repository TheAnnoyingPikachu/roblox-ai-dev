# 0057: Animal Stations: detailed eggs

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-16. Task STATION-046.

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

## Open for SHANNON

- Approve the four looks, or ask for changes.
- On approval they are uploaded and put in the game: the hatchery, the egg storage rack, the vendor's
  counter and the egg pictures in the menus all draw eggs today (`Ranch.eggModel`, the HUD's
  `eggArt`), and the hatching animation is written for the plain shell. The smaller option is the
  world models only, keeping the flat egg pictures in the menus.

## Not done

Concepts only: nothing is uploaded and the game still shows the plain eggs. Two rounds of looking at
the cards.
