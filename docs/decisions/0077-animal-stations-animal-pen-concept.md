# 0077: Animal Stations: an animal pen behind the Barn (concept)

Status: proposed (a concept for SHANNON; nothing is in the game). Date: 2026-11-17. Task STATION-075.

## What SHANNON asked

"make a concept for an animal pen fit into the current ranch so the animals arent in the center".

## What was made (`docs/concepts/animal-pen-card.png`)

The homestead with the herd moved out of its middle into a fenced pen (`scenes/animal_pen.py`, built on
`scenes/homestead.py` with its `PEN` switched on; the homestead's own card and models are unchanged).

- **Where:** behind the Barn, 142 studs out at 236 degrees of the plan, 60 studs along the ring by 40
  out, its front to the Barn's back. The homestead is full between the ways, so the pen is the first
  thing outside it. Its gate is on its left end, where a short lane leaves the Strength Gym's path.
- **What is in it, by the Barn's level:** a rail fence, a gate under an "ANIMAL PEN" board, a trough and
  hay at first; an open shelter and a hay rack from the middle levels; a pond, a mud wallow, a shade tree
  and a salt lick at the top. The animals that roamed the meadow roam the pen (the card also shows the
  Giraffe concept of decision 0076 at the hay rack).
- **The middle:** the meadow keeps its pond and shade tree and becomes a green to sit on: flower beds
  and benches, no animals, no trough, no rain shelter.

## What building it would change

- Fact: the land behind the Barn rises (about 17 studs at the pen's middle, 30 at its back), so
  `ValleyMap` would level a pad for the pen and its lane, as it does for a training ground, and its spec
  would check the pad.
- `Ranch.somewhere` (where the herd walks) would pick spots in the pen instead of the meadow; the pen's
  fence would be unseen `Solid` blocks, like a building's.
- The pen, its fence and its shelter would be models in three looks that follow the Barn's level, like
  the buildings (an upload of three to six models).

## For SHANNON to decide

1. The place (behind the Barn, entered from the Strength Gym's path) and the size: go, or another place
   (for example by the road in from the hub, which would need no levelling but is outside the gate).
2. Whether the meadow becomes the green shown, or keeps something else in the middle.
3. The go-ahead to build it into the game.

## Not done

Nothing is in the game. The land is not levelled on the card (its ground is flat). Not looked at from a
player's height inside the pen with a full herd, or on a phone.
