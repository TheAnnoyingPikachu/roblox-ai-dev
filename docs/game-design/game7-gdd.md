# Animal Stations (game 7): design framework

Status: framework. The settled facts are in decisions 0019 to 0032; a later decision replaces an
earlier one, and 0029 to 0032 are the current summary. Every number is a draft.

## Pitch

Hatch animals from eggs, train them at your ranch, and send a team through endless waves of
harder and harder enemies. Your ranch is your base and a long tycoon. The hub is where you meet
vendors.

## The pieces

- **Animals:** a small African beta pool of 8 species (`game7-animals.md`). Each has a role
  (Attack, Defence, Utility), a group (pack or solitary) and three super-rare variants. The
  Elephant is the Titan: legendary only, a rare hatch from the egg that unlocks at player level
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
- **Waves:** an endless line of enemy teams that grow 3% a wave, with a variant boss every
  tenth. Clearing a wave pays coins.
- **Player level:** from XP, and XP comes from everything: hatching and creature level-ups now;
  waves, daily, weekly and monthly login tracks and gear levels when they exist.
- **Places:** the hub (plaza, egg stalls) and one ranch island per player, joined only by
  teleport pads. Mountains ring every area. A canyon through the hub's mountains is the wave
  arena. A server holds 3 players.

## Words

"Level" means three things, so use: **wave** (the endless levels), **stat level** (0 to 70) and
**player level**.

## Built

- Pure, tested rules in `src/shared`: `StationConfig`, `StationRules` (hatch, stat levels,
  training time), `BattleRules` (wave fights), `LevelRules` (waves, rewards), `StationProgress`
  (the saved profile: coins, XP, animals, team, Titan, training).
- Server: saves, egg buying at the stalls, team and training requests, ranch assignment and
  teleports. Client: coins and level, and the Animals panel.
- World: the hub with its wave arena canyon and three ranch islands, as simple placeholders.
  SHANNON has said the world is right for now.
- The first animal models (decision 0033): the Rhino and the mythic Lava Rhino, jointed and
  animated (idle, walk, horn attack, magic attack). They pace each ranch's paddock as a showcase.

## Not built yet

- Wave fights in the arena. Until then coins, wave progress and most XP cannot be earned in play.
- The other animals' models; owned animals standing on the training pads or in the paddock.
- The ranch tycoon: universal upgrades, expansion and training enhancements, paid with gold and
  samples from harder enemies. More hub vendors. Gear. The egg overhaul.
- Login tracks (daily, weekly, monthly). Saving to Roblox is deferred ("we'll do saving later").
- Magical attacks, microgames, teams of 3 players.
- Fights between players. They will work differently from wave fights and stats will not affect
  them. Nothing is built with them in mind.
- The standard features: start menu, quests, cosmetics, leaderboard, music.
