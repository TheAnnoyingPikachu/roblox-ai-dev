# Animal Stations (game 7): design framework

Status: framework. The settled facts are in decisions 0019 to 0030; a later decision replaces an
earlier one, and 0029 to 0031 are the current summary. Every number is a draft.

## Pitch

Hatch animals from eggs, train them at your ranch, and send a team through endless waves of
harder and harder enemies. Your ranch is your base and a long tycoon. The hub is where you meet
vendors.

## The pieces

- **Animals:** a small African beta pool of 8 species (`game7-animals.md`). Each has a role
  (Attack, Defence, Utility), a group (pack or solitary) and three super-rare variants. The
  Elephant is the Titan: legendary only, a rare hatch from the egg that unlocks at player level
  15 (there is no legendary-only egg). The eggs are placeholders: an overhaul is planned.
- **Stats:** Speed, Strength, Stamina, Mana, Health, Defence. Each has a level up to 70;
  training raises it and a maxed stat is doubled. On hatch every stat starts at a level from 1
  to 15, higher numbers being rarer, with a 1 in 100,000 jackpot of one stat at 70.
- **Team:** three animals in any mix, plus one Titan in its own fourth slot.
- **Battles:** automatic and decided by the server. Attack beats Utility, Utility beats Defence,
  Defence beats Attack (a slight edge). Pack and solitary animals get group bonuses. Mana sets
  how often power attacks happen.
- **Waves:** an endless line of enemy teams that keep growing, with a variant boss every tenth.
  Clearing a wave pays coins.
- **Player level:** from XP. Hatching gives XP now; waves will too.
- **Places:** the hub (plaza, egg stalls) and one ranch island per player, joined only by
  teleport pads. Animals train at the ranch. Mountains ring every area to hide the void. A
  canyon through the hub's mountains is the wave arena. A server holds 3 players.

## Words

"Level" means three things, so use: **wave** (the endless levels), **stat level** (0 to 70) and
**player level**.

## Built

- Pure, tested rules in `src/shared`: `StationConfig`, `StationRules` (hatch, stat levels,
  roles), `BattleRules` (team battle), `LevelRules` (waves, rewards), `StationProgress` (the
  saved profile: coins, XP, animals, team, Titan, training).
- Server: saves, egg buying at the stalls, team and training requests, ranch assignment and
  teleports. Client: coins and level, and the Animals panel.
- World: the hub with its wave arena canyon and three ranch islands, as simple placeholders.

## Not built yet

- Wave battles in the arena. Until then coins, wave progress and most XP cannot be earned in play.
- Animal models; animals standing on the training pads or in the paddock.
- The ranch tycoon: universal upgrades and expansion, paid with gold and samples from harder
  enemies. More hub vendors.
- Magical attacks, microgames, PvP (on hold; it will be the three-role loop), teams of 3 players.
- The standard features: start menu, logins, quests, cosmetics, leaderboard, music.

## Open questions

- What Speed, Strength and Stamina each do on their own (attack comes from the best of the four
  non-Health, non-Defence stats today).
- How waves give XP, gold and samples.
