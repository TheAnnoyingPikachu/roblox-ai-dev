# 0086: Animal Stations: the training grounds in the overhaul's look (concept)

Status: proposed. Date: 2026-11-18. Task STATION-090.

## What SHANNON asked

"can you do some concepts forthe training grounds following the updated map detail?"

## What was made (`docs/concepts/training-grounds-card.png`)

The real game in Studio (local build, stamp `dev`), ranch 1's six areas at Training Grounds level 5,
each from one camera, now and after. The after was applied live in a Play session and thrown away.

## What is wrong now (facts, from the screens)

- The Speed Track's clay lanes and its pond have grass blades growing up through them: its ground is
  Grass, and the overhaul's blades grow through anything lying flat on Grass (decision 0085).
- Each area is a hard-edged disc of one ground (sand, slate, limestone) cut out of the land.
- Round it, the slopes are bare rock with nothing on them: the overhaul's woods stop at the valley floor.
- The areas themselves (their models) already look finished; the problem is the land round them.

## The after (all of it in code, no new models or uploads)

1. The track's ground is LeafyGrass instead of Grass (`Valley.luau`'s `MATERIAL.track`): no blades
   through the lanes and pond.
2. A frayed edge: the floor and the grass interleave over the outer 10 to 20 studs by noise, instead of
   a hard circle. Not for the Swim Pool, whose ground is already the beach's sand.
3. A border round each area's rim (radius about 92): the faceted bushes, rock clusters and flower
   clumps, open where the path comes in.
4. Woods up the slopes round each area (104 to 175 studs out): faceted trees where it is gentle,
   pines where it is steeper, none in water or on another ground.

Fact: 744 pieces for the six areas, so about 2,200 for three ranches (assumption: the frame rate
holds, as the trees are models; not measured).

## For SHANNON to decide

1. Go, or changes. Recommended: go, as above, built into `Valley.dress` so it stands at every level.
2. Whether the slopes get ledges and grassy tops too (more work; recommended later, if the woods are
   not enough).

## Not done

Not looked at: levels 0 to 4 (assumption: the land round an area is the same at every level, so the
after fits them too), a camera at ground level, a phone, the frame rate.
