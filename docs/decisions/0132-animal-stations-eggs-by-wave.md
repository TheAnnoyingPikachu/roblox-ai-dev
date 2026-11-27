# 0132: Eggs unlock by wave again; training XP by time; the level in the player list

Date: 2026-11-27. Status: accepted (SHANNON). Task: STATION-194.

## Context

SHANNON asked whether the XP rate is right. The review (facts from the formulas, not a playtest):

- Level L takes 25 x (L - 1)^2 XP (level 100: 245,025). About three quarters of a player's XP is first wave
  clears (10 + 4 per wave), so the player level mostly copied the best wave: first clears alone give level 21 at
  wave 70, 44 at wave 150, 72 at wave 250 and 82 at the wall (284).
- Training paid 5 XP a stat level, whether the level took 2 minutes or 36 hours: one animal trained to the top
  earned less than one Ivory Egg.

SHANNON: "change what you see to be necessary and lock eggs behind waves again instead of level but keep levels in
the game as a way for players to show off their playtime and such".

## Decision

1. **Eggs unlock by the best wave** (as decision 0056 had it), each on a boss wave, chosen where the player level
   that opened it was reached by first clears:

   | Egg | Was (player level) | Now (best wave) |
   |---|---|---|
   | Safari | 5 | 10 |
   | Golden | 8 | 20 |
   | Dusk | 12 | 40 |
   | Oasis | 16 | 50 |
   | Ivory | 24 | 80 |
   | Legend | 32 | 100 |
   | Mythic | 42 | 140 |
   | Divine | 54 | 180 |
   | Celestial | 68 | 230 |
   | Crown | 85 | 260 |

   The Meadow and Wild Eggs are open from the start. The Crown Egg at 260 is past the wall's start (250) and
   below the best runs (268 to 284, decision 0125). `canBuy` and `StationRewards.bestEgg` read `p.best`.
2. **Training pays XP by time**: a stat level pays one XP for every `XP_TRAIN_SECONDS` (600, ten minutes) it takes
   to train, at least `XP_STAT_LEVEL` (5) (`StationProgress.trainXp`). One stat 0 to 70: 799 XP over 109 hours (was
   350); 70 to 140 (the star levels): 13,110 XP over 2,190 hours (was 350). Six stations busy all day add about
   860 XP a day in the star levels.
3. **The level is for show**: the player list (leaderstats) shows `Level`; the level card shows the XP to the next
   level; a new egg gets the same card ("<egg> unlocked! For beating wave N") when a new best wave opens it. The
   level rewards (decision 0126) and the trade's minimum level stay.

## Not changed

Wave XP, egg XP and the level curve. Meadow Egg XP farming (about 6,000 XP an hour from ten nests) was looked at
and left: with eggs unlocked by wave it only speeds the level, which is now for show.
