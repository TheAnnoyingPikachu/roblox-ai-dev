# 0078: Animal Stations: the eggs spread out, a cleaner egg vendor, the rarity shown when it hatches

Status: accepted (SHANNON, 2026-11-17: "clean up the eggs menu and creature icons positioning and spread
the creatures appropriately between them and then get rid of the 1 in such and such number for the
varients and instead have an animation that says how rare it is when they hatch"). Changes decision
0056's egg rows. Task STATION-078.

## The eggs (draft numbers)

Each egg now has its own set of animals and at most seven rare finds, so they fit in one row; no egg
repeats the rare finds of the egg before it.

| Egg | Hatches (in 10,000) | Rare finds (1 in N) |
|---|---|---|
| Meadow (unchanged) | Jackal 3,400, Tortoise 3,300, Meerkat 3,300 | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat 5,000 |
| Wild | Jackal, Tortoise, Meerkat 1,000 each; Cheetah 2,400, Rhino 2,300, Flamingo 2,300 | Fire Cheetah, Crystal Rhino, Peacock Flamingo 4,000; Sphinx Jackal, Island Tortoise, Star Meerkat 20,000 |
| Safari | Cheetah, Rhino, Flamingo, Lion 2,500 each | Shadow Lion 2,000; Fire Cheetah, Crystal Rhino, Peacock Flamingo 1,000; Lightning Cheetah, Lava Rhino, Phoenix Flamingo 10,000 |
| Golden (unchanged) | Lion 5,000, Cheetah, Rhino, Flamingo 1,500 each, Elephant 500 | as before |

Before, the Wild Egg was mostly commons and listed nine rare finds (three of them the Meadow Egg's), and
the Safari Egg listed ten, including the commons' mythics.

- Fact: every variant is still a drop of some egg, no mythic is likelier than a legendary of its egg,
  and at most one hatch in a hundred is a variant (the specs).
- Lost: the commons' legendaries are only in the Meadow Egg now, and their mythics only in the Wild Egg.

## The egg vendor

Each card has the egg, its price and time; under HATCHES the animals it gives, each with its name under
its picture; under RARE FINDS its variants in one row, each edged in its tier's colour. The "1 in N" under
each variant is gone. Every card is the same size.

## The hatch

When an egg opens, its rarity pops up in the middle of the screen in its colour (COMMON, RARE!,
LEGENDARY!!, MYTHIC!!!): bigger, longer and with a shake the rarer it is, over the animal's name and, for
a rare find, "Only 1 in N <egg>s hatches one"; a rainbow coat adds a line. It takes the place of the
message that said what hatched. A jackpot stat still shows its message.

## Not done

Not looked at on a phone. The reveal was tried in Studio with a Lava Rhino sent by hand, not a real hatch.
