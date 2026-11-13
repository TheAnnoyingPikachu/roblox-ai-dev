# Animal Stations (game 7): design spec (foundation draft)

Status: foundation only. Facts are in decision 0019. Everything else here is a **hypothesis**
to settle in later tasks.

## Pitch

Hatch animals from eggs. Every animal has four stats: speed, strength, swim and smarts. Put each
one to work at the mini-game station that matches its best stat to earn coins, then buy better
eggs. A cheetah belongs on the Speed Track. A dolphin belongs in the Swim Pool.

## Core loop (hypothesis)

1. Buy an egg with coins and hatch it. The odds are shown on the egg.
2. Look at the new animal's stat card and assign it to a station.
3. Stations earn coins every second from the animals working there (`StationRules.rate`).
4. Optional: play the station's mini-game yourself with an animal for a short burst bonus.
5. Buy better eggs for animals with higher stats.

## Built so far

- `StationConfig`: 4 stats, 5 rarities, 11 animals, 2 eggs, 4 stations.
- `StationRules`: `hatch`, `rate`, `bestStation`, `income`, tested in `StationRules.spec.luau`.

## Next (not started)

Save profile and remotes (kit), the server loop, a hub world with the four stations, stat cards
and assignment UI, animal models, playable mini-games, and the user's standard features (start
menu, logins, quests, cosmetics, leaderboard, music).
