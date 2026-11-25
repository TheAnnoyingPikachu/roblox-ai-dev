# 0120: Animal Stations: 27 boons in three tiers

Status: accepted (SHANNON, 2026-11-25: "go ahead with all that stuff plus the new boons and give them that
rainbow texture", after the concept board "Boon concepts" on the HUD canvas). Task STATION-165.
Date: 2026-11-25.

## Context

- Fact: a run offered 8 boons (`WaveRuns.BOONS`): 5 common, 3 rare, the first card rare in 15% of offers.
- SHANNON asked for new boons, lucky ones and some ultra lucky ones, signed off before the pick HUD is built.

## What

- 27 boons in three tiers (`Boon.tier`): 12 common, 9 lucky, 6 ultra lucky; `rare` stays true for lucky and
  ultra (the HUD's gold edge). The list, the texts and every number are in `WaveRuns`.
- How often (`WaveRuns.won`): an offer is three cards. Its first card is ultra lucky in `ULTRA_PCT` (2%) of
  offers while the run has none yet (`Run.ultra`), lucky in `RARE_PCT` (15%) more, and lucky always after a
  boss wave; the other two are common.
- Caps (`Boon.cap`): Charged Up, Lucky Find, Gold Rush, Overcharge, Combo Chain, Titan's Roar and Jackpot Egg
  count once; Steady Paws and Watchful up to 3. Everything else stacks without limit (decision 0107).
- New fight rules, all through `BattleRules.Setup` and only on the player's side, so a fight without boons is
  as it was: damage taken (Iron Coat), meter fill (Focus), how long a full meter waits (Steady Paws), click
  strikes (Hard Taps), the shield's cooldown (Watchful, never under 1 s), +2% damage for each of the player's
  own animals standing (Pack Bond), Phoenix Feather (once a fight for each stack, the animal knocked out is
  back at once at `PHOENIX_PCT` 30%), Overcharge (a Perfect press gives back a quarter of the meter), Combo
  Chain (+1 s and x1.1 on a combo's hit), Thorns (a foe takes back 8% of what it deals, never its last HP),
  Titan's Roar (the Titan's meter starts full), Legend's Blessing (x1.15 damage, HP, speed, meter, and 1/1.15
  damage taken), Glass Cannon (x1.2 damage, x0.9 HP, each stack).
- Timed (`Run.untilWave`): Unbreakable makes the next 3 fights `immortal`; Twin Picks makes the 5 picks after
  it count twice (common and lucky; the board said "take two boons", built as the pick counting twice so a
  shared fight's vote stays one vote).

## Economy (the boons marked COINS on the board)

- Gold Rush (+25% of the wave's coins into the pot) is unchanged.
- Treasure Map: +`MAP_SAMPLES` (2) samples into the pot for each wave won, each stack.
- Golden Hour: `WaveRuns.bank` pays the pot twice over when the run is left, not after a loss (a loss keeps
  `LOSS_KEEP` % as before). In a shared fight each member's own pot doubles.
- Jackpot Egg: leaving the run (not a loss) adds the player's best unlocked egg (`StationRewards.bestEgg`) to
  the cellar, once a run (cap 1), through `StationRewards.grant` (a full cellar keeps it in the waiting
  rewards). The `banked` message carries `egg`.
- Fact: at 2% of offers and one ultra a run, Golden Hour or Jackpot Egg is in about one long run in five.

## The run simulation (decision 0107, run again 2026-11-25)

`BattleRules.battle` over whole runs from wave 1, 4 clicks a second, presses at 1.5 s, three seeds. The last
wave cleared, main's 8 boons against the 27:

| Team | Picks at random | Best picks, 8 boons | Best picks, 27 boons |
|---|---|---|---|
| Starter 8 | 19 | 19 | 19 to 29 |
| Mid 35 | 59 | 59 | 59 |
| Max 70 | 89 | 259 to 289 | 209 to 269 |

- "Best picks" for the 27: Legend's Blessing, Twin Picks, then Sharp Claws, Quick Paws, Hard Taps, Pack Bond,
  Thick Hide, Iron Coat (249 to 269); damage and speed first without Twin Picks gives 209 to 269.
- Fact: with 12 commons Sharp Claws or Quick Paws is in fewer offers, so the best team stops a little sooner;
  the wall is still reached only with a strong team and good stacks. No number was changed for it.
- Fact: taking Glass Cannon whenever offered is a trap (109 to 189): its -10% HP stacks too, as the board said.

## Not changed

The steep waves (`LevelRules`), the pot's streak, `LOSS_KEEP`, voting (`WaveRuns.tally`), the old boons' numbers.
