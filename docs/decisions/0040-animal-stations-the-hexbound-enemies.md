# 0040: Animal Stations: the Hexbound, evil magic knights, ogres and dragons, are the enemies

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Replaces the animal enemies of 0023 and 0032 and the animal bosses of 0037.

## Decision

From SHANNON: "i kind of want to go with an enemy instead of other animals. im thinking evil
magic medival knights and orgres and dragons", then "would that be easier or harder than animals?
you could cut corners with the enemies".

- The enemies of the endless waves are a faction, **the Hexbound**: evil magic knights, ogres and
  dragons. They glow hexfire green, which no animal does, so friend and foe read at a glance.
- They are a separate roster (`StationConfig.FOES`). A foe has the same six stats, role and group
  as an animal, so `BattleRules` fights it exactly the same way, but it is never hatched, owned,
  saved or found in an egg. The animals are only ever the player's team.
- **The line:** knights from wave 1, ogres from wave 5, the Ogre Warlord from wave 15. Three foes
  per wave, drawn the same way as before, growing 3% a wave as before.
- **The boss:** every 10th wave ends with a **dragon**, the strongest the wave allows: a Hexfire
  Whelp from wave 10, a Drake from 30, a Dragon from 60.

| Foe | Kind | Role | Group | First wave |
|---|---|---|---|---|
| Gloom Squire | knight | Attack | pack | 1 |
| Gloom Bulwark | knight | Defence | solitary | 1 |
| Gloom Banner | knight | Utility | pack | 1 |
| Ogre Brute | ogre | Attack | solitary | 5 |
| Ogre Hexcaller | ogre | Utility | pack | 5 |
| Ogre Warlord | ogre | Attack | pack | 15 |
| Hexfire Whelp | dragon | Attack | solitary | boss, 10 |
| Hexfire Drake | dragon | Attack | solitary | boss, 30 |
| Hexfire Dragon | dragon | Attack | solitary | boss, 60 |

- **Balance:** the foes' numbers were set so the waves are about as hard as they were with animal
  enemies (measured: a fresh trio of starters now clears waves 1 to 9 and meets the first dragon
  at 10, trained starters reach wave 28, a team of maxed mythics with a Titan reaches 79). The
  first dragon is a deliberate wall for an untrained team.
- **Samples:** the Hexbound would drop them (hex shards), bosses the most. Not built: the wave
  fight that pays them is not wired yet.

## Why it is easier than animals (and where the corners are cut)

- **Three models, not sixteen:** one per kind. A tier within a kind (a Drake, a Warlord) is a tint
  and a size in game, not a new model. No variants, rarity, eggs, hatching, saves or collection UI.
- **Knights are haunted armour:** the pieces float apart (the helm, the gauntlets) with hexfire
  in the gaps, so there is no skin to join and no joint to hide.
- **The dragon is the animals' predator body** with wings and horns.
- **Harder part:** knights and ogres walk on two legs, and every animation so far is four-legged.
  They need their own walk and attack poses (a biped set; the dragon adds a wing flap). The pieces
  reuse the animals' rig names: arms are the "front legs", legs the "back legs", the cape the "tail".

## Status

- Done: the roster, the rules, the tests, and a look-test of the three models as Blender previews
  (`tools/blender/stations/assets/foes.py`). The models are NOT in the game yet: not baked, not
  uploaded, not rigged, no biped animations.
- Not done: hit and death reactions, the enemy hover card (it shows animals only), the wave fight.

## Costs and limits

- The old animal enemies and their boss variants are gone from the waves.
- A faction name and the foe names are drafts and are cheap to change.
