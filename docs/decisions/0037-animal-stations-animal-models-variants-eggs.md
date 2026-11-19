# 0037: Animal Stations: a model for every animal, one rare variant each, egg models and a hatching animation

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Changes the variants of 0027 and 0029. Wave enemies and bosses are untouched
(SHANNON: "dont worry about enemies and bosses at the moment").

## Decision

From SHANNON: "make a model and animations for each planned animal, make a cool rarer varient for
each animal and spread them across the eggs accordingly, normal animals shouldnt go above epic and
titans are all legendary with varients always being legendary or higher, also make a cool model
for each egg and a hatching animation as well".

**Rarity rules**

- A normal animal is never above epic. Today the highest is rare (the Lion).
- A Titan is legendary.
- Every animal has **exactly one variant**, and a variant is always legendary or mythic. The three
  variants per animal (epic, legendary, mythic) of 0027 are gone, and so is the epic variant tier.
- Any hatch can be its animal's variant: 1 in 2,000 for a legendary one, 1 in 20,000 for a mythic
  one (the odds those tiers already had).

| Animal | Rarity | Variant | Variant rarity |
|---|---|---|---|
| Jackal | common | Pharaoh Jackal | legendary |
| Tortoise | common | Gemshell Tortoise | legendary |
| Meerkat | common | Storm Meerkat | legendary |
| Cheetah | uncommon | Lightning Cheetah | mythic |
| Rhino | uncommon | Lava Rhino | mythic |
| Flamingo | uncommon | Phoenix Flamingo | mythic |
| Lion | rare | Sun Lion | mythic |
| Elephant (Titan) | legendary | Frost Mammoth | mythic |

**Eggs** keep their animals, which already follow rarity: Meadow (the three commons), Wild
(commons and uncommons), Safari (uncommons and the Lion), Golden from player level 15 (the Lion,
uncommons and the Titan). A variant comes from whichever egg hatches its animal.

**Models.** All sixteen are built by script in Blender (`tools/blender/stations/assets`), in
jointed pieces like the Rhino, so the same moves (idle, walk, attack, magic attack) work for all
of them. A variant is its animal with a new skin and glowing pieces, and is bigger. The Jackal,
Cheetah, Lion and Meerkat share one predator body with their own numbers. The Flamingo has two
legs: its wings are built as the "back legs".

**Eggs and hatching.** Each egg has its own model, built from parts in the game, and opening a
finished egg plays a hatching animation before the animal steps out.

**Owned animals are seen.** A player's animals walk the roaming area of their ranch, in place of
the two showcase Rhinos.

## Costs and limits

- First-pass models: checked together on one preview sheet and in the game, not polished one by one.
- The Flamingo's wings swing like legs when it walks.
- A variant's model is named after its id ("lava_rhino" is the asset "creature_rhino_lava"); a
  test keeps the ids in that form.
