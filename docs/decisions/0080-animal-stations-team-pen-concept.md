# 0080: Animal Stations: the meadow as a pen for the team (concept)

Status: accepted (SHANNON, 2026-11-17: "leave them off the ranch unless theyre training and go ahead and
build it"); in the game by STATION-081. Date: 2026-11-17. Tasks STATION-080, STATION-081.

## What SHANNON asked

"make a concept for a pen in the middle of the ranch like it is right now but only your 3 animal team
can be in there".

## What was made (`docs/concepts/team-pen-card.png`)

The homestead as it is, its meadow fenced round as a pen (`scenes/team_pen.py`, the homestead scene with
its `TEAM` switch set; the homestead's own card and models are unchanged):

- A rail fence just inside the meadow's edge, inside the ring path; one gate towards the road in from
  the hub, under a "YOUR TEAM" board, with a lantern either side.
- Inside, as now: the pond, the shade tree, the trough. A bed of straw for each of three.
- Only the team of three in it (the card shows a Lion, a Lightning Cheetah and a Rhino). The Titan sleeps
  in its den (decision 0079).

## What building it would change (for SHANNON to decide)

1. Where the rest of the herd goes: not shown (recommended: the game shows only the team on the
   homestead), or in the animal pen behind the Barn of decision 0077.
2. The game: the herd on the homestead would be `Profile.team` (three) instead of the first eight
   animals (`syncHerd`), walking spots inside the fence (`Ranch.somewhere`), and the fence as unseen
   solid blocks with the gate open.
3. The go-ahead to build it.

## Built (STATION-081)

- The herd on the homestead is the team (`Profile.team`, at most three) and the Titan in its den. Every
  other animal is off the ranch, unless it trains: then it is in its training area, as before. (The
  first eight animals roamed before.)
- `Ranch.luau` builds the fence where the meadow's stone kerb was (just outside the meadow, inside the
  ring path): posts every 8 degrees with two rails, which are solid, and the one gate towards the road
  in, under a "Your Team" board with a lantern each side; three beds of straw inside. The team walks
  where the herd walked (`Ranch.somewhere`), all inside the fence.

## Not done

The gate has no door that closes. Not looked at from a player's height inside, or on a phone.
