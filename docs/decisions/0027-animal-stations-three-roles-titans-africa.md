# 0027: Animal Stations three roles, Titans, and the African beta pool

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Replaces the four-way loop of 0022, the four roles of 0024 and the roster of 0020.

## Decision

- **Three roles in a rock paper scissors loop**, set by the species (not by the best stat):
  Attack beats Utility, Utility beats Defense, Defense beats Attack. Edge unchanged: x 1.25.
  - Attack: damage x 1.3.
  - Defense: enemies must hit it while it stands, and it takes damage x 0.8 (Tank is gone).
  - Utility: after attacking, heals the most hurt teammate by half its attack.
- **Titans are their own category outside the loop** (neutral to everyone): legendary, far
  bigger stats, no variants, no special job. A team is three animals plus **one Titan in a
  fourth slot** (`Profile.titan`). Titans can train like any animal.
- The four stats stay Speed, Strength, Stamina and Mana (0026). Attack still comes from an
  animal's best stat, HP from all four, turn order from Speed.
- **African beta pool** (15 species; the old 16 are removed):
  - Attack: Hyena, Jackal (common), Cheetah (uncommon), Lion (rare).
  - Defense: Warthog, Tortoise (common), Rhino (uncommon), Gorilla (rare).
  - Utility: Meerkat, Flamingo (common), Giraffe (uncommon), Mandrill (rare).
  - Titans: Elephant, Hippo, Crocodile.
  - Each non-Titan keeps three variants (epic, legendary, mythic): 36 in all. Looks:
    `docs/game-design/game7-animals.md`.
- Eggs keep their names and prices. Titans hatch from the Safari Egg at 4% in total. **This is
  a placeholder**: how Titans are earned was not specified.
- Level enemies are never Titans (yet).

## Checks (tests)

Equal animals: each role beats the one it should from either side. One of each role beats three
of any single role with the same stats. Level reach (draft): starters 8, trained starters 14,
rares 23, rares + Titan 27, legendary team 37, trained rares + Titan 45.

## Not decided yet

How Titans are earned; Titan bosses in the levels; the magical attacks; PvP (on hold).

## Direction from SHANNON, recorded here, not built yet

- **No restrictions on team make-up** (any mix of roles, such as three Attackers), except
  **only one Titan** per team. Both already hold in the rules.
- **Sub-factions** such as pack animals and solitary animals will give bonus buffs (for example
  a pack animal is stronger with other pack animals, a solitary animal stronger alone). Which
  species are in which sub-faction and the buff numbers are to design.
