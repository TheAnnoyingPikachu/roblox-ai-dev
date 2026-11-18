# 0087: Animal Stations: ledges and grassy tops on the rock round the training grounds (concept)

Status: accepted (SHANNON, 2026-11-18: "go for it and cut flower clumps now"); built by STATION-093.
Date: 2026-11-18. Tasks STATION-092, STATION-093.

## What SHANNON asked

"show me what the ledges and grassy tops would look like" (item 2 of decision 0086).

## What was made (`docs/concepts/training-ledges-card.png`)

The real game in Studio (local build, stamp `dev`) with decision 0086 built (STATION-091), ranch 1's
areas at Training Grounds level 5. Three areas from the 0086 cameras, then with the ledges, and one
close-up from the gym's yard. Applied live in a Play session and thrown away.

## What was tried

Round every ground, every 4 degrees, at 116 to 200 studs out:

- **Ledges** where the rock face is steep (its slope's normal 0.25 to 0.8 up), about one spot in two:
  a shelf of stone 12 to 24 studs wide and 7 to 11 deep out of the face, a smaller one under it, a
  grass top, and on it a bush, a small pine or flowers. Three warm greys (decision 0085's), Slate.
- **Grassy tops** where the rock lies flat (normal over 0.8 up): the rock there turned to LeafyGrass,
  with a pine on about a third.

Fact: 229 ledges and 350 grassy tops for one ranch's six areas.

## What it shows (facts, from the screens)

- From above, as a player sees an area walking in, it hardly changes: the woods of 0086 already
  cover most of the rock, and the ledges lie flat to the camera.
- From the ground (the close-up), the bare rock faces get steps, shelves with plants and green patches:
  this is where it shows.
- A few shelves stand out from the face with a gap under them where the face curves away.

## For SHANNON to decide

1. Build it, or not. Recommended: build it, as the rock faces are what a player sees standing in an
   area, with each shelf pushed further into the face so none floats.
2. Assumption to check if built: about 230 ledges of 3 parts per ranch (about 2,000 parts for three)
   on top of 0086's; a phone may need fewer.

## Built (STATION-093)

- `Valley.luau`: `rocky` walks a fixed grid of the rock round each ground (10 to 94 studs past its
  edge) from `ValleyMap`'s heights, not raycasts. Where the slope over 12 studs is under 0.9,
  `Valley.tops` (called after `Valley.write`) turns the rock to LeafyGrass and `dress` stands a pine on
  about a third; steeper, up to 3.5, one spot in five gets a ledge set into the face with only 3 studs
  standing out, so none floats. 641 ledges for three ranches (at one in 2.5 there were 1,307).
- The flower clumps are gone from the areas' border (SHANNON): bushes and rocks only.
- Asked at the same time: the whole homestead is LeafyGrass (`calm` to `ValleyMap.HOME`, it was the
  meadow only), so no blade comes up through a stall, a plot or a path; the tufts along the
  homestead's dirt paths come one in seven, not one in two.
- Fact: 23,221 parts in the world in Studio, ranch 1's areas at level 5.

## Not done

Not looked at: the track, the pool and the guard yard close up (less rock round them), a phone, the
frame rate.
