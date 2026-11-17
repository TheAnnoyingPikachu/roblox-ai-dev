# 0080: Animal Stations: the meadow as a pen for the team (concept)

Status: proposed (a concept for SHANNON; nothing is in the game). Date: 2026-11-17. Task STATION-080.

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

## Not done

Nothing is in the game. Not looked at from a player's height inside, or on a phone.
