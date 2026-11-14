# Animal Stations: the Hexbound (enemy bestiary and art brief)

Status: draft (decision 0040). Names, roles and numbers are in `src/shared/StationConfig.luau`
(`FOES`, the source of truth). This page adds the look.

The Hexbound are the enemies of the endless waves: **evil magic knights, ogres and dragons**.
Everything about them glows **hexfire**, a toxic green (150, 255, 70), so an enemy is always the
one that glows green. They are not animals: they are never hatched, owned, saved or in an egg.

## The line

| Foe | Kind | Role | Group | Stats (spd/str/sta/mana/hp/def) | First wave |
|---|---|---|---|---|---|
| Gloom Squire | knight | Attack | pack | 38 / 24 / 16 / 14 / 32 / 14 | 1 |
| Gloom Bulwark | knight | Defence | solitary | 8 / 26 / 48 / 12 / 58 / 58 | 1 |
| Gloom Banner | knight | Utility | pack | 28 / 8 / 16 / 44 / 28 / 10 | 1 |
| Ogre Brute | ogre | Attack | solitary | 24 / 80 / 28 / 8 / 76 / 22 | 5 |
| Ogre Hexcaller | ogre | Utility | pack | 28 / 12 / 28 / 60 / 50 / 12 | 5 |
| Ogre Warlord | ogre | Attack | pack | 46 / 92 / 40 / 20 / 84 / 28 | 15 |
| Hexfire Whelp | dragon | Attack | solitary | 46 / 70 / 36 / 46 / 108 / 38 | boss, 10 |
| Hexfire Drake | dragon | Attack | solitary | 70 / 130 / 70 / 80 / 200 / 90 | boss, 30 |
| Hexfire Dragon | dragon | Attack | solitary | 100 / 200 / 100 / 120 / 320 / 160 | boss, 60 |

Stats are before the wave's scaling (60% at wave 1, then +3% a wave).

## The look (three models, tiers by tint and size)

- **Knight** (`foe_knight`, about 7.5 studs tall): haunted black-violet plate with floating pieces.
  A great helm with swept bone horns and angry hexfire eye slits floats over a glowing neck; spiked
  pauldrons, a barrel chest with a hexfire rune, a ragged violet cape and tabard; a sword with
  hexfire runes in the right hand and a kite shield with a hexfire sigil on the left arm. The three
  knight foes share the model; the squire, the bulwark and the banner differ by tint, and later by a
  prop (a banner on the Banner).
- **Ogre** (`foe_ogre`, about 14 studs tall): a hunched green brute, a big belly, long arms and
  short legs, tusks and brow horns, an iron collar with hexfire runes, a belt, a loincloth, a spiked
  club with hexfire nails, cracks of hexfire across the hide. The Warlord is a larger, darker one.
- **Dragon** (`foe_dragon`, about 10 studs tall, 24 long, a wingspan of about 24): the animals'
  predator body made heavy, a horned head with glowing eyes, a spine of spikes (every other one
  hexfire), a long tail with a bone spade, two scalloped bat wings veined with hexfire. The Whelp is
  small and pale, the Drake larger, the Dragon the largest and darkest.

## Animation plan (not built)

The animals' rig names are reused. Knight and ogre are bipeds: `leg_fl`/`leg_fr` are the arms,
`leg_bl`/`leg_br` the legs, `tail` the cape or loincloth. They need a biped pose set: a heavy
stomping walk with the arms swinging against the legs, a sword chop and a club smash, and a magic
attack (the hexfire runes flare). The dragon uses the four-legged poses and adds `wing_l` and
`wing_r`: a slow flap, a rear-up for the breath, hexfire breath as the magic attack.
