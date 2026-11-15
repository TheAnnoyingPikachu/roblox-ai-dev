# 0056: Animal Stations: the egg overhaul (variants as drops of their own, eggs unlock with the waves)

Status: proposed (built on the branch for SHANNON to judge; not published)
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
  egg card says "Clear wave N to unlock"): the Wild Egg at wave 5 (the ogres have been met), the
  Safari Egg at wave 10 (the first dragon is beaten), the Golden Egg at wave 20 (the second).
- Still no legendary-only egg (0031): every egg drops ordinary animals, and the Titan is a rare
  hatch from the Golden Egg. Prices, hatch times, XP and the basic odds are unchanged.
- A species may now have any number of variants of a tier (the hatch no longer picks by tier).

## The eggs (draft numbers)

| Egg | Unlocks | Price | Basic animals | Legendary drops | Mythic drops |
|---|---|---|---|---|---|
| Meadow | from the start | 100 | Jackal 34%, Tortoise 33%, Meerkat 33% | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 5,000 each | none |
| Wild | wave 5 | 1,500 | commons 54%, uncommons 46% | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 2,000 each; Fire Cheetah 1 in 4,000 | Sphinx Jackal 1 in 20,000 |
| Safari | wave 10 | 15,000 | uncommons 80%, Lion 20% | Fire Cheetah 1 in 500; Shadow Lion 1 in 2,000 | Sphinx Jackal 1 in 5,000; Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 10,000 each |
| Golden | wave 20 | 50,000 | Lion 50%, uncommons 45%, Elephant 5% | Shadow Lion 1 in 400; War Elephant 1 in 2,000 | Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 2,000 each; Sun Lion 1 in 4,000; Frost Mammoth 1 in 20,000 |

All of an egg's rare drops together: 1 hatch in about 1,670 (Meadow), 555 (Wild), 333 (Safari) and
208 (Golden). Before, any hatch was a variant about 1 time in 1,800.

The four variants that are still concepts (decisions 0054 and 0055) get rows when their models are
in the game. Proposed: Crystal Rhino and Peacock Flamingo beside the Fire Cheetah (Wild 1 in 4,000,
Safari 1 in 500); Island Tortoise and Star Meerkat beside the Sphinx Jackal (Wild 1 in 20,000,
Safari 1 in 5,000).

## What changes for players

- Variants are far easier to get from the Safari and Golden Eggs than before (a Shadow Lion was
  about 1 in 4,000 Golden Eggs, now 1 in 400), a little rarer from the Meadow Egg for any one
  variant, and each can only come from the eggs that list it.
- A player now needs waves, not levels: the Wild Egg, open to everyone before, needs wave 5. A
  player who had the Safari or Golden Egg by level but has not cleared wave 10 or 20 loses it until
  they do. No save changes; animals already owned are untouched.

## Open for SHANNON

- The numbers: every chance in the table, and the three waves (5, 10, 20).
- Players who lose an egg they had (above). Recommended: accept it while the game is in beta; the
  other way is to keep an egg open for anyone at its old level as well.
- A fifth, later egg (say at wave 30, the Hexfire Drake) was left out: four eggs hold every
  creature. Say if you want one.

## Not done

The egg card's row of rare drops holds seven portraits; an egg with more (the Wild and Safari Eggs
once the concept variants are in) needs the row to wrap. The basic odds are still not shown as
numbers on the card. Balance: none of these numbers has been played.
