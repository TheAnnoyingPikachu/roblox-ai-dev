# Animal Stations (game 7): design spec (foundation draft)

Status: foundation only. Facts are in decisions 0019 to 0023. Everything else here is a **hypothesis**
to settle in later tasks.

## Pitch

Hatch animals from eggs. Every animal has four stats: speed, strength, stamina and mana. Train
them at the stations, build a team of three, and push through endless levels for coins to buy
better eggs.

## Roles, Titans and roster (decision 0027)

Three roles in a rock paper scissors loop, set by species: Attack beats Utility, Utility beats
Defense, Defense beats Attack. Titans are a separate legendary category in the team's fourth
slot. The roster is an African beta pool: Hyena, Jackal, Cheetah, Lion (Attack); Warthog,
Tortoise, Rhino, Gorilla (Defense); Meerkat, Flamingo, Giraffe, Mandrill (Utility); Elephant,
Hippo, Crocodile (Titans). This replaces the role and matchup parts of the sections below.

## Next direction (decision 0025, not built)

PvP on hold. Roles become Attack, Defense, Utility, with a **Titan** as a legendary fourth team
slot. The ranch becomes a long tycoon: upgrade areas bought with gold and **samples** dropped by
harder and harder enemies.

## Modes and roles (decision 0024)

One battle system, three modes: **endless wave grinding** (levels), **rock paper scissors PvP**,
and **training**. Each type is a role: Speed = Attack, Strength = Tank, Stamina = Defense,
Mana = Utility (healer). Stats were renamed in 0026 (swim to stamina, smarts to mana); every
animal has magical attacks.

## Pivot (decision 0023)

Train a team of three animals to clear **endless levels**. Stations no longer pay coins: they
**train** the station's stat. Coins come from clearing levels and buy eggs. Lobbies hold 3
players; teams of 3 players come later.

## Vision (decision 0021)

Three pillars on the same four stats: a **ranch** you raise animals on (your home base),
lots of short **silly reflex microgames** (our own designs), and **turn-based creature battles**.
Servers hold 3 players (0023); each gets a home ranch around the shared hub.
Battle matchups (decision 0022) are a rock paper scissors loop with a slight edge (x1.25):
Speed beats Mana, Mana beats Strength, Strength beats Stamina, Stamina beats Speed.

## Core loop (hypothesis)

1. Buy an egg with coins and hatch it. The odds are shown on the egg.
2. Pick a team of three and put spare animals on stations to train (`StationRules.train`).
3. Fight the next level (`LevelRules.battle`); clearing it pays coins (`LevelRules.reward`).
4. Optional: play a station's microgame for a training boost (not designed yet).
5. Buy better eggs, train, and push further.

## Built so far

- `StationConfig`: 4 stats, 3 roles + Titans, 15 African species (12 with a basic version and 3
  super-rare variants, 3 Titans; bestiary in `game7-animals.md`), 3 eggs, 4 stations.
- `StationRules`: `hatch`, `versionStats`, `rarity`, `stat`, `train`, `bestStat`, `role`, `matchup`; `LevelRules`: `enemies`, `fight`, `reward`; `BattleRules`: `fighter`, `battle` (roles), tested in `StationRules`, `LevelRules` and `BattleRules` specs.
- `StationProgress`: the saved profile (coins, animals, team, training), egg buying, tested in its spec. Server requests and a first HUD use it (0025).

- World (`src/stations/World.luau`): shared hub plaza, egg market, four stations, and three home
  ranches. The server gives each player a ranch and spawns them at its gate.

## Next (not started)

Save profile and remotes (kit), the server loop, a hub world with the four stations, stat cards
and assignment UI, animal models, playable mini-games, and the user's standard features (start
menu, logins, quests, cosmetics, leaderboard, music).
