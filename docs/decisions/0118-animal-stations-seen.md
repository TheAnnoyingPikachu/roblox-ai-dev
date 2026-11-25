# 0118: Animal Stations: Seen is the animals met

Status: accepted (SHANNON's pick, 2026-11-24: "Only animals actually met"; the save change approved by SHANNON
on 2026-11-25). Task STATION-158. Date: 2026-11-25.

## Context

- Fact: the Animals window's Seen tab listed every species and variant the player's open eggs could still give,
  plus the exclusive ones. Nothing in the save said what a player had come across.
- SHANNON picked "only animals actually met" on the HUD concept board: Seen is a record of what the player has
  seen in play, not a catalogue.

## What

- The save gains `met`: a list of `"species/variant"` keys (`"lion/"` for the plain species,
  `"lion/sun_lion"` for a variant). `StationProgress.meet(p, s, v)` adds one, once; a key that is not a
  species or one of its variants in `StationConfig` is never added, so the list is at most `MAX_MET` long (every
  version there is: 31 short strings today).
- What meets an animal:
  - owning it: `crack` (hatching), `give` (admin, Robux), `grant` (rewards) and a trade's `commit`
    (`StationTrade`);
  - the intro's four borrowed legends, once the borrowed fight ends (a skipped intro never shows them in a
    fight);
  - fighting beside a teammate's animals: after each wave of a shared fight, every animal in the fight is met by
    every member;
  - the Ranger's loan (STATION-159), when it is built.
- `sanitize` keeps only known keys of 64 characters or fewer, each once, and meets every animal the save owns,
  so a save from before this change starts with its own animals met. An animal released or traded away stays
  met.
- The Seen tab shows the met animals the player does not own, as dark outlines, each with the egg that gives it
  at the lowest level and that level ("From the Dusk Egg, level 18"), "From the Shop" for an exclusive one.
- `StationProgress.VERSION` goes to 4: a server from before this change refuses a save written after it
  (`tooNew`) instead of loading it and dropping `met`.

## Not changed

Eggs, odds, prices and every rule of play. `met` is read only by the Seen tab.

## If rejected

The Seen tab goes back to the open eggs' catalogue (one function in `HudAnimals`); `met` can stay in saves
unread, or `sanitize` can drop it.
