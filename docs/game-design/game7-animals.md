# Animal Stations: the African beta pool (bestiary and art brief)

Status: beta pool, draft (decision 0027). Names, stats and odds are in
`src/shared/StationConfig.luau` (the source of truth). This page adds the **look** of every
version for the art pipeline. The first farm-and-forest roster (0020) is retired.

## Stats and roles

- Training raises four stats: **Speed, Strength, Stamina and Mana** (0026). Every animal has
  magical attacks, so even the basic versions should hint at a power (a spark, a glow, dust).
- Every animal has one of three **roles**, set by its species: **Attack** (hits hard), **Defense**
  (draws hits and shrugs them off) and **Utility** (heals). They form a rock paper scissors loop:
  Attack beats Utility, Utility beats Defense, Defense beats Attack.
- **Titans** are their own category outside the loop: legendary, huge, and they fill the team's
  fourth slot. A team is three animals plus one Titan.

## How versions work

- Every non-Titan species has a **basic** version: common, uncommon or rare.
- On top of that, every hatch from any egg rolls for a **variant** of that species:

| Tier | Chance per hatch | Stats | Twist |
|---|---|---|---|
| Epic | 1 in 200 | basic × 1.5 | +25 to one stat |
| Legendary | 1 in 2,000 | basic × 2 | +40 to one stat |
| Mythic | 1 in 20,000 | basic × 3 | +60 to one stat |

- Stats then vary ±10% per animal, so two Sun Lions are never quite identical.
- Titans have no variants (yet).

## Art rules for every animal

- Same chunky, cute, rounded style as the concept video: big head, big eyes, short legs, soft colours.
- One silhouette per species. A variant keeps the silhouette and changes colour, material,
  accessories and effects, so players recognise the species at a glance.
- Effects grow with the tier: **epic** = new palette and one accessory; **legendary** = special
  material (gold, pearl, crystal) plus a sparkle or glow; **mythic** = a fully transformed body
  (fire, sand, stars, light) plus a constant particle trail and a rarity aura.
- Titans are about three times the size of a rare animal, with a slow, heavy walk.
- Rarity colours for nameplates and auras: common grey, uncommon green, rare blue, epic purple,
  legendary gold, mythic rainbow shimmer.

## Attack animals

| Version | Rarity | Stats (spd/str/sta/mana) | Look |
|---|---|---|---|
| Hyena | common | 30 / 40 / 20 / 12 | Sandy spotted hyena with a scruffy mane and a cheeky grin. |
| Ember Hyena | epic | twist strength | Dark coat with glowing orange spots; little sparks when it laughs. |
| Bonechief Hyena | legendary | twist stamina | Wears a bone necklace and a horned skull helmet, green spirit glow in the eyes. |
| Eclipse Hyena | mythic | twist mana | Pitch-black body ringed with a burning corona, spots like tiny eclipses. |
| Jackal | common | 42 / 22 / 15 / 18 | Slim tan jackal with a dark back and big pointed ears. |
| Dune Jackal | epic | twist stamina | Pale gold coat, a desert scarf, kicks up small sand swirls. |
| Golden Jackal | legendary | twist strength | Polished gold fur with a glint sweep and amber eyes. |
| Pharaoh Jackal | mythic | twist mana | Black and gold, a striped headdress, glowing blue glyphs floating around it. |
| Cheetah | uncommon | 70 / 35 / 20 / 20 | Golden-tan cheetah with black spots and tear marks. |
| Shadow Cheetah | epic | twist mana | Black coat with faint violet spots and glowing violet eyes. |
| Golden Cheetah | legendary | twist strength | Metallic gold coat with darker gold spots. |
| Lightning Cheetah | mythic | twist speed | Electric-blue spots, crackling arcs along the body, fading afterimages. |
| Lion | rare | 55 / 90 / 40 / 25 | Tawny lion with a big fluffy mane and a proud chest. |
| White Lion | epic | twist stamina | Snow-white coat and mane, pale blue eyes. |
| Sun Lion | legendary | twist mana | The mane is a ring of golden sun rays that slowly turns; warm glow. |
| Constellation Lion | mythic | twist strength | Night-sky body with star lines tracing its shape, a mane of drifting stardust. |

## Defense animals

| Version | Rarity | Stats (spd/str/sta/mana) | Look |
|---|---|---|---|
| Warthog | common | 22 / 35 / 40 / 8 | Grey-brown warthog with curved tusks and a wiry mohawk. |
| Mudslinger Warthog | epic | twist strength | Caked in thick mud armour, drips and splats as it trots. |
| Ironhide Warthog | legendary | twist stamina | Riveted iron plates and steel tusks, sparks when it stamps. |
| Magma Warthog | mythic | twist strength | Cracked black rock skin with lava glowing in the cracks, smoking tusks. |
| Tortoise | common | 5 / 25 / 48 / 20 | Olive tortoise with a domed patterned shell and a kind face. |
| Mossback Tortoise | epic | twist mana | Shell covered in moss, tiny flowers and a mushroom or two. |
| Gemshell Tortoise | legendary | twist stamina | Shell plates are cut gems in different colours that catch the light. |
| Island Tortoise | mythic | twist mana | Carries a tiny island on its back: a palm tree, a waterfall, a little cloud. |
| Rhino | uncommon | 25 / 60 / 65 / 10 | Grey rhino with a big front horn and armour-like skin folds. |
| Stone Rhino | epic | twist stamina | Carved from sandstone with painted tribal-style patterns. |
| Crystal Rhino | legendary | twist mana | Clear crystal horn and crystal plates along the back. |
| Thunder Rhino | mythic | twist speed | Storm-cloud hide, a lightning-bolt horn, rumbles when it charges. |
| Gorilla | rare | 25 / 80 / 90 / 40 | Dark grey gorilla with a lighter face and big arms. |
| Silverback | epic | twist mana | Silver stripe down the back and calm, wise eyes. |
| Lava Gorilla | legendary | twist strength | Obsidian body with molten orange veins and drifting embers. |
| Galaxy Gorilla | mythic | twist mana | Fur is a starfield with nebula colours; two tiny moons orbit its head. |

## Utility animals

| Version | Rarity | Stats (spd/str/sta/mana) | Look |
|---|---|---|---|
| Meerkat | common | 30 / 8 / 15 / 42 | Small sandy meerkat standing upright, dark eye patches, always alert. |
| Scout Meerkat | epic | twist speed | Tiny binoculars and a scout neckerchief. |
| Sandmage Meerkat | legendary | twist mana | Little robe and staff, a ribbon of sand spiralling around it. |
| Mirage Meerkat | mythic | twist speed | Shimmering heat-haze body with two flickering mirror copies beside it. |
| Flamingo | common | 20 / 8 / 22 / 45 | Bright pink flamingo standing on one leg. |
| Sunset Flamingo | epic | twist stamina | Feathers fade from orange to purple like a sunset. |
| Pearl Flamingo | legendary | twist mana | Pearly white sheen with a pearl-drop crest. |
| Phoenix Flamingo | mythic | twist strength | Feathers of fire, an ember trail, a flare when it spreads its wings. |
| Giraffe | uncommon | 30 / 25 / 35 / 65 | Yellow giraffe with brown patches and little horn nubs. |
| Painted Giraffe | epic | twist speed | Patches in bright paint colours, as if a child coloured them in. |
| Cloudtop Giraffe | legendary | twist stamina | Its head is up in a small private cloud; patches are sky blue. |
| Stargazer Giraffe | mythic | twist mana | Midnight coat whose patches are windows of stars; a telescope monocle. |
| Mandrill | rare | 35 / 30 / 40 / 90 | Olive mandrill with the red and blue face and a golden beard. |
| Masked Mandrill | epic | twist strength | Wears a carved wooden mask with bright painted stripes. |
| Stormcaller Mandrill | legendary | twist speed | Carries a staff topped with a small thundercloud, fur lifted by static. |
| Spirit Mandrill | mythic | twist mana | Half see-through, glowing teal, with spirit wisps circling it. |

## Titans (fourth slot)

| Titan | Rarity | Stats (spd/str/sta/mana) | Look |
|---|---|---|---|
| Elephant | legendary | 30 / 160 / 180 / 60 | Huge grey elephant with gold-capped tusks and painted ear patterns; the ground shakes. |
| Hippo | legendary | 35 / 180 / 150 / 40 | Massive purple-grey hippo with a giant jaw; water sprays when it stomps. |
| Crocodile | legendary | 50 / 170 / 130 / 50 | Long armoured green crocodile with jagged back plates and glowing yellow eyes. |

## Eggs

| Egg | Price | Hatches (basic odds) |
|---|---|---|
| Meadow Egg | 100 | the 6 commons |
| Wild Egg | 1,500 | commons 54%, uncommons 46% |
| Safari Egg | 15,000 | uncommons 57%, rares 39%, a Titan 4% |

Variant chances are the same in every egg. How Titans are earned is a draft: the 4% Safari
chance is a placeholder until the ranch upgrades and samples exist (0025).
