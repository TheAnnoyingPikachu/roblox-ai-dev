# 0109: Animal Stations: a quick press for each class, popping up by the animal

Status: accepted (SHANNON, 2026-11-24, below). Changes decision 0106's press table and where the presses pop up.
Date: 2026-11-24. Task STATION-128.

## Context

- Fact: decision 0106 gave each species (and four variants) the press of what its spell does: a lion, a
  rhino and a giraffe a ring, a jackal, a tortoise and a meerkat a needle, a cheetah and a flamingo a chain,
  every Titan a mash. A team of one class each could have the same press twice.
- Concept: the canvas "New Arena Concepts", board "Quick presses: how they pop up" (A a row of cards, B over
  the animal, C round the cursor). A side placement was tried in the game (STATION-127) first.
- SHANNON, 2026-11-24: "do option B for the QTEs and make each QTE assigned to one of the four classes like
  attack defense utility"; on the side placement: "the QTEs are too far off to the side now, just do it like
  you would in that option B"; then "make the QTEs more compact and try to not block the enemies with them".

## What

- A press is its animal's class's (`BattleRules.PRESS_OF_ROLE`): attack a ring, defense a needle, utility a
  chain, Titan a mash. A team of one of each class and its Titan has all four presses. The species and
  variant tables of decision 0106 are gone; a new species needs nothing. The presses' windows and pay are
  unchanged.
- The pop-ups (display only, `stations-client/PressPops.luau`): each stands by its own animal, tied to it
  by a line in its class's colour (attack berry, defense sky, utility leaf, Titan gold), with the class's
  name on a tag at its top edge. One player's cards stand in one row just under their team, pushed apart so
  none covers another; the camera stands behind the team, so the enemies are higher on the screen and the
  cards never cover them. The cards are compact: the line says whose each is, so the card shows only what to
  do and its key. Another player's animal with a full meter gets only a small marker over its head.

## Evidence

- `BattleRules.spec`: each class's press, four classes four presses. 786 specs pass.
- Played in Studio (build dev, local, one player): a test wave 25 with a team of an attack, a utility and a
  defense animal and a Titan; three pop-ups at once in a row under the team, each tied to its animal.

## To confirm at the checkpoint

1. Which press goes with which class (ring attack, needle defense, chain utility, mash Titan). Rejected:
   swap them in `PRESS_OF_ROLE`, nothing else changes.
2. Several animals of one class in a team all get that class's press (a team of three attackers taps three
   rings).

## Not tested

Two or three real players (the markers over another player's animals); a phone's screen.
