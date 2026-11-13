# 0021: Animal Stations vision (ranch, microgames, battles) and home ranches

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0019 and 0020.

## Vision (from SHANNON)

The game has three pillars, all driven by the same four stats:

1. **Ranch:** collect animals from eggs and raise them on your own home ranch.
2. **Microgames:** lots of short, silly, fast reflex games (our own designs, characters and art;
   a genre, not a copy of any existing game). A station's stat makes its microgames easier, and
   animals left on a station still earn idle coins (0019).
3. **Battles:** turn-based creature battles between animals (again a genre, our own system),
   using speed, strength, swim and smarts.

## Decision (built now)

- A server holds at most **6 players**. Each player gets a **home ranch** (lowest free of 6) on
  the outer roads around the shared hub: two each on the north, east and west roads; south stays
  the welcome walk.
- A ranch is a fenced yard with a gate sign showing the owner, a barn and silo, a paddock with
  8 tagged animal spots (`RanchSpot`) and an egg nest (`RanchNest`). Owners spawn at their gate.
- The hub plaza, egg market and stations are shared by everyone on the server.
- Max Players is a place setting a place file cannot carry: set it to 6 when publishing (as
  Garden does). The server warns when it is higher; a 7th player would stay at the hub spawn.

## Not decided yet

Microgame list and controls, battle rules (turns, moves, type matchups), whether players can
visit each other's ranches or battle each other, and how ranches are upgraded.
