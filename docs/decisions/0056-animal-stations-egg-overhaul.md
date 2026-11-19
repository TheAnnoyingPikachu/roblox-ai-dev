# 0056: Animal Stations: the egg overhaul (variants as drops of their own, eggs unlock with the waves)

Status: accepted by SHANNON on 2026-11-15 ("eggs are go make the lowest egg open from the start"); not published
Date: 2026-11-15. Changes 0031 (eggs by player level) and 0037 (a variant chance on every hatch).
Task STATION-044.

## What SHANNON asked

"overhaul the eggs to fit all creatures, make the variants their own higher tier drops and make the
eggs unlock alongside the natural progression of the game".

## Decision

- A variant is a drop of its own. Each egg lists its rare drops (`Egg.rare`): a variant and its
  chance, shown to the player as "1 in N" under the variant's portrait on the egg's card. A hatch
  rolls the egg's rare drops first; only if none hits does it roll a basic animal. The hidden roll on
  every hatch (legendary 1 in 2,000, mythic 1 in 20,000, whatever the egg) is gone.
- A variant only hatches from an egg that lists it, and no longer needs its basic animal to be in
  that egg (the Safari Egg has no Jackal but lists the Sphinx Jackal).
- Higher eggs are where the variants are: a variant gets likelier egg by egg, an animal's mythic
  starts one egg after its legendary, and no mythic of an egg is likelier than a legendary of it.
- Eggs unlock with the waves, not the player level (`Egg.wave`, the wave that must be cleared; the
  egg card says "Clear wave N to unlock"): the Safari Egg at wave 10 (the first dragon is beaten),
  the Golden Egg at wave 20 (the second). The Meadow and Wild Eggs are open from the start: the Wild
  Egg was first set at wave 5, and SHANNON asked for the lowest egg to be open from the start. Read
  as the lowest of the locked eggs, the Wild Egg, since the Meadow Egg was open already; putting
  `wave = 5` back on it is one line.
- Still no legendary-only egg (0031): every egg drops ordinary animals, and the Titan is a rare
  hatch from the Golden Egg. Prices, hatch times, XP and the basic odds are unchanged.
- A species may now have any number of variants of a tier (the hatch no longer picks by tier).

## The eggs (draft numbers)

| Egg | Unlocks | Price | Basic animals | Legendary drops | Mythic drops |
|---|---|---|---|---|---|
| Meadow | from the start | 100 | Jackal 34%, Tortoise 33%, Meerkat 33% | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 5,000 each | none |
| Wild | from the start | 1,500 | commons 54%, uncommons 46% | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 2,000 each; Fire Cheetah, Crystal Rhino, Peacock Flamingo: 1 in 4,000 each | Sphinx Jackal, Island Tortoise, Star Meerkat: 1 in 20,000 each |
| Safari | wave 10 | 15,000 | uncommons 80%, Lion 20% | Fire Cheetah, Crystal Rhino, Peacock Flamingo: 1 in 500 each; Shadow Lion 1 in 2,000 | Sphinx Jackal, Island Tortoise, Star Meerkat: 1 in 5,000 each; Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 10,000 each |
| Golden | wave 20 | 50,000 | Lion 50%, uncommons 45%, Elephant 5% | Shadow Lion 1 in 400; War Elephant 1 in 2,000 | Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 2,000 each; Sun Lion 1 in 4,000; Frost Mammoth 1 in 20,000 |

All of an egg's rare drops together: 1 hatch in about 1,670 (Meadow), 417 (Wild), 135 (Safari) and
208 (Golden). Before, any hatch was a variant about 1 time in 1,800. The Safari Egg is the richest
in variants: it is the home of the three uncommon animals' legendaries. A spec keeps an egg's whole
list under 1 hatch in 100.

The four new variants (decisions 0054 and 0055) have been in these tables since their models went
into the game on 2026-11-16.

## What changes for players

- Variants are far easier to get from the Safari and Golden Eggs than before (a Shadow Lion was
  about 1 in 4,000 Golden Eggs, now 1 in 400), a little rarer from the Meadow Egg for any one
  variant, and each can only come from the eggs that list it.
- A player now needs waves, not levels, for the Safari and Golden Eggs: one who had either by level
  but has not cleared wave 10 or 20 loses it until they do. No save changes; animals already owned
  are untouched.

## Open for SHANNON

- Whether "the lowest egg" meant the Wild Egg (as built) or only the Meadow Egg.
- A fifth, later egg (say at wave 30, the Hexfire Drake) was left out: four eggs hold every
  creature. Say if you want one.

## Not done

The basic odds are still not shown as
numbers on the card. Balance: none of these numbers has been played.
