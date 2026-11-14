# 0042: Animal Stations: the Hexbound in the game, with evil auras, and the admin test wave

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0040 and 0041.

## Decision

From SHANNON: "how taxing on people systems would it be to give them evil auras to obscure their
lacklustre look a bit? also run a test wave in game".

- **The five enemy models are baked, uploaded and in the game**, each rigged like an animal.
  A tier of a kind is the same model with its own size and tint, set in its `StationConfig.FOES`
  entry (`model`, `size`, `tint`), so there are still only five models.
- **Evil aura.** Every Hexbound carries one, built into its model: a pale green pool of light on
  the ground, dark smoke rising off its footprint, a few hexfire sparks, and one soft light with no
  shadows. About 25 live particles and one light each. They are built once into the model, so the
  server does no work while they run, and the cost scales with the enemies in view, not with players.
  **Measured in Studio** with 42 enemies on screen at once (14 times a real wave, about 2,200 live
  particles): 16.7 ms a frame with the auras on and with them off, the same, on a desktop capped at
  60 fps. Not measured on a phone.
- **Animations for the enemies.** The two-legged ones (knight, archer, mage, ogre) have their own set:
  a heavy walk with the arms swinging against the legs, a sword or club chop, a bow shot, a spell
  cast, a power attack with both arms thrown up, a hit reaction and a fall onto the back. The dragon
  uses the four-legged poses and beats its wings (a slow beat at rest, a hard one when it attacks).
  Animals and enemies also got a hit reaction and a defeat (an animal rolls onto its side).
- **The test wave.** In the Admin menu (owner and Studio only), a "Test wave" button plays one wave
  in the arena canyon: your team on one side, the wave's enemies walking in from the other, then the
  fight replayed from the rules' own log (`BattleRules.battle` now takes an optional log; it cannot
  change a result). Each attack plays its animation and its hit lands when the log says; health bars
  drop, damage and healing numbers float, the fallen fall. The server decides nothing here and saves
  nothing: coins, XP and progress are untouched. The team is your own team, the three starters, or a
  fully trained best team (three mythics and the Frost Mammoth).
- **The hover card shows enemies too** (name, "Hexbound <kind>", role, group, stats, health) and
  health in a fight, with the team's bonuses.

## Why

- Auras cost almost nothing and do hide a plain model: a glowing pool and drifting sparks make each
  one read as a threat from a distance.
- Replaying the rules' own log means the show can never disagree with the result.

## Costs and limits

- This is a replay for looking at, not the real wave fight: nothing earns coins or samples yet, and
  nothing runs it for ordinary players.
- No ranged attacks: an archer or mage stands still and "shoots" at the front of the line.
- First-pass animations, seen as stills and in motion only for a few waves.
- Phones: not tested. The world is about 15,000 parts before any fight.
