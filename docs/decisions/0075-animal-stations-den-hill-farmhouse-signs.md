# 0075: Animal Stations: the Titan's Den in its hill, the farmhouse in the game, signs moved clear

Status: accepted (SHANNON, 2026-11-17: "rebuild the titan den into the hill thats behind it and fix the
sings for example the trophy lodge sign and a few signs that say buy at barn house even after maxing",
then "go ahead with the farm house as well"). Builds decisions 0072 and 0074. Task STATION-071.

## The Titan's Den

- `ValleyMap` raises a hill behind the den's place (`ValleyMap.DEN`: on the line 134 degrees out from
  the homestead's middle, its face 116 studs out, the hill 28 studs high, running back into the
  mountainside), level ground before its gate. A spec checks the hill stands well over the hall.
- `Valley.den` cuts the hall out of it (35 studs wide, 21.5 high, 32 deep): heights cannot hold a cave.
- The den's models are now only its front and what is inside: a timber frame in the cave's mouth
  (look 1), a stone gate (2), a great stone gate with tusks, banners and braziers (3); a stone floor, a
  bed of hay, a trough and lamps on the back wall. The Titan stands inside. Its plot, before it is
  bought, is staked inside the cave.

## The Ranch House

The farmhouse of decision 0074 replaces the house's three models: a cottage (levels 0 and 1), a
farmhouse with a long porch (2 and 3), a great farmhouse with a cross wing (4). Its unseen blocks and
the door's prompt follow each look.

## Signs

- The Trophy Lodge's name now hangs under its cornice in front of its columns; it was sunk in its
  roof. The Hatchery's hangs in front of its posts. The Titan's Den's is on its gate. The farmhouse's
  hangs in front of its porch posts.
- The "Buy it in the ranch menu" boards that stayed after buying were the second, older copy of the
  ranch that STATION-070 fixed: with every upgrade bought, no such board is left (checked in Studio).

## Not done

- The farmhouse's "R" is a little darker than the other letters (its bake's shade). Not looked at on a
  phone. The two looks of the house and den in between were checked from the build's previews only.
