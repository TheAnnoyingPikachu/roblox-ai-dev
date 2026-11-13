# Animal Stations: the beta pool (bestiary and art brief)

Status: small beta pool, draft (decisions 0029 to 0031). Names, stats and odds are in
`src/shared/StationConfig.luau` (the source of truth). This page adds the **look** of every
version for the art pipeline.

## Stats, roles and groups

- Training raises six stats: **Speed, Strength, Stamina, Mana, Health and Defence**, each from
  level 0 to 70 (a maxed stat is doubled). Health is HP, Defence cuts incoming damage, Mana sets
  how often an animal uses its power attack. Every animal has magical attacks, so even the basic
  versions should hint at a power (a spark, a glow, dust).
- Every animal has a **role**, set by its species: **Attack**, **Defence** or **Utility**.
  Attack beats Utility, Utility beats Defence, Defence beats Attack.
- Every animal has a **group**. **Pack** animals get stronger for each other pack animal on the
  team. **Solitary** animals get stronger when no teammate shares their role.
- The **Titan** is its own category outside the role loop: legendary only, huge, and it fills
  the team's fourth slot. A team is three animals plus one Titan. It is a rare hatch from the
  egg that unlocks at player level 15.

## How versions work

- Every non-Titan species has a **basic** version: common, uncommon or rare.
- On top of that, every hatch from any egg rolls for a **variant** of that species:

| Tier | Chance per hatch | Stats | Twist |
|---|---|---|---|
| Epic | 1 in 200 | basic × 1.5 | +25 to one stat |
| Legendary | 1 in 2,000 | basic × 2 | +40 to one stat |
| Mythic | 1 in 20,000 | basic × 3 | +60 to one stat |

- On hatch every stat gets a **base level** from 1 to 15 (higher numbers are rarer), and 1
  hatch in 100,000 has one stat at level 70 straight away. The Titan has no variants.

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

## Pack animals

| Version | Role | Rarity | Stats (spd/str/sta/mana/hp/def) | Look |
|---|---|---|---|---|
| Jackal | Attack | common | 42 / 22 / 15 / 18 / 30 / 10 | Slim tan jackal with a dark back and big pointed ears. |
| Dune Jackal | | epic | twist stamina | Pale gold coat, a desert scarf, kicks up small sand swirls. |
| Golden Jackal | | legendary | twist strength | Polished gold fur with a glint sweep and amber eyes. |
| Pharaoh Jackal | | mythic | twist mana | Black and gold, a striped headdress, glowing blue glyphs floating around it. |
| Meerkat | Utility | common | 30 / 8 / 15 / 42 / 25 / 8 | Small sandy meerkat standing upright, dark eye patches, always alert. |
| Scout Meerkat | | epic | twist speed | Tiny binoculars and a scout neckerchief. |
| Sandmage Meerkat | | legendary | twist mana | Little robe and staff, a ribbon of sand spiralling around it. |
| Mirage Meerkat | | mythic | twist speed | Shimmering heat-haze body with two flickering mirror copies beside it. |
| Flamingo | Utility | uncommon | 30 / 10 / 30 / 65 / 50 / 15 | Bright pink flamingo standing on one leg. |
| Sunset Flamingo | | epic | twist stamina | Feathers fade from orange to purple like a sunset. |
| Pearl Flamingo | | legendary | twist mana | Pearly white sheen with a pearl-drop crest. |
| Phoenix Flamingo | | mythic | twist strength | Feathers of fire, an ember trail, a flare when it spreads its wings. |
| Lion | Attack | rare | 55 / 90 / 40 / 25 / 70 / 30 | Tawny lion with a big fluffy mane and a proud chest. |
| White Lion | | epic | twist health | Snow-white coat and mane, pale blue eyes. |
| Sun Lion | | legendary | twist mana | The mane is a ring of golden sun rays that slowly turns; warm glow. |
| Constellation Lion | | mythic | twist strength | Night-sky body with star lines tracing its shape, a mane of drifting stardust. |
| **Elephant** | **Titan** | legendary | 30 / 160 / 180 / 60 / 200 / 120 | Huge grey elephant with gold-capped tusks and painted ear patterns; the ground shakes. |

## Solitary animals

| Version | Role | Rarity | Stats (spd/str/sta/mana/hp/def) | Look |
|---|---|---|---|---|
| Tortoise | Defence | common | 5 / 25 / 48 / 20 / 55 / 50 | Olive tortoise with a domed patterned shell and a kind face. |
| Mossback Tortoise | | epic | twist mana | Shell covered in moss, tiny flowers and a mushroom or two. |
| Gemshell Tortoise | | legendary | twist defence | Shell plates are cut gems in different colours that catch the light. |
| Island Tortoise | | mythic | twist health | Carries a tiny island on its back: a palm tree, a waterfall, a little cloud. |
| Cheetah | Attack | uncommon | 70 / 35 / 20 / 20 / 45 / 15 | Golden-tan cheetah with black spots and tear marks. |
| Shadow Cheetah | | epic | twist mana | Black coat with faint violet spots and glowing violet eyes. |
| Golden Cheetah | | legendary | twist strength | Metallic gold coat with darker gold spots. |
| Lightning Cheetah | | mythic | twist speed | Electric-blue spots, crackling arcs along the body, fading afterimages. |
| Rhino | Defence | uncommon | 25 / 60 / 65 / 10 / 75 / 60 | Grey rhino with a big front horn and armour-like skin folds. |
| Stone Rhino | | epic | twist defence | Carved from sandstone with painted patterns. |
| Crystal Rhino | | legendary | twist mana | Clear crystal horn and crystal plates along the back. |
| Thunder Rhino | | mythic | twist speed | Storm-cloud hide, a lightning-bolt horn, rumbles when it charges. |

## Eggs

| Egg | Price | Hatches (basic odds) |
|---|---|---|
| Meadow Egg | 100 | Jackal, Tortoise or Meerkat |
| Wild Egg | 1,500 | commons 54%, uncommons 46% |
| Safari Egg | 15,000 | uncommons 80%, the Lion 20% |
| Golden Egg | 50,000, from player level 15 | the Lion 50%, uncommons 45%, the Titan Elephant 5% |

Variant chances are the same in every egg. There is no legendary-only egg (decision 0031). These
eggs are placeholders: an egg overhaul is planned.

## Parked for later

Removed from the pool for now to keep it small (their stats and variants are in decision 0027
and git history): Hyena, Warthog, Gorilla, Giraffe, Mandrill, and the Hippo and Crocodile Titans.
