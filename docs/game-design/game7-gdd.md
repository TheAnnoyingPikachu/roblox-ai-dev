# Animal Stations (game 7): design framework

Status: framework. The settled facts are in decisions 0019 to 0032; a later decision replaces an
earlier one, and 0029 to 0032 are the current summary. Every number is a draft.

## Pitch

Hatch animals from eggs, train them at your ranch, and send a team through endless waves of
harder and harder enemies. Your ranch is your base and a long tycoon. The hub is where you meet
vendors.

## The pieces

- **Animals:** a small African beta pool of 8 species (`game7-animals.md`). Each has a role
  (Attack, Defence, Utility), a group (pack or solitary) and one rare variant, always legendary
  or mythic (decision 0037); a normal animal is never above epic. The Elephant is the Titan:
  legendary, a rare hatch from the egg that unlocks at player level
  15 (there is no legendary-only egg). The eggs are placeholders: an overhaul is planned.
- **Stats:** six, each with one job in a wave fight:

| Stat | Job |
|---|---|
| Speed | attack speed: how fast an attack happens |
| Stamina | the delay between attacks |
| Strength | damage |
| Mana | how much each attack charges the power attack |
| Health | HP |
| Defence | cuts incoming damage |

- **Stat levels:** every stat has a level up to 70, and a maxed stat is doubled. Species still
  matter: a stat's value is the species' number grown by its level. On hatch every stat starts
  at a level from 1 to 15 (a 15 is 1 in 90), with a 1 in 10,000 jackpot of one stat at 70.
- **Training:** in real time at the ranch, also while you are away. Every level takes a little
  longer than the last: two minutes for level 1, about a day for level 61 and two days for
  level 70 (about three weeks for one stat). Training enhancements will shorten this.
- **Team:** three animals in any mix, plus one Titan in its own fourth slot.
- **Wave fights:** on a clock and decided by the server. Attack animals hit harder, Defence
  animals draw the enemies' hits and take less, Utility animals heal. Pack and solitary animals
  get group bonuses.
- **Waves:** an endless line of enemy teams that grow 3% a wave, with a dragon boss every
  tenth. The enemies are the Hexbound (decision 0040), evil magic knights, archers, mages, ogres and
  dragons, not animals (`game7-enemies.md`). Clearing a wave pays coins.
- **Player level:** from XP, and XP comes from everything: hatching and creature level-ups now;
  waves, daily, weekly and monthly login tracks and gear levels when they exist.
- **Places:** the hub (plaza) and one ranch per player behind the hub's mountains,
  south, east and west (decision 0035). A ranch is reached by teleport pad or on foot up its own
  mountain pass, ready for riding animals later. Mountains ring every area. A canyon through the
  hub's mountains to the north is the wave arena. A server holds 3 players.

## Words

"Level" means three things, so use: **wave** (the endless levels), **stat level** (0 to 70) and
**player level**.

## Built

- The Hexbound enemies in game (decision 0042): five models with their own animations and a dark
  glow each.
- The battle arena (decisions 0045, 0046): a walled stone pit about 190 studs long with a gatehouse,
  braziers, banners, statues, cages and bones, a dais for the team, the Hexbound's gate that the
  enemies walk out of, a violet dusk that fades in as you walk in, a fight camera and a wave title.
- The Breach (decision 0047): behind the gate, a scorched road to a vast, half-broken portal ring the
  Hexbound tore open, with detailed demon heads and carved columns on the arena's structures.
- A Home button on the bottom bar teleports a player to their ranch.
- A new UI (decision 0044): a bottom bar (Animals, Waves), card-style sheets with animal and
  enemy portraits, a player card with level, XP, coins and samples, laid out for phone, tablet and
  desktop.
- Real wave fights (decision 0043): the wave gate at the arena's entrance lists the waves open to
  you; the server decides the fight with your team, pays coins, XP and samples, and the arena
  replays it with health bars and damage numbers. One fight at a time; a loss costs nothing.

- Pure, tested rules in `src/shared`: `StationConfig`, `StationRules` (hatch, stat levels,
  training time), `BattleRules` (wave fights), `LevelRules` (waves, rewards), `StationProgress`
  (the saved profile: coins, XP, animals, team, Titan, training).
- Server: saves, egg buying at the stalls, team and training requests, ranch assignment and
  teleports. Client: coins and level, and the Animals panel.
- World: the hub with its wave arena canyon and three ranch islands, as simple placeholders.
  SHANNON has said the world is right for now.
- The ranch tycoon (decision 0034): three upgrades bought in the ranch menu (opened at the Ranch House door) with coins and
  samples. Ranch House: animals training at once (2 to 6). Barn: animals you can keep (10 to 80).
  Training Grounds: training speed (100% to 200%). Every level changes how the ranch looks.
- Eggs (decision 0036): bought from the egg vendor on the ranch into the egg storage; the player
  chooses which to hatch, six at once; they take 1 minute to 4 hours; a finished egg is opened by
  hand at the hatchery. A gear vendor's stall stands ready for gear.
- A model for every animal and its variant (decisions 0033, 0037): sixteen jointed models that
  share the same moves (idle, walk, attack, magic attack). A player's animals walk the roaming
  area of their ranch. Each egg type has its own model, and opening one plays a hatching
  animation before the animal steps out of its nest.

## Not built yet

- Archers and mages firing a visible arrow or spell (the rules have no range yet).
- Hexbound hit and death effects beyond the fall, a roar, and a prediction of how a fight will go.
- Animals standing at the training court they train at.
- More ranch upgrades and expanding the plot. More hub vendors. Gear. The egg overhaul.
- Login tracks (daily, weekly, monthly). Saving to Roblox is deferred ("we'll do saving later").
- Magical attacks, microgames, teams of 3 players.
- Fights between players. They will work differently from wave fights and stats will not affect
  them. Nothing is built with them in mind.
- The standard features: start menu, quests, cosmetics, leaderboard, music.
