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
  Golden Egg, which unlocks when wave 20 is cleared.

## How versions work

- Every animal has a **basic** version. A normal animal is never above epic (today: common,
  uncommon or rare); the Titan is legendary.
- Every animal has **variants**, always legendary or mythic (the Lion, the Elephant, the Jackal and the Cheetah
  have one of each, decisions 0050 to 0053). A variant is a drop of its own (decision 0056): it
  hatches only from the eggs that list it, at the chance that egg gives it (the table under Eggs):

| Variant rarity | Chance per hatch | Stats | Twist |
|---|---|---|---|
| Legendary | 1 in 5,000 to 1 in 400, by egg | basic × 2 | +40 to one stat |
| Mythic | 1 in 20,000 to 1 in 2,000, by egg | basic × 3 | +60 to one stat |

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
| Jackal | Attack | common | 42 / 22 / 15 / 18 / 30 / 10 | Faceted low-poly (decision 0052): a lean sandy hunter, big pointed ears, a long muzzle, a dark saddle, dark paws, a bushy tail. Card: `docs/concepts/jackal-card.png`. | 4 x 7 |
| Pharaoh Jackal | | legendary | twist mana | Black coat, gold collars, anklets, ear tips and tail tip, turquoise glowing eyes and brow gem. Card: `docs/concepts/pharaoh-jackal-card.png`. | 5 x 9 |
| Sphinx Jackal | | mythic | twist speed | Sandstone, a pharaoh's blue and gold striped headdress, a glowing sun disc between the ears, a striped beard, a gold collar, folded wings of gold and blue feathers, glowing gold eyes. Card: `docs/concepts/sphinx-jackal-card.png`. | about 5 x 10 |
| Meerkat | Utility | common | 30 / 8 / 15 / 42 / 25 / 8 | Textured faceted model (decision 0055): it stands upright, a sentinel: sandy with a cream belly, dark bands across the back, dark eye patches, thin arms at the chest, a long tail propped behind. Card: `docs/concepts/meerkat-card.png`. | 5 x 5 |
| Storm Meerkat | | legendary | twist mana | Thundercloud coat, glowing forked lightning down the back, a ruff of cloud, a crest of sparks, a ball of lightning between the paws, a charged tail. Card: `docs/concepts/storm-meerkat-card.png`. | 7 x 6 |
| Star Meerkat | | mythic | twist speed | A coat of night sky, glowing gold stars joined into constellations, a great star on the chest, a ring of stars round the head, a comet for a tail tip. Card: `docs/concepts/star-meerkat-card.png`. | 7 x 7 |
| Flamingo | Utility | uncommon | 30 / 10 / 30 / 65 / 50 / 15 | Textured faceted model (decision 0055): tall and pink on two stilts, coral wings with black flight feathers, a pale beak with a black hook, a hard stare. Two legs: its wings are built as the back legs. Card: `docs/concepts/flamingo-card.png`. | 8 x 6 |
| Phoenix Flamingo | | mythic | twist mana | Fire-red with a gold neck, a glowing crest, flight feathers and long tail streamers of flame, gold flames up the breast. Card: `docs/concepts/phoenix-flamingo-card.png`. | 11 x 10 |
| Peacock Flamingo | | legendary | twist stamina | Teal with a royal blue neck, emerald wings, a great fan of tail feathers with glowing eyes, a beaded crest. Card: `docs/concepts/peacock-flamingo-card.png`. | 10 x 7 |
| Lion | Attack | rare | 55 / 90 / 40 / 25 / 70 / 30 | Faceted low-poly (decision 0050): a chunky tawny cat, a mane of big brown crystal shards, pale paws and muzzle, amber slit eyes, a tufted tail. Card: `docs/concepts/lion-card.png`. | 7 x 13 |
| Sun Lion | | mythic | twist strength | Golden, a mane of big yellow crystal shards, a sun with twelve rays on each haunch, glowing eyes, a flame of a tail. Card: `docs/concepts/sun-lion-card.png`. | 9 x 16 |
| Shadow Lion | | legendary | twist speed | Ink black, a bone mask, spine and fangs, a mane of big black crystal shards with a few glowing green ones, green ribs and eyes. Card: `docs/concepts/shadow-lion-concept.png`; the model is `creature_lion_shadow` in `tools/blender/stations/assets/lions.py`. | about 8 x 15 |
| Giraffe | Utility | rare | 50 / 60 / 45 / 55 / 80 / 25 | Faceted low-poly (decision 0076): cream under chestnut patches, a short dark mane, a heavy brow, sharp dark-tipped horns, long legs with dark hooves. Card: `docs/concepts/giraffe-card.png`. | 23 x 15 |
| Diamond Giraffe | | mythic | twist defence | Silver-blue under diamond plates, glowing diamond horns, a crest of glowing crystal down the neck, diamonds out of its shoulders, glowing eyes. Card: `docs/concepts/diamond-giraffe-card.png`. | about 23 x 15 |
| Elephant (Titan) | Titan | legendary | 30 / 160 / 180 / 60 / 200 / 120 | Faceted low-poly (decision 0051): blue-grey, flared ears, a heavy brow, a ringed trunk, curved pale tusks, amber slit eyes. Card: `docs/concepts/elephant-card.png`. | 14 x 25 |
| Frost Mammoth | | mythic | twist health | Icy blue and shaggy with a hump, small ears, huge curved tusks of glowing ice, ice spikes down its back, glowing eyes. Card: `docs/concepts/frost-mammoth-card.png`. | 19 x 30 |
| War Elephant | | legendary | twist strength | Dark elephant in war gear with a cannon on its back, ember eyes, a glowing muzzle. Card: `docs/concepts/war-elephant-card.png`. | about 19 x 27 |


## Solitary animals

| Version | Role | Rarity | Stats (spd/str/sta/mana/hp/def) | Look | Size (tall x long) |
|---|---|---|---|---|---|
| Tortoise | Defence | common | 5 / 25 / 48 / 20 / 55 / 50 | Textured faceted model (decision 0055): a war tortoise, olive and scaly, a high dome of six-sided horn plates in tiers, bone spikes round the rim, a hooked beak. Card: `docs/concepts/tortoise-card.png`. | 4 x 9 |
| Gemshell Tortoise | | legendary | twist defence | A midnight shell set with cut rose gems in gold settings, the four down the spine glowing, gold beads round the rim, teal skin, gold claws and beak. Card: `docs/concepts/gemshell-tortoise-card.png`. | 5 x 12 |
| Island Tortoise | | mythic | twist health | Mossy stone carrying an island: an acacia with glowing fruit, rocks, grass and glowing flowers, vines from the rim, a sprout on its head. Card: `docs/concepts/island-tortoise-card.png`. | 10 x 14 |
| Cheetah | Attack | uncommon | 70 / 35 / 20 / 20 / 45 / 15 | Faceted (decision 0053): a slender golden sprinter on very long legs, black diamond spots and tear marks, a very long ringed tail. Card: `docs/concepts/cheetah-card.png`. | 5 x 11 |
| Lightning Cheetah | | mythic | twist speed | Storm-dark coat, electric blue spots, glowing bolts down both flanks and a crest of them on the neck, a zigzag tail with a glowing tip. Card: `docs/concepts/lightning-cheetah-card.png`. | 6 x 14 |
| Thunder Cheetah (id `fire_cheetah`; it was the Fire Cheetah until decision 0102) | | legendary | twist strength | Built of blue storm clouds: a spiky cloud mane, lightning down its legs, a bolt on its chest and a storm cloud for a tail tip. SHANNON's ForgeGUI model. | about 9 x 13.5 |

| Rhino | Defence | uncommon | 25 / 50 / 60 / 10 / 70 / 55 | Textured faceted model (decision 0054): a massive slate war rhino slung low on pillar legs under sleeves of armour, a short deep head, a scimitar of a bone horn, bone studs on the shoulder plate, claw scars. Card: `docs/concepts/rhino-card.png`. | 8 x 14 |
| Lava Rhino | | mythic | twist strength | Obsidian plates with lava in their cracks, glowing lava in the folds between them and round the knees, molten horns, rock spikes with hot tips, a burning tail. Card: `docs/concepts/lava-rhino-card.png`. | 11 x 19 |
| Crystal Rhino | | legendary | twist defence | Living grey rock grown through with gemstones of nine colours: great clusters of crystals on the hump and rump, a ridge down the spine, veins of gem, a great glowing crystal horn, a mace of crystals for a tail; seven crystals glow, each in its own colour. Card: `docs/concepts/crystal-rhino-card.png`. | 12 x 16 |



## Eggs

The egg overhaul (decision 0056, draft numbers). The Meadow and Wild Eggs are open from the start; the Safari and Golden Eggs unlock with the waves. A hatch rolls the egg's
rare drops first, then a basic animal.

| Egg | Price | Unlocks | Basic animals | Legendary drops | Mythic drops |
|---|---|---|---|---|---|
| Meadow Egg | 100 | from the start | Jackal, Tortoise or Meerkat | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 5,000 each | none |
| Wild Egg | 1,500 | from the start | commons 54%, uncommons 46% | Pharaoh Jackal, Gemshell Tortoise, Storm Meerkat: 1 in 2,000 each; Thunder Cheetah, Crystal Rhino, Peacock Flamingo: 1 in 4,000 each | Sphinx Jackal, Island Tortoise, Star Meerkat: 1 in 20,000 each |
| Safari Egg | 15,000 | wave 10 cleared | uncommons 80%, the Lion 20% | Thunder Cheetah, Crystal Rhino, Peacock Flamingo: 1 in 500 each; Shadow Lion 1 in 2,000 | Sphinx Jackal, Island Tortoise, Star Meerkat: 1 in 5,000 each; Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 10,000 each |
| Golden Egg | 50,000 | wave 20 cleared | the Lion 50%, uncommons 45%, the Titan Elephant 5% | Shadow Lion 1 in 400; War Elephant 1 in 2,000 | Lightning Cheetah, Lava Rhino, Phoenix Flamingo: 1 in 2,000 each; Sun Lion 1 in 4,000; Frost Mammoth 1 in 20,000 |

There is no legendary-only egg (decision 0031). The four eggs are detailed models (decision 0057,
`docs/concepts/egg-family.png`): in the hatchery, on the storage rack and the vendor's counter, on the
hub's fountain, in the menus and in the hatching animation.

### The rainbow coat

Any hatch, from any egg, of any animal or variant, comes out in a rainbow coat 1 time in 200
(decision 0058; `docs/concepts/rainbow-family.png`). The coat adds 5% to every stat, rounded up;
rarity and role stay the same. It runs through the rainbow from nose to tail and keeps the animal's
spots, stripes and plates; its glowing pieces turn through the colours.

## Parked for later

Removed from the pool for now to keep it small (their stats and variants are in decision 0027
and git history): Hyena, Warthog, Gorilla, Giraffe, Mandrill, and the Hippo and Crocodile Titans.
