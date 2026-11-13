# 0029: Animal Stations framework: small roster with groups, six levelled stats, ranch base and vendor hub

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Replaces the roster and Titan egg of 0027, the training numbers of 0023 and
0028, and the hub stations and hilltop ranches of 0028. This is framework: simple placeholders,
draft numbers.

## Decision

**Animals**

- The beta pool is 8 species. Pack: Lion (cat), Jackal (dog), Meerkat, Flamingo (bird) and the
  Titan Elephant. Solitary: Cheetah, Rhino, Tortoise. One common and one uncommon per role, plus
  the rare Lion.
- **Groups give battle bonuses.** A pack animal gains 10% attack and HP for each other pack
  animal on its team. A solitary animal gains 25% when no teammate shares its role.
- Teams have no restrictions on roles; only one Titan (its own fourth slot, 0027).
- **The Titan exists only as legendary** and hatches only from the **Legendary Egg** (50,000
  coins), which unlocks at **player level 15**.

**Player level**

- Players have XP and a level: level n needs 25 × (n − 1)² XP (level 15 = 4,900). Eggs give XP
  when hatched (10, 40, 150, 500). Clearing waves will give XP once battles are playable.
- Three different things are called a level, so the words are: **wave** (the endless levels),
  **stat level** (0 to 70) and **player level**.

**Stats**

- Six stats: Speed, Strength, Stamina, Mana, Health and **Defence**. Defence cuts incoming
  damage: damage × 100 ÷ (100 + Defence), so 100 Defence halves it.
- **Every stat has a level from 0 to 70.** A stat's value is its hatched value × (1 + level ÷ 70),
  so a maxed stat is doubled. Level n takes 30 × n seconds of training (about 21 hours for one
  stat to 70). An animal that reaches 70 stops training by itself.
- Attack comes from the best of Speed, Strength, Stamina and Mana; Health is only HP, Defence
  only cuts damage, Mana also sets how often power attacks happen (0028).

**World**

- **The hub is where players meet vendors.** For now that is the plaza with the fountain and one
  egg stall per egg. The five training stations are removed from the hub.
- **A ranch is the player's base and where animals train.** Each ranch is a large separate
  island, completely detached from the hub. Players spawn at their ranch and travel with
  teleport pads: one at the ranch gate to the hub, one in the hub back to their own ranch.
- A ranch has one training pad per stat (plain coloured placeholders, tagged `TrainPad`) next
  to the barn, paddock and egg nest, with empty room to grow.

**Saves**

- A saved animal with a missing stat is repaired from its species' stats instead of being
  dropped, so adding a stat later cannot delete players' animals.

## Direction from SHANNON, recorded here, not built yet

- The ranch is a **tycoon**: train there, buy **universal upgrades**, and **expand the ranch**,
  paid for with gold and samples from harder and harder enemies (0025). Long means hard to
  afford, not physically huge.
- The hub will gain more vendors.

## Checks

641 headless tests. Studio play on 2026-11-13: world builds with no script errors; a player
spawns on their ranch island, the pads teleport both ways, eggs hatch the new animals, the
Legendary Egg is refused below level 15, and training a stat ticks up live in the Animals panel.
Wave reach (draft): starters 9, maxed starters 26, uncommons 17, with the Titan 26, maxed 39,
legendary team 39, maxed mythic team with the Titan 69.

## Not decided yet

What Speed, Strength and Stamina each do on their own; the battle screen; how waves give XP,
gold and samples; the tycoon's upgrades; the magical attacks.
