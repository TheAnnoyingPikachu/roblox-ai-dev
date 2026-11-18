# 0086: Animal Stations: the training grounds in the overhaul's look (concept)

Status: accepted (SHANNON, 2026-11-18: "go for the after look its awesome!"); built by STATION-091.
Date: 2026-11-18. Tasks STATION-090, STATION-091.

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

## Built (STATION-091)

- `Valley.luau`: the track's floor is LeafyGrass; `Valley.dress` stands the border (every 9 degrees on
  the rim, open 16 degrees either side of the path) and up to 260 tries of woods per ground, from 6 to
  75 studs past its edge, kept off paths, the stream, water, the homestead, other grounds and the den's
  hill (`wild`).
- `ValleyMap.kind`: a floor ends 84 studs out, give or take 8 by noise, instead of a 90-stud circle;
  the pool keeps its circle.
- Fixed on the way: `calm` in `World.luau` (STATION-089) made a row of no width at the end of each
  round and Roblox threw "Region cannot be empty", which stopped the world build after ranch 1's
  valley. A row is now at least 4 studs wide.
- Fact: the world counted about 19,800 parts in Studio with the areas at level 5, up from about 9,300.
  The flower clumps are the most parts for what they give (12 each); cut them first if phones are slow.

## Not done

Not looked at: levels 0 to 4 (assumption: the land round an area is the same at every level, so the
after fits them too), a camera at ground level, a phone, the frame rate.
