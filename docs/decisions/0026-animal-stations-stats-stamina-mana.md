# 0026: Animal Stations stats are Speed, Strength, Stamina and Mana

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Renames two stats from 0019; older decisions keep their original wording.

## Decision

- Training raises **Speed, Strength, Stamina and Mana**. Swim became Stamina and Smarts became
  Mana, so every animal keeps its numbers, role and matchups (read 0022 and 0024 with the new
  names: Speed beats Mana, Mana beats Strength, Strength beats Stamina, Stamina beats Speed).
- The Swim Pool trains Stamina. The Puzzle Library is now the Magic Library and trains Mana.
- **Every animal has magical attacks.** Not built: what the attacks are, and whether each stat
  gets its own job in battle (for example Stamina = HP, Mana = magic power) instead of today's
  "attack from the best stat".
- Saved profiles store stats by name. No published saves exist yet, so there is no migration;
  a Studio profile with the old names would be dropped by `sanitize`.

## Direction from SHANNON, recorded here, not built yet

When PvP comes back, the rock paper scissors loop will be between the three roles: Attack,
Defense and Utility (with the Titan as the legendary fourth slot, 0025). The current four-way
loop in `StationConfig.BEATS` stays until the roles are reworked.
