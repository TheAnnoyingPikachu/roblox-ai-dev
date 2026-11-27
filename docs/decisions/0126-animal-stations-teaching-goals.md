# 0126: Animal Stations: teaching goals and a reward every 5 player levels

Status: accepted (SHANNON, 2026-11-27, Round 2 of the decision pass, build 4 A: "Teaching goals woven between the
boss goals ..., plus a reward every 5 player levels", then "yes builds"). The goals' wording and rewards are
Claude's. Task STATION-186. Date: 2026-11-27.

## What

- Five teaching goals in `StationGoals.LIST`, each after a stage's boss goal (decision 0115):

| After | Goal | Reached when | Pays |
|---|---|---|---|
| boss10 | Upgrade your Barn | Barn level 1 or more | 3 wave pays |
| boss10 | Build the Windmill | Windmill level 1 or more | 5 samples |
| boss20 | Put a Titan in its slot | the Titan slot is filled | 4 wave pays, 4 samples |
| boss30 | Own an animal with a coat | any coat | 5 wave pays |
| boss50 | Fuse four of a coat into a better one | a coat of tier 2 or more | the best egg |

- `StationGoals.LEVELS`: player levels 5, 10, ... 100 each pay once: 4 wave pays and level / 5 x 2 samples, the
  best egg on every tenth. They are kept in the save's `goals` list (ids `lvl5` to `lvl100`) and paid by the same
  `payGoals` as soon as reached; the toast reads "Goal done: Reach player level 5".
- Data schema: `StationProgress.MAX_GOALS` 64 to 128 (the list is 39 goals and 20 level rewards).
- A save that already passed a boss gets the teaching goals after it next, and is paid at once for any it has
  already done.

## Not changed

The boss goals and the four starter goals and what they pay; the goal strip shows the list's next goal only.
