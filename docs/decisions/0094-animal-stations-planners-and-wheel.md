# 0094: Animal Stations: weekly and monthly planners, the daily wheel and boosts

Status: accepted (SHANNON, 2026-11-19: "go for option B, it all looks good", from the rewards concepts page);
built by STATION-100.
Date: 2026-11-19. Task STATION-100.

## What SHANNON chose (concept B, "grows with you")

- Coins are counted in **wave pays**: what the player's next new wave pays (`LevelRules.reward(best + 1)`),
  never under 40. Eggs are the best one the player has unlocked ("below" is the one before it).
- **Weekly planner**: a reward for each day logged in that week, claimed in order; it starts again on
  Monday (UTC). Day 1: 5 wave pays; 2: two eggs below the best; 3: 10 wave pays; 4: training x2 for 30 min;
  5: the best egg; 6: 20 wave pays and 5 samples; 7: the best egg and hatching x2 for 1 hour.
- **Monthly planner**: counts days logged in the calendar month; a missed day never resets it. Milestones:
  day 1, 10 wave pays; 3, the best egg; 7, hatching x2 for 2 hours; 10, 30 wave pays and 10 samples; 14,
  two of the best egg; 17, training x2 for 3 hours; 21, a Golden Egg; 24, 60 wave pays and 30 samples; 28,
  the month's rainbow animal (Cheetah in November 2026, then Jackal, Flamingo, Tortoise, Meerkat, Rhino,
  Lion, Giraffe, and round again).
- **Daily wheel**: one free spin a day. 2 wave pays 30%, 5 wave pays 20%, a Meadow Egg 15%, hatching x2
  for 30 min 12%, training x2 for 30 min 10%, 5 samples 8%, the best egg 4.75%, and the jackpot, a
  rainbow mythic variant at random, 0.25% (1 in 400). After 100 spins without the jackpot its chance
  doubles (taken from the first prize) until it comes.

## How (facts)

- Rules: `src/shared/StationRewards.luau` (pure), tests `tests/StationRewards.spec.luau`.
- Save schema (StationProgress): `boosts` (windows of hatching and training x2: `{ from, to }`, at most 16
  each, dropped 30 days after they end) and `rewards` (the last UTC day counted, the week and month being
  counted, days logged and rewards claimed in each, the last free spin's day, extra spins, the pity count,
  and eggs won while the storage was full, which wait and move in when there is room). Older saves load
  with both empty. `public` never sends the animals inside waiting eggs.
- Boosts: an egg's open time is `StationProgress.dueAt` (twice as fast inside a hatching window), and
  training time `trainedBetween` (twice as fast inside a training window). A new boost runs on from the end
  of one still running: longer, never stronger.
- Remote contract: new requests `rewards` (count today), `claim_week`, `claim_month(day)` and `spin`. The
  server works out the reward on a copy of the save, rolls the eggs' animals and the jackpot's mythic, then
  changes the save with them. New client events `reward` and `spun` (the prize, so the wheel stops on it).
- Client: a Gifts button in the side dock (a dot when anything can be claimed or spun) opens Gifts: This
  week, This month and the Daily wheel, with the odds shown.

## Hypotheses (to check in play)

- The planners pay roughly a day's normal earnings each week. If coins flood in, lower the wave pays.
- The 1 in 400 jackpot is rare enough to stay special (about 7% a month of daily spins).

## Not done here

- No Robux: no paid spins. Extra spins exist in the save (`spins`) but nothing gives them yet.
