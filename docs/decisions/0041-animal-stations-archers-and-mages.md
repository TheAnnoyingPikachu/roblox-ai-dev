# 0041: Animal Stations: archers and mages join the Hexbound

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Adds to 0040.

## Decision

From SHANNON: "can you add a few more enemies like archers and mages?"

Five new foes, so waves have more than melee brutes. Archers are fast and fragile (high Speed, low
Health and Defence). Mages hit hard through their Mana, and the healer and the warden fill the
Utility and Defence roles. Everything else is the fight rules as they were: the roles and group
bonuses already make an archer a glass cannon and a warden a wall.

| Foe | Kind | Role | Group | Stats (spd/str/sta/mana/hp/def) | First wave |
|---|---|---|---|---|---|
| Shade Archer | archer | Attack | pack | 46 / 24 / 14 / 14 / 26 / 8 | 3 |
| Shade Crossbowman | archer | Attack | solitary | 16 / 70 / 26 / 14 / 50 / 16 | 9 |
| Hexcaster | mage | Attack | solitary | 26 / 56 / 14 / 72 / 38 / 8 | 6 |
| Hexweaver | mage | Utility | pack | 28 / 10 / 20 / 58 / 36 / 10 | 8 |
| Hexwarden | mage | Defence | solitary | 10 / 24 / 46 / 42 / 62 / 56 | 12 |

- The ogre healer is now the **Ogre Shaman** (it was the Ogre Hexcaller), so no two foes share a name.
- A new foe turns up every few waves: archers at 3, ogres at 5, mages at 6, a healing mage at 8, a
  crossbowman at 9, the Hexwarden at 12, the Ogre Warlord at 15, and a dragon boss every 10th wave.
- **Models:** two new ones, `foe_archer` (a hooded bowman with a hexfire bowstring, a glowing arrow
  and a quiver of glowing arrows) and `foe_mage` (a hooded, horned caster with a crystal staff, a
  hexfire orb in one palm and runes orbiting it). The Crossbowman, Hexweaver and Hexwarden share
  their kind's model with a different tint and size. They are Blender previews only, like the
  other Hexbound.
- **Balance:** measured against the same reference teams as before. Fresh starters still clear waves
  1 to 9 and meet the first dragon at 10; maxed starters reach 26 (was 28); fresh uncommons 17;
  starters with a Titan 29; maxed starters with a Titan 49; maxed mythics with a maxed mythic Titan
  win 94 of the first 100 waves and first stall at the wave-70 dragon boss (was 79: it comes down to
  which foes that wave draws, not to the new foes being stronger).

## Costs and limits

- Archers and mages need their own animations (a bow draw and a spell cast), which do not exist yet.
- Nothing yet makes an archer shoot from range: the fight rules have no range, so all foes strike
  the front of the line like animals do. Range is a possible later change, not part of this one.
