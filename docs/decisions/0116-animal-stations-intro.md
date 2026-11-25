# 0116: Animal Stations: the intro (borrowed legends)

Status: accepted (SHANNON, 2026-11-24: "we will do the legendary loan team when they join as a taster", then "go
for your choice of C and implement what youve shown me"); the wave and the numbers are Claude's draft, for the
checkpoint. Task STATION-142. Date: 2026-11-24.

## Context

- Fact: a new player started with 300 coins, no animals and a menu, and had to buy, hatch and wait before the
  first fight. Beta blocker 11 is a taster of the game at its best in the first minutes.
- Fact: a fight is one deterministic simulation that is run again as taps arrive (`BattleRules.battle`). It
  cannot be paused, so the boards' "the fight waits for you" is not built as drawn.

## What

- A save that has not done the intro sees one card at its ranch, and nothing else: the Ranger lends four
  legends for one battle (Sphinx Jackal, Lava Rhino, Phoenix Flamingo, War Elephant: one of each class and the
  Titan, each at level 1, real animals from real eggs). One button, To battle (Space). "Skip intro" shows
  after ten seconds.
- The borrowed fight is wave 40, the Shadow Dragon's, on the real field with the real HUD. Its setup is
  `StationIntro.SETUP`: the pit fight's clicks, four times the team's health (the Ranger's blessing: no legend
  drops under two thirds untouched), and `immortal`, a new `BattleRules.Setup` field under which nobody on the
  team can lose its last point of health. Whatever the player presses or does not press, it is won, in about a
  minute untouched and about forty seconds played.
- Four lessons show during it, one line at a time with four steps that turn gold: tap the enemies (ten
  strikes), hold a ring, raise the shield, mash the Titan's finisher. They are chances, not gates: a missed
  press comes round again in seconds and the fight never stops.
- Winning (or skipping) ends the intro, once: the save's `intro` is set and three starter eggs go into the
  nests already hatching, with a Jackal, a Tortoise and a Meerkat inside: one animal of each class. A starter
  egg (`quick`) hatches in 5 seconds. The goal strip takes over from there ("Hatch a team of three").
- The borrowed fight pays nothing, opens no wave and counts for no best or stars.
- Save: `intro` (true once done), `quick` on a held egg. A save from before the intro that has an animal, an egg
  or a cleared wave counts as done. No new version: it ships with decision 0115's (2).
- Remote contract: `intro("fight" | "skip")`; one new message, `intro`, when the borrowed fight is won.

## Not built from the boards

- The fight waiting for each lesson (see Context). A lesson is shown while it can be done instead.
- The legends leaving outlines in Animals ("Seen", STATION-140).
- The Ranger lending one legend again for the wave 10 boss, then once a day (the board's pick 2).

## To confirm at the checkpoint

1. The four legends, and the fight on wave 40 with four times their health.
2. Skipping gives the same starter eggs as winning.
3. The starter team is fixed (Jackal, Tortoise, Meerkat) rather than rolled, so every player starts with the
   three classes. Players keep the 300 starting coins as well.
4. Whether to build the second loan (wave 10's boss, then daily).

## Amended 2026-11-25 (STATION-157, SHANNON's picks)

- Finishing or skipping the intro also gives `StationIntro.COINS` (300) with the three Starter Eggs, so the first
  Meadow Egg (100) can be bought at once. Logged as `intro` (Gameplay) by Analytics.
- The borrowed fight is `patient` (`BattleRules.Setup`): a full meter never fires or fails by itself, so a press
  bubble stays until the player does it or the fight ends. Only the intro uses it.
- The lessons stay chances, not pauses (the fight cannot be paused), but each one is spotlit: when its press card or
  the shield is up, the field darkens under the HUD and a gold ring pulses round it.
