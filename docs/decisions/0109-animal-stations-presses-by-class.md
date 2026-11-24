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

## Amended (SHANNON, 2026-11-24): the reference's look, and the ring held

- SHANNON, on a reference picture: "make the QTEs following this reference", then on the concept: "make the
  hold key indicator slightly smaller and bring it more central ... once youve refined them agin go ahead
  and add them, and also make the old hold the new circle fill hold".
- The pop-ups are drawn by `PressPops.card`: dark glass with a violet edge, key caps, a gold glow on what is
  due (green for the needle in its zone); the class tags are gone and the line to the animal is fine,
  fading, with a small ring where it meets it.
- The ring is now held while it fills (`HOLD_TENTHS`, 1.2 s). Let go early, it fires with what was held (a
  Good); held to full it fires itself, a Perfect. Clicking its plate is a plain tap (never a Perfect).
- Remote contract: `power`'s second integer is, for a ring, how long it was held in tenths of a second
  (0 to 30); the server caps it at ten a second since the meter filled, on its own clock, as it caps a mash.

## Amended again (SHANNON, 2026-11-24): no line, gone when done

- SHANNON: "the popups still persist for a bit after you complete them and somtimes pop back up and also get rid
  of the line leading the box to its animal completely"; "dont start counting clicks until the wave has started".
- No line or ring ties a card to its animal. A card that is done bursts and is gone in 0.34 s, not when the
  attack plays; a press the server turns down is sent again for up to 5 s, and only then does a fresh card show.
- Clicks count from the wave's start (`FightFrom` on each member, server time), not while the enemies walk in.

- Keys (SHANNON, 2026-11-24: "make titan mashing space bar and make the three button presses a random order of
  arrow keys ... the other two a random button between WASD each time but dont make two the same button at once"):
  `PressPops.claim` gives the mash Space, a chain three arrows in a random order (a second chain up at once three
  of W A S D), a ring or a needle a random free one of W A S D; no two cards up at once share a key. During a fight
  these keys are bound above the character's controls (`PressPops.listen`), so they never move or jump it. The
  number keys no longer press.

## Amended (SHANNON, 2026-11-24): more forgiving, with a fail

- SHANNON: "make the duration of the QTEs a bit more forgiving but give them all a fail condition as punishment
  for messing them up"; "one animal cant gen a power attack again before the player has a chance to do the last one".
- Longer: `AUTO_FIRE` 6 s (was 4), `PERFECT_EARLY` 0.35 (0.25: a wider green), `PERFECT_LATE` 0.8 (0.55),
  `MASH_BY` 4.5 (3.6).
- A fail for each: a chain key out of order, a needle stopped outside the green, a ring let go before
  `RING_FAIL` (6 tenths), a mash short of `MASH_FAIL` (4) when its time is up. The client judges it on what the
  player saw and sends `presses` = `FAILED` (-1); the meter is spent on a plain hit marked `fail` and "MISSED!"
  pops. Remote contract: `power`'s second integer is now -1 to 30. Believing the client here is safe: it can
  only cost the player.
- A meter whose tap is laid but not landed shows empty in the replay (`WaveShow`), so no second card pops for
  the same power; a full meter already holds until its press is done, failed or fired itself.

- A card left until `AUTO_FIRE` (6 s) fails too (SHANNON, 2026-11-24: "if you leave the QTE for too long that
  also fails it just like missing it"): `EXPIRE_FAILS`, a plain hit marked `fail`, MISSED!; the HUD shakes the
  card red at that time. The team list's 1 to 4 badges are gone (the number keys no longer press).

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
