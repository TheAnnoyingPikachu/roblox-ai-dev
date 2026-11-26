# 0121: Animal Stations: the decision pass before release

Status: accepted (SHANNON, 2026-11-26, in the doc "Animal Stations: your decision pass": 49 questions answered,
then "done, go ahead with all of the choices"). Task STATION-176 makes the economy changes; the other picks are
recorded here and done in their own tasks. Date: 2026-11-26.

## Context

- Fact: a completion review (2026-11-25) and a check of the "before release" plan against the code
  (2026-11-26) left 49 open questions. SHANNON answered them in one doc, each with options and Claude's pick.
- Fact: "Talk first" means SHANNON wants to discuss it before anything changes; "Not now" means no change.

## The answers

Economy and pacing:

1. Pacing bands, A: session 1 ends at wave 10 to 20; day 1 at 20 to 25 with a Wild animal; week 1 at 30 to 40
   with a Titan possible; month 1 at 50 to 60. A target to tune against, not yet a test.
2. Replay pay, A: 40% of a wave's first-clear coins (was 25%). `LevelRules.REPLAY_PCT`.
3. The egg gap, A: the Safari Egg costs 6,000 coins (was 15,000, ten times the Wild Egg's 1,500).
4. The first Titan, A: the wave 20 boss goal pays a plain Elephant, once a save (it paid 6 wave pays and 4
   samples). `StationRewards.Spec.animal`, `StationGoals`.
5. Training tail: talk first. 6. Ranch animals earning while away: talk first.
7. Difficulty, A: every wave matched to a smooth target, checked by a test (its own task).
8. Power presses, A: in a run the player's meters fill `BattleRules.PLAYER_FILL` (2) times as fast; the
   Legion's are unchanged.
9. Wave 300, B: the last waves are steeper so wave 300 stays out of reach (`LevelRules.END_FROM`,
   `END_GROWTH`).

Robux and trading: 10 to 15 not now (tradable Eternals, guardrails, prices, what else is sold, the odds
record, the trading record). Trading stays off (`StationTrade.ON`).

Second half: 16 A then C (stage names for stages 6 to 30 and a boss rotation from existing foes now, new
stages in updates later); 17 C (one battlefield); 18 not now (a second tier of upgrades); 19 talk first (the
Windmill); 20 A (the six parked species after launch, as update eggs).

Polish: 21 A (music and sound volume, and mute); 22 A (the game's own ranch and hub music); 23 A (its own fight
tracks); 24 A (its own hit sounds and a training sound); 25 not now (Eternal's colour); 26 A (text of 12 px or
more).

Fights, goals and friends: 27 A (a loss names the cheapest change that wins); 28 A (goals that teach upgrades,
the Windmill, fusing, coats and the Titan, and a reward every few player levels); 29 A (a best-wave
leaderboard and "Visit a ranch"); 30 A (a welcome-back card); 31 A (the gear line removed); 32 B (no
playtests with children).

Housekeeping: 33 A (Claude lists the merged tasks for SHANNON to accept); 34 A (tests for the save version,
the trade ledger and banking the run pot, and a compile check of every script in CI); 35 A (rollback and
data-erasure runbooks); 36 A (a failed model load becomes an analytics event); 37 A (the game's CLAUDE.md
fixed).

Launch and after: 38 A (Kids and Select on SHANNON's account: 2FA, the age check, Plus or Premium, the
questionnaire aiming for Mild); 39 B (no paid push); 40 C, "Jungle Rumble", with "S1 savannah" and
"smackdown" noted beside it (the exact title to confirm); 41 A (an update every second Saturday); 42 A (a
short list of values tunable live within approved ranges); 43 B (a few big languages before launch).

Later, with the launch plumbing: 44 B (the beta universe becomes production and keeps its saves); 45 not now
(the paid coat); 46 C (no beta gift); 47 B (launch with the Robux shelf hidden); 48 B (painted store art from
ForgeGUI); 49 A (Claude checks phones and lag first, then a session with friends).

## What STATION-176 changes

- `LevelRules.REPLAY_PCT` 25 to 40. The Waves menu says "A wave you have cleared pays 40% again."
- The Safari Egg's price 15,000 to 6,000.
- `BattleRules.PLAYER_FILL = 2`: a run's `setup` multiplies its team's `gain` by it, after Focus. Fights with no
  setup (the intro, admin test fights, the rules' own tests) are unchanged, and so is every foe.
- `LevelRules.END_FROM, END_GROWTH = 250, 1.08`: `might` multiplies by `END_GROWTH ^ (level - END_FROM)` after
  wave 250. Waves up to 250 are as they were.
- The goal `boss20` pays `{ animal = "elephant" }`. `canGrant` needs room in the barn for it, like a rainbow
  reward; `grant` gives a plain level 1 Elephant. A save that already finished `boss20` gets nothing new.

## Simulation (2026-11-26)

`BattleRules.battle`, 4 clicks a second, presses 1.5 s after a meter fills.

Power presses in a fight, before and after `PLAYER_FILL`:

| Team | Waves | Before | After |
|---|---|---|---|
| Three level 1 starters | 1, 2, 3, 5, 8 | 1, 1, 1, 1, 2 | 3, 3, 2, 3, 3 |
| Level 8 starters | 5, 10, 15 | 2, 4, 4 | 3, 7, 4 |

Whole runs, best picks (Legend's Blessing, Twin Picks, then damage, speed and defence), 12 seeds, last wave
cleared:

| Team | Before (no wall) | After (wall from 250, 8% a wave) |
|---|---|---|
| Max 70 | 169 to 300, two of 12 cleared 300 | 169 to 289 |
| Best 70 | 249 to 300, six of 12 cleared 300 | 249 to 279 |

- Damage-first picks: 169 to 279 and 249 to 289. Random picks: 89 to 199. No run cleared wave 300.
- Assumption: a party of two or three is not simulated; the crowd grows with the party (decision 0108), and a
  party can probably go further than one player.
- Fact: an extra wall from 250 at 3% or 5% a wave still let the best team clear 300 in 12 seeds.

## Not changed

Prices of every other egg, `REWARD_GROWTH`, `STEEP_FROM`, `STEEP_GROWTH`, `STEEP_BEND`, `POWER_COST` (halving it
sped up the Legion's power attacks too and broke the intro's "cannot be lost"), the boss chests.
