# 0106: Animal Stations: the pit fight (stages, the gate waking up, clicks, quick presses)

Status: accepted (SHANNON, 2026-11-22, below). The numbers are Claude's draft, to confirm at the checkpoint.
Date: 2026-11-22. Tasks STATION-119 (stages and the gate), STATION-120 (clicks and the presses) and
STATION-121 (the presses popping up, more forgiving; the action camera).

## Context

- Concept: the canvas "Arcade Arenas & Fight Loop", boards "Battle · The pit as it is" (playable) and "Plan".
  The boards are set in today's arena (decision 0046): the walled pit, the blue dais, the fanged gate.
- SHANNON, 2026-11-22: "i like this pit concept with the multipl QTE can you implement stages and the gate
  waking up the four press types", then "it should be a tapping fight where you click to attack and do QTEs
  and stuff". Asked what a click does, SHANNON picked "Clicks add strikes" (the team still attacks on its own,
  slower) and a playable board first; after trying it: "clicking should only target the front lane not any
  specific target", then "please implement it into the game".
- Not picked (still only on the board): the boss taking wing, fire rain and the team finisher.

## What

### Stages (display only)

- A stage is `LevelRules.STAGE` (10) waves and ends on the boss wave the game already has (every
  `BOSS_EVERY`th). `LevelRules.stage(wave)` gives its number, name and first and last wave. Names: 1 The
  Vanguard, 2 The Charge, 3 The Siege, 4 and 5 The Dark Host, 6 and on The Ancient.
- During a fight the HUD shows the stage at the top: its number and name and ten pips (cleared, this wave,
  the boss).

### The gate wakes up (display only)

- By the wave's place in its stage: 1 to 3 the gate watches (as built); 4 to 6 the eyes in its columns open;
  7 to 9 the braziers turn violet, a pair more each wave, from the gate towards the team; 10 the big eye
  opens and the portal burns red.
- WaveShow sets the player's `FightWave` attribute while their fight is on. `ArenaMood.client` changes this
  player's view only: the gate is shared by everyone in the server.

### Clicks add strikes (rule)

- In a run's fight (`Setup.clicks`, which `WaveRuns.setup` sets) the team's own attacks are `CLICK_SLOW`
  (2.4) times slower.
- A click anywhere on the fight is a strike: a tap with slot `BattleRules.STRIKE` (-1). The next standing
  animal of the team, in turn, hits the usual target (the front line's first Defence foe, else its first
  foe; the player never picks one) with `STRIKE_SECONDS` (0.6) seconds' worth of its attacking: its damage x
  `STRIKE_SECONDS / (swing + rest)`, splash and heal as a normal hit, and its meter gains the same share of
  its energy per attack. A strike is a normal hit in the log, marked `click`.
- A strike less than `STRIKE_GAP` (1/12 s) after the last one does nothing, so nobody strikes faster than
  12 a second whatever the client sends.
- Hypothesis (to check in play): about 4 clicks a second matches the old team's damage, 8 is about 1.6
  times it, none is 0.42 times.

### Four quick presses (rule)

Changed by decision 0109: a press is now its animal's class's (attack ring, defense needle, utility chain,
Titan mash), and the pop-ups stand by their animals under the team.

`BattleRules.pressOf(animal)` gives an animal's press from what its spell does; a Titan always mashes.

| Press | Species | Variants that differ | Perfect when |
|---|---|---|---|
| ring | lion, rhino, giraffe | Star Meerkat | `PERFECT_AT` (2.5 s) after the fill, `PERFECT_EARLY` (0.25 s) before to `PERFECT_LATE` (0.55 s) after |
| needle | jackal, tortoise, meerkat | Lava Rhino, Phoenix Flamingo | at a crossing: `PERFECT_AT` after the fill, then every `NEEDLE_EVERY` (1.5 s), same window |
| chain | cheetah, flamingo | Gemshell Tortoise | the tap comes no later than `PERFECT_AT + PERFECT_LATE` after the fill |
| mash | elephant (every Titan) | | the tap brings `MASH_COUNT` (8) presses, no later than `MASH_BY` (3.6 s) `+ PERFECT_LATE` after the fill |

- A full meter pops its press up on the screen, a card for each animal in a row across the lower middle:
  the ring closing on its mark, the needle swinging through the gold, the chain's 1-2-3 tapped in order, the
  mash's count. The plates on the right show only the name, the number key and the mana (SHANNON: "have the
  bars on the right just tell you the mana amount and have all the QTEs pop up in the screen"). The server
  judges only the tap's time and, for a mash, its presses.
- More forgiving than the ring was (SHANNON: "make the qtes a bit more forgiving on time but theres gonna be
  alot of them happening"): the window went from 0.15 s early / 0.4 s late to 0.25 / 0.55, the needle's
  swing from 1.2 s to 1.5 s (so its gold stays a fair share of the swing), the mash from 10 presses by 3.2 s
  to 8 by 3.6 s.
- Every press pays as today: a Perfect is x `PERFECT`, any other press x 1; a meter nobody presses fires
  itself after `AUTO_FIRE` and costs the third star; combos and the shield are unchanged.

### The fight's camera and spacing (display only)

SHANNON, 2026-11-22, watching a run: "do way less camera zooming", then "move the enemies further away and do
an action camera between them and the animals that pans left and right to show the front lines of the
battlefield ... only a bit further away though".

- The camera stands on the canyon's side, level with the gap between the team's front line and the
  enemies', and pans from one front line to the other and back every 9 s (`ArenaCamera.client`). It reads
  where the lines stand from the fighters, so it follows a rush as it comes on.
- No more cut-ins on the team's power hits (decision 0097 had them); only a power hit nudges the view, by
  less than before. The finish keeps its slow motion.
- The enemies stand 6 studs further off (`WaveShow`: the gap between the lines is 20 studs past their depths,
  was 14).

### Remotes (contract change)

- New `strike`: one integer 1 to 20, the clicks since the client last sent (it sends at most every 0.25 s).
  It costs 0.5 of the router's tokens, so strikes cannot starve `power` and `shield`. The server lays the
  strikes from `TAP_AHEAD` ahead of the show, `STRIKE_GAP` apart, and replays the fight; refused like a
  power tap (`no_fight`, `strike` when the fight is over or a strike would lose a won fight).
- `power` takes an optional second integer, 0 to 30: a mash's presses. The server believes at most
  `MASH_RATE` (12) a second since the meter filled, on its own clock.

### Pay and timing

- A run's fight is decided at once with the slow team and no clicks, so it is often a loss at first; a
  fight the clicks win pays when it ends, as taps already do (decision 0092). Strikes never turn a won
  fight into a loss.
- A show that has ended frees the player to start the next fight (`readyAt`), so a quick clicker does not
  wait out the slow fight's time.

## Risks

- A strike lands `TAP_AHEAD` (about 1.2 s) after its click: every tap does, since the fight is replayed with
  it (decision 0092). The HUD answers a click at once with a slash, a sound and the hit counter.
- The waves' balance (decision 0101) was set before clicks. Check it in play; `CLICK_SLOW` and
  `STRIKE_SECONDS` are the two dials.
- The click and mash counts come from the client; the server caps both by its own clock, so a claimed
  count never beats a fast hand.

## Amended (SHANNON, 2026-11-24): clicking is a bonus

- SHANNON: "clicking is a bonus that should make waves slightly easier to finish".
- `CLICK_SLOW` 1 (was 2.4: a team nobody clicked for attacked at 42% speed) and `STRIKE_SECONDS` 0.25 (was 0.6):
  four clicks a second add about a quarter to a team's damage. In the wave-1 check none of 150 fresh Meadow
  teams loses wave 1 without clicking (55% did). The late waves were retuned with it (`STEEP_GROWTH` 1.013,
  decision 0110): the best team with good picks clears 299 to 300 clicking four times a second, 289 without.

