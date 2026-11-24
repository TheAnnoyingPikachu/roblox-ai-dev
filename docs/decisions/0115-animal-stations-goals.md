# 0115: Animal Stations: goals

Status: accepted in principle (SHANNON, 2026-11-24, with the concept boards); the list and the numbers are
Claude's draft, for the checkpoint. Task STATION-137. Date: 2026-11-24.

## Context

- Fact: a new player had nothing on screen that said what to do next. The Explore and IntroOwn boards put
  one goal at the top of the HUD, always, with what it pays.
- Fact: rewards already have rules (`StationRewards`, decision 0094): coins in "wave pays", so a reward is worth
  the same at any point of the game, and eggs that go to the storage or wait when it is full.

## What

- `StationGoals` (pure, specs in `tests/StationGoals.spec.luau`): a fixed, ordered list. The first goal a save
  has not finished is the goal on screen.

  | Goal | Reached when | Pays |
  |---|---|---|
  | Hatch a team of three | the save holds 3 animals | 2 wave pays |
  | Clear wave 3 | best wave is 3 | 4 wave pays |
  | Train a stat up a level | any stat of any animal is above level 1 | a Wild Egg |
  | Open one of today's gifts | a planner reward or a wheel spin was ever taken | 3 samples |
  | Beat the wave 10 boss | best wave is 10 | a Safari Egg |
  | Beat the wave 20, 30 ... 300 boss | best wave reaches it | 6 wave pays and 2 samples for each stage; every fifth stage the best egg the player has unlocked instead |

- The server pays a goal the moment the save shows it reached (after every change, `onChanged`), one after
  another, and tells the player (`fx` "goal"). A returning save is caught up the same way.
- Save: `goals`, the ids finished (16 characters at most, 64 kept). `StationProgress.VERSION` goes to 2, so an
  older server cannot load a save with goals, strip them and let them be paid twice.
- Remote contract: nothing new from the client. One new message to it: `goal` `{ text, items }`.
- Analytics: the coins and samples a goal pays are logged as Gameplay, reason `goal`.

## To confirm at the checkpoint

1. The list and what each goal pays. The Safari Egg at the first boss is a taste of an egg the player cannot
   buy yet (level 5); it still takes an hour to hatch.
2. Stage bosses pay about 720 samples over all thirty stages. If that is too many for the ranch's prices,
   lower `2 * stage`.
3. Goals pay by themselves, with a message. Rejected: a Claim button, which is one more thing to learn.
