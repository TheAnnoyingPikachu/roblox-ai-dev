# 0104: Animal Stations: the Shadow Legion replaces the Hexbound

Status: accepted (SHANNON, 2026-11-20, below); the stats, first waves and the revive numbers are Claude's
draft, to confirm. Built by STATION-113 (the models) and STATION-114 (the roster).
Date: 2026-11-20. Tasks STATION-113, STATION-114.

## Context

- SHANNON made 17 Shadow Legion enemies in ForgeGUI (01:27 to 02:01, from SHANNON's concept sheets), after
  the Shadow Knight (STATION-112).
- SHANNON: "begin rigging for everything from the heavy knight onwards ... every enemy is in you can get
  rid of all the old ones and add another menu to the admin screen that can spawn every enemy"; then
  "get rid of every old enemy and add every new model as a new enemy with stats and power numbers and
  such. after they are all spread them across the waves accordingly", "get rid of them [the Ogre Shaman,
  dragons and Gloom Imp] and just make every new model a new enemy", "battle preists heal enemies,
  necromancers revive dead enemies and darkcaster is just a damage dealing mage", and "there should be 17
  models now, rig them all please".

## What

- **18 enemies, each its own model** (`StationConfig.FOES`, model `foe_<kind>[_<word>]_forge`). Every
  old Hexbound enemy (15) and its Blender model (six: knight, archer, mage, ogre, dragon, imp) is gone.

| Enemy | Kind | Role | Group | First wave | Stats from |
| --- | --- | --- | --- | --- | --- |
| Shadow Knight | knight | attack | pack | 1 | Gloom Squire |
| Heavy Knight | knight | defense | solitary | 1 | Gloom Bulwark |
| Battle Priest (heals enemies) | mage | utility | pack | 1 | Gloom Banner |
| Shadow Archer | archer | attack | pack | 3 | Shade Archer |
| Shieldbearer | knight | defense | pack | 4 | new |
| Ogre Enforcer | ogre | attack | solitary | 5 | Ogre Brute |
| Darkcaster (damage mage) | mage | attack | solitary | 6 | Hexcaster |
| Berserker | knight | attack | solitary | 7 | new |
| Crossbow Troop | archer | attack | solitary | 9 | Shade Crossbowman |
| Cavalry | cavalry | attack | pack | 11 | new |
| Necromancer (raises the fallen) | mage | attack | solitary | 12 | new |
| Ogre Commander | ogre | attack | pack | 15 | Ogre Warlord |
| Shieldbearer Commander | knight | defense | solitary | 18 | new |
| Siege Golem | golem | defense | solitary | 22 | new |
| Cavalry Commander | cavalry | attack | solitary | 26 | new |
| Dark Drake | dragon | attack | solitary | boss from 10 | Hexfire Whelp |
| Shadow Dragon | dragon | attack | solitary | boss from 30 | Hexfire Drake |
| Ancient Alpha Dragon | dragon | attack | solitary | boss from 60 | Hexfire Dragon |

- An enemy that replaces an old one keeps its stats, so the waves stay as hard; the new ones sit between
  their neighbours in the line. A dragon still ends every 10th wave.
- **The Battle Priest heals** (the utility role, as the Banner and Hexweaver did). It opens at wave 1 so
  every role is there from the start, as before.
- **The Necromancer revives** (`ability = "revive"`): each of its power attacks raises the first fallen
  ally not raised before, at `BattleRules.REVIVE_PCT` (50 %) of its max HP. Each enemy is raised at most
  once a fight, so a fight still ends. Its power score counts it as a quarter more HP. The replay shows the
  fallen enemy standing up again, glowing, with its health bar back.
- **The Darkcaster** is a plain damage mage (attack role).
- **Swarm waves have no minions** now (the Gloom Imp is gone): their crowd is all regulars, still matched
  to the classic wave's power (`LevelRules.CROWDS`, minions 0).

## The models

- Each is cut from SHANNON's sheet (bases, signs, second copies and back views dropped) and skinned by
  `tools/blender/stations/skin_forge.py`. The dragons and the Cavalry that stood at an angle were turned to
  face forward.
- **Rigged in whole parts** (SHANNON, 2026-11-20: "many of the models have warping parts"; "go for method
  one now"). ForgeGUI grows arms, capes and weapons onto the body, so skin blended across a joint smeared
  them. Each model's joints and parts are placed by hand (`legion`: boxes read off the `--stretch` bones
  view), and the skin is cut apart where two bones' parts meet, so every part moves whole. That is the
  look of a Roblox rig with separate limbs: a joint bent far can open a small gap, but nothing stretches.
  Capes, cloaks, robes, quivers and banners stay on the body. Riders: the horse's head, legs and tail
  move; the rider and what it holds ride the body. Dragons: wings, head, tail and legs from the elbow and
  knee down.
- `skin_forge.py --stretch` poses a model at the peak of each of the game's clips and draws every face
  stretched by a quarter red: all 18 are at 0% (the first rigs reached 36%).
- Creatures: a `foe_dragon*` model is Winged, a `foe_cavalry*` one four-legged, any other foe Biped; the
  attack clip comes from the kind (archers draw, mages cast, the rest chop).

## Not checked

- The new stats and first waves are not balance-tested beyond the existing wave tests.
- The swarm power multipliers were set with minions; to recheck now the crowds are all regulars.
