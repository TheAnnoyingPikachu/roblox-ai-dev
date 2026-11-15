# 0049: Animal Stations: admin menu adds animals to your ranch

Status: proposed (for SHANNON at the next Animal Stations checkpoint)
Date: 2026-11-15. Amends 0038 (admin menu). Task STATION-032.

## Decision

0038 kept the admin menu to display only. SHANNON asked for a second admin menu that adds
creatures to their ranch, so ranch features and fights can be tried without hatching eggs.

- A second admin button, **Add animals**, under the Admin button opens a list of every species and
  variant. A first button picks the stat level the new animal gets (1, 10, 35 or the maximum, 70).
- The action `admin_add(k, level)` is a new remote contract. `k` is the place in the server's
  `LOOKS` list (species, then variants, then foes); a foe or an unknown place is refused.
- The server runs `isAdmin` first (the owning user, or Studio), then `StationProgress.give`, a pure
  function that checks the species, variant and level, adds the animal with a new id and puts it on
  the team the way a hatched one is. It skips the Barn's limit and keeps the save's limit
  (`MAX_ANIMALS`, 100). It touches nothing else: no coins, eggs, XP or upgrades.
- It changes only the admin's own save. No other player's data is reachable, and nothing is migrated.

## Open for SHANNON

- ~~Live or Studio only.~~ Settled by SHANNON (2026-11-15): the admin menus stay in live games, for
  the game's owner only (`isAdmin`: the owning user, or anyone in Studio).
