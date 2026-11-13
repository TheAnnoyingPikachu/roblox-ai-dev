# Animal Stations: the first 16 animals (bestiary and art brief)

Status: first lot, draft. Names, stats and odds are in `src/shared/StationConfig.luau` (the
source of truth). This page adds the **look** of every version for the art pipeline.

## How versions work

- Every species has a **basic** version: common, uncommon or rare. That's what you hatch nearly every time.
- On top of that, every hatch from any egg rolls for a **variant** of that species:

| Tier | Chance per hatch | Stats | Twist |
|---|---|---|---|
| Epic | 1 in 200 | basic × 1.5 | +25 to one stat |
| Legendary | 1 in 2,000 | basic × 2 | +40 to one stat |
| Mythic | 1 in 20,000 | basic × 3 | +60 to one stat |

- The **twist** gives a variant a second job: the Ember Fox is still a runner, but its extra
  strength makes it a decent gym animal too.
- Stats then vary ±10% per animal, so two Golden Cheetahs are never quite identical.

## Art rules for every animal

- Same chunky, cute, rounded style as the concept video: big head, big eyes, short legs, soft colours.
- One silhouette per species. A variant keeps the silhouette and changes colour, material,
  accessories and effects, so players recognise the species at a glance.
- Effects grow with the tier: **epic** = new palette and one accessory; **legendary** = special
  material (gold, pearl, crystal) plus a sparkle or glow; **mythic** = a fully transformed body
  (fire, water, stars, light) plus a constant particle trail and a rarity aura.
- Rarity colours for nameplates and auras: common grey, uncommon green, rare blue, epic purple,
  legendary gold, mythic rainbow shimmer.

## Speed animals (Speed Track)

| Version | Rarity | Stats (spd/str/swm/smt) | Look |
|---|---|---|---|
| Bunny | common | 40 / 10 / 8 / 18 | Cream-white bunny with tall pink-lined ears and a cotton tail. |
| Clover Bunny | epic | twist smarts | Mint-green fur, ears shaped like four-leaf clover leaves, little green sparkles. |
| Moon Bunny | legendary | twist swim | Silver-lavender fur, a glowing crescent on the forehead, floats slightly with a stardust trail. |
| Comet Bunny | mythic | twist speed | White-hot glowing body with a blue flame tail that streams behind it like a comet. |
| Fox | common | 45 / 15 / 12 / 30 | Orange fox with a white-tipped bushy tail and black socks. |
| Arctic Fox | epic | twist swim | Snow-white fluffy coat, icy blue eyes, frosty breath puffs. |
| Ember Fox | legendary | twist strength | Charcoal fur with glowing orange cracks, the tail tip is a living flame. |
| Kitsune | mythic | twist smarts | Pink-gold fox with nine floating spirit tails and blue spirit flames orbiting it. |
| Horse | uncommon | 65 / 40 / 20 / 20 | Chestnut horse with a dark mane and white blaze. |
| Painted Pony | epic | twist smarts | Pastel patchwork coat, braided mane with ribbons. |
| Pegasus | legendary | twist strength | Pure white with feathered wings and golden hooves; wings flap as it runs. |
| Starlight Unicorn | mythic | twist smarts | Iridescent pearl coat, crystal horn, a rainbow mane that slowly shifts colour, star sparkles. |
| Cheetah | rare | 90 / 30 / 10 / 25 | Golden-tan cheetah with black spots and tear marks. |
| Shadow Cheetah | epic | twist smarts | Black coat with faint violet spots and glowing violet eyes. |
| Golden Cheetah | legendary | twist strength | Polished metallic gold coat with darker gold spots and a glint sweep. |
| Lightning Cheetah | mythic | twist speed | Electric-blue spots, crackling arcs along the body, leaves fading afterimages. |

## Strength animals (Strength Gym)

| Version | Rarity | Stats (spd/str/swm/smt) | Look |
|---|---|---|---|
| Pig | common | 10 / 40 / 12 / 20 | Round pink pig with a curly tail. |
| Truffle Pig | epic | twist smarts | Chocolate-brown pig wearing a little mushroom-cap hat. |
| Royal Pig | legendary | twist smarts | Pink pig with a golden crown and a red velvet cape. |
| Flying Pig | mythic | twist speed | Sky-blue pig with feathery wings, aviator goggles and cloud puffs under its hooves. |
| Goat | common | 25 / 45 / 5 / 15 | White goat with short horns and a little beard. |
| Mountain Goat | epic | twist speed | Slate-grey coat, big curled horns, kicks up pebble dust. |
| Crystal Goat | legendary | twist smarts | Amethyst crystal horns and gem flecks across the coat that catch the light. |
| Thunder Ram | mythic | twist strength | Storm-cloud wool with lightning-bolt horns; small rumbles of sparks when it stomps. |
| Bear | uncommon | 25 / 65 / 35 / 20 | Brown bear with a honey-coloured muzzle. |
| Panda Bear | epic | twist smarts | Classic black and white, chewing a bamboo stalk. |
| Polar Bear | legendary | twist swim | White fur with frost crystals and icy breath. |
| Aurora Bear | mythic | twist smarts | Translucent body glowing aurora green and pink, with glowing runes on its paws. |
| Gorilla | rare | 25 / 90 / 10 / 45 | Dark grey gorilla with a lighter face and big arms. |
| Silverback | epic | twist smarts | Silver stripe down the back and calm, wise eyes. |
| Lava Gorilla | legendary | twist strength | Obsidian body with molten orange veins and drifting embers. |
| Galaxy Gorilla | mythic | twist smarts | Fur is a starfield with nebula colours; two tiny moons orbit its head. |

## Swim animals (Swim Pool)

| Version | Rarity | Stats (spd/str/swm/smt) | Look |
|---|---|---|---|
| Duck | common | 12 / 8 / 42 / 15 | Yellow duckling with an orange bill. |
| Rubber Duck | epic | twist swim | Glossy yellow toy duck, bobs and squeaks. |
| Golden Duck | legendary | twist smarts | Shiny gold duck that leaves coin sparkles in the water. |
| Storm Duck | mythic | twist speed | Blue-grey duck under its own tiny raincloud with little lightning flashes. |
| Frog | common | 30 / 8 / 45 / 12 | Bright green frog with big round eyes. |
| Dart Frog | epic | twist speed | Neon blue body with black patterns. |
| Frog Prince | legendary | twist smarts | Green frog with a tiny golden crown and a short cape. |
| Jade Frog | mythic | twist strength | Carved jade body with gold trim, holding a glowing gold coin in its mouth. |
| Otter | uncommon | 25 / 20 / 65 / 35 | Brown otter with a cream face and whiskers. |
| Sea Otter | epic | twist smarts | Floats on its back holding a shell, wrapped in kelp. |
| Pearl Otter | legendary | twist smarts | Pearly white sheen and a pearl necklace. |
| Tidal Otter | mythic | twist strength | Made of swirling water with a white foam crest and bubbles. |
| Dolphin | rare | 35 / 30 / 90 / 60 | Smooth blue-grey dolphin with a happy face. |
| Pink River Dolphin | epic | twist smarts | Bubblegum-pink dolphin with a longer snout. |
| Midnight Dolphin | legendary | twist strength | Deep navy body covered in glowing bioluminescent dots. |
| Crystal Dolphin | mythic | twist speed | See-through crystal body that splits light into rainbows. |

## Smarts animals (Puzzle Library)

| Version | Rarity | Stats (spd/str/swm/smt) | Look |
|---|---|---|---|
| Mouse | common | 22 / 5 / 8 / 42 | Grey mouse with big round pink ears. |
| Clockwork Mouse | epic | twist speed | Brass wind-up mouse with a turning key on its back. |
| Wizard Mouse | legendary | twist smarts | Starry blue hat and robe, waving a glowing wand. |
| Astro Mouse | mythic | twist speed | Astronaut helmet, a jetpack with flame puffs, floating in low gravity. |
| Raccoon | common | 20 / 20 / 15 / 45 | Grey raccoon with a black eye mask and a striped tail. |
| Treasure Raccoon | epic | twist strength | Carries a backpack overflowing with shiny trinkets. |
| Ninja Raccoon | legendary | twist speed | Dark wrap and headband, leaves a puff of smoke when it dashes. |
| Moonleaf Tanuki | mythic | twist strength | Round tanuki with a glowing leaf on its head and a shimmering illusion outline. |
| Parrot | uncommon | 30 / 10 / 10 / 65 | Bright green parrot with a red head. |
| Pirate Parrot | epic | twist swim | Tiny tricorn hat and an eye patch. |
| Rainbow Macaw | legendary | twist speed | Extra-vivid rainbow gradient feathers with a shine. |
| Phoenix Parrot | mythic | twist strength | Feathers made of fire, leaves an ember trail as it flies. |
| Owl | rare | 35 / 15 / 5 / 90 | Brown owl with big round eyes and ear tufts. |
| Snowy Owl | epic | twist swim | White owl with grey speckles and gold eyes. |
| Arcane Owl | legendary | twist speed | Feathers with glowing runes and a small spellbook floating beside it. |
| Celestial Owl | mythic | twist strength | Night-sky plumage with constellation lines and a moon halo. |

## Eggs

| Egg | Price | Hatches (basic odds) |
|---|---|---|
| Meadow Egg | 100 | the 8 commons |
| Wild Egg | 1,500 | commons 52%, uncommons 48% |
| Safari Egg | 15,000 | uncommons 60%, rares 40% |

Variant chances are the same in every egg. Later ideas, not built yet: a luckier variant egg, a
pity counter for variants, and a variant album with rewards.
