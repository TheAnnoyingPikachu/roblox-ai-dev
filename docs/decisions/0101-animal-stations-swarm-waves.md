# 0101: Animal Stations: swarm waves

Status: accepted (SHANNON, 2026-11-19: "go ahead with all of that", from the swarm plan on the power scores
page); built by STATION-108.
Date: 2026-11-19. Task STATION-108.

## What

- **Crowds:** waves send more enemies (`LevelRules.CROWDS`).

  | Waves | Enemies | Rushes | Elites | Minions | Power factor |
  |---|---|---|---|---|---|
  | 1 to 4 | 4 | 1 | 0 | 1 | 1 |
  | 5 to 9 | 6 | 1 | 0 | 3 | 1.1 |
  | 10 to 19 | 8 | 2 | 0 | 4 | 1.4 |
  | 20 to 39 | 12 | 2 | 1 | 6 | 1.75 |
  | 40 and up | 16 | 3 | 2 | 8 | 2.1 |

  - Each rush sends its minions first, then regulars drawn from the old line, elites last.
  - A boss wave's dragon takes the last place.
  - Minions are the new Gloom Imp (fast, frail). Elites are regulars x1.6 in every stat, edged in gold.
- **Same difficulty:**
  - The old three-foe wave stays as `LevelRules.classic`, and its power is the wave's power
    (`LevelRules.power`, shown in the match-up).
  - A swarm's stats are scaled by one number until its power is within 5% of the classic wave's power x
    the row's factor.
  - The factors grow with the crowd, since a crowd's power sum is worth less against the team's splash,
    crowd power attacks and the front line. They are set so that 98 to 99% of test fights (four test teams
    at four training levels, waves 1 to 140) end as they did against the classic waves.
  - Wave pay is unchanged.
- **Rules for crowds** (`BattleRules`, side 1 only for the team's moves):
  - The front line: at most 6 enemies attack at once; the next steps up when one falls.
  - Rushes: the next rush is called when half of the last is down or 8 s after it arrived, and lands 2 s
    later.
  - Splash: an Attack animal's normal hit also strikes the next enemy for 50%.
  - Power attacks strike up to 4 more enemies for 60%.
  - A Defence animal's power attack knocks the enemies it strikes back 1 s.
  - A Utility animal's power attack heals the whole team.
  - Still decided by the server and replayed exactly with taps.
- **The arena:**
  - Enemies stand in rows of 6; later rushes wait behind the gate and run in when called.
  - An enemy that joins the front line steps into a fallen one's place.
  - Splash and crowd hits show on every enemy struck, and knock-backs push the line back.
  - A knockout counter pops, three coins fly from each fallen enemy to the coin counter (display only),
    and a power bar shows each side's power still standing.
  - Small hits on one enemy merge into one number; at most 12 numbers float at once.
- **The third star** (decision 0097) now rewards firing every power attack yourself. Crowd fights are too
  short for the old time target.
- **The Waves menu** shows one card per kind of enemy with how many come and an ELITE tag, each with its
  share of the wave's power, and the rush count.

## Not done

- Models are spawned for each wave, not kept for a whole run (the plan's pooling).
- The phone-emulator check is not done.
