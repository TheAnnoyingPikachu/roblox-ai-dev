# 0025: Animal Stations saves, egg buying, team and training requests; next direction

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0023 and 0024.

## Decision (built)

- **Profile** (`StationProgress`): coins, animals (id, species, variant, hatched stats, trained
  points, training station and start time), a team of up to 3 animal ids, best level cleared.
  New players start with 300 coins (three Meadow eggs). At most 100 animals.
- **Saves** use the kit (`Saves.start`, store `StationsProfile`, staging/studio suffixes as every
  game). `sanitize` repairs any stored shape; `snapshot` settles training on every write.
- **Buying:** a prompt on each market stall. The server checks coins, rolls the hatch with its own
  Rng (`StationRules.hatch`) and adds the animal; the first three join the team. In-game coins
  only (decision 0002).
- **Requests** (kit Router, rate limited, validated): `profile`, `buy egg`, `team id`,
  `train id station`, `stop id`. The client only names actions.
- **Training** is settled from timestamps: +1 per 60 s, at most 8 hours counted per settle while
  away, at most 4 animals training at once. A training animal is not in the team.
- **Client:** coins, hatch and refusal toasts, and an Animals panel (stats, role, team toggle,
  train, stop).

## Direction from SHANNON, recorded here, not built yet

- **PvP is on hold.**
- **Roles become Attack, Defense and Utility; the Titan is a legendary fourth team slot.** This
  replaces the four-role table of 0024 (Tank goes; which type maps to which role and how a Titan
  is earned are to design next).
- **The ranch is a long tycoon:** many upgrade areas bought with gold plus **samples** that drop
  from harder and harder enemies (in the style of collecting samples on missions). Long means
  hard to earn enough gold and samples, not a physically huge ranch.
