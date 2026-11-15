# Animal Stations: the beta pool (bestiary and art brief)

Status: small beta pool, draft (decisions 0029 to 0037). Every animal below has a model in the game. Names, stats and odds are in
`src/shared/StationConfig.luau` (the source of truth). This page adds the **look** of every
version for the art pipeline.

## Stats, roles and groups

- Training raises six stats: **Speed, Strength, Stamina, Mana, Health and Defence**, each up
  to level 70 (a maxed stat is doubled). In a wave fight Speed is how fast an attack happens,
  Stamina the delay between attacks, Strength the damage, Mana how fast the power attack
  charges, Health the HP and Defence cuts incoming damage. Every animal has magical attacks, so
  even the basic versions should hint at a power (a spark, a glow, dust).
- Every animal has a **role**, set by its species: **Attack** animals hit harder, **Defence**
  animals draw the enemies' hits and take less damage, **Utility** animals heal.
- Every animal has a **group**. **Pack** animals get stronger for each other pack animal on the
  team. **Solitary** animals get stronger when no teammate shares their role.
- The **Titan** is its own category: legendary only, huge, and it fills
  the team's fourth slot. A team is three animals plus one Titan. It is a rare hatch from the
  egg that unlocks at player level 15.

## How versions work

- Every animal has a **basic** version. A normal animal is never above epic (today: common,
  uncommon or rare); the Titan is legendary.
- Every animal has **one variant**, always legendary or mythic. Any hatch of that animal, from
  any egg, can be it:

| Variant rarity | Chance per hatch | Stats | Twist |
|---|---|---|---|
| Legendary | 1 in 2,000 | basic × 2 | +40 to one stat |
| Mythic | 1 in 20,000 | basic × 3 | +60 to one stat |

- On hatch every stat gets a **base level** from 1 to 15 (higher numbers are rarer: a 15 is 1
  in 90), and 1 hatch in 10,000 has one stat at level 70 straight away.

## Art rules for every animal

- Same chunky, cute, rounded style as the concept video: big head, big eyes, short legs, soft colours.
- One silhouette per species. A variant keeps the silhouette and changes colour, material,
  accessories and effects, so players recognise the species at a glance.
- Effects grow with the tier: **epic** = new palette and one accessory; **legendary** = special
  material (gold, pearl, crystal) plus a sparkle or glow; **mythic** = a fully transformed body
  (fire, sand, stars, light) plus a constant particle trail and a rarity aura.
- The Titan is about three times the size of a rare animal, with a slow, heavy walk.
- Rarity colours for nameplates and auras: common grey, uncommon green, rare blue, epic purple,
  legendary gold, mythic rainbow shimmer.

## The look (decisions 0033, 0037)

Animals are **dangerous-looking beasts, not cute toys**: real proportions, a heavy brow over small
slanted eyes, a grim mouth, fangs, horns and claws, dark skin. **Big animals are big**, and a
variant is bigger than its basic animal, with a new skin and glowing parts. Sizes are in studs (a
player is about 5 tall).

## Pack animals

| Version | Role | Rarity | Stats (spd/str/sta/mana/hp/def) | Look | Size (tall x long) |
|---|---|---|---|---|---|
| Jackal | Attack | common | 42 / 22 / 15 / 18 / 30 / 10 | Lean sandy hunter, big pointed ears, long muzzle, dark saddle, bushy tail. | 4 x 7 |
| Pharaoh Jackal | | legendary | twist mana | Black coat, gold collar and anklets, turquoise glowing eyes and brow gem. | 5 x 9 |
| Meerkat | Utility | common | 30 / 8 / 15 / 42 / 25 / 8 | Small and quick, tan with dark bands across the back and dark eye patches. | 2 x 5 |
| Storm Meerkat | | legendary | twist mana | Thundercloud coat, glowing bands across the back, a charged tail tip. | 3 x 6 |
| Flamingo | Utility | uncommon | 30 / 10 / 30 / 65 / 50 / 15 | Tall pink wader, hooked black-tipped beak, hard stare. Two legs: its wings are built as the back legs. | 8 x 6 |
| Phoenix Flamingo | | mythic | twist mana | Fire-red, with a crest, wing tips and tail of flame. | 11 x 8 |
| Lion | Attack | rare | 55 / 90 / 40 / 25 / 70 / 30 | Faceted low-poly (decision 0050): a chunky tawny cat, a mane of big brown crystal shards, pale paws and muzzle, amber slit eyes, a tufted tail. Card: `docs/concepts/lion-card.png`. | 7 x 13 |
| Sun Lion | | mythic | twist strength | Golden, a mane of big yellow crystal shards, a star of a sun on each haunch, glowing eyes, a flame of a tail. Card: `docs/concepts/sun-lion-card.png`. | 9 x 16 |
| Shadow Lion (concept, not in the game yet) | | legendary | twist speed | Ink black, a bone mask, spine and fangs, a mane of big black crystal shards with a few glowing green ones, green ribs and eyes. Card: `docs/concepts/shadow-lion-concept.png`; the model is `creature_lion_shadow` in `tools/blender/stations/assets/lions.py`. | about 8 x 15 |
| Elephant (Titan) | Titan | legendary | 30 / 160 / 180 / 60 / 200 / 120 | War elephant: wide ears, heavy brow, long trunk and tusks. | 15 x 25 |
| Frost Mammoth | | mythic | twist health | Pale and shaggy, huge glowing ice tusks, ice spikes down its back. | 20 x 30 |

## Solitary animals

| Version | Role | Rarity | Stats (spd/str/sta/mana/hp/def) | Look | Size (tall x long) |
|---|---|---|---|---|---|
| Tortoise | Defence | common | 5 / 25 / 48 / 20 / 55 / 50 | War tortoise: high plated shell with a spiked rim, thick clawed legs, hooked beak. | 4 x 9 |
| Gemshell Tortoise | | legendary | twist defence | Dark shell with a glowing crystal on every plate. | 7 x 12 |
| Cheetah | Attack | uncommon | 70 / 35 / 20 / 20 / 45 / 15 | Slender golden sprinter with black spots and tear marks, very long tail. | 5 x 9 |
| Lightning Cheetah | | mythic | twist speed | Storm-dark coat, electric spots, glowing bolts down both flanks. | 6 x 12 |
| Rhino | Defence | uncommon | 25 / 50 / 60 / 10 / 70 / 55 | War rhino: slate hide, high shoulders with bone studs, scimitar horn, claw scars. | 8 x 14 |
| Lava Rhino | | mythic | twist strength | Obsidian hide split by glowing cracks, molten horns, rock spikes, burning tail. | 13 x 18 |

## Eggs

| Egg | Price | Hatches (basic odds) |
|---|---|---|
| Meadow Egg | 100 | Jackal, Tortoise or Meerkat |
| Wild Egg | 1,500 | commons 54%, uncommons 46% |
| Safari Egg | 15,000, from player level 10 | uncommons 80%, the Lion 20% |
| Golden Egg | 50,000, from player level 15 | the Lion 50%, uncommons 45%, the Titan Elephant 5% |

Variant chances are the same in every egg. There is no legendary-only egg (decision 0031). These
eggs are placeholders: an egg overhaul is planned.

## Parked for later

Removed from the pool for now to keep it small (their stats and variants are in decision 0027
and git history): Hyena, Warthog, Gorilla, Giraffe, Mandrill, and the Hippo and Crocodile Titans.
