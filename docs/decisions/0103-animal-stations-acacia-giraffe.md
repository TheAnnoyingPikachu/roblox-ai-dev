# 0103: Animal Stations: the Acacia Giraffe, a new variety

Status: accepted (SHANNON, 2026-11-20: "make a new spot for the acacia giraffe and add it to the eggs and
such"); the tier, twist and odds below are Claude's draft, to confirm. Built by STATION-109.
Date: 2026-11-20. Task STATION-109.

## Context

- SHANNON made a giraffe with acacia trees growing on it in ForgeGUI (artifact 6e93bd49). The giraffe
  had one variety, the mythic Diamond Giraffe, so the model had no place.

## What

- A new variety of the giraffe: `acacia_giraffe`, "Acacia Giraffe".
  - **Tier: legendary.** Every other species has a legendary and a mythic; the giraffe lacked its
    legendary.
  - **Twist: health** (a living tree; the Diamond Giraffe's is defence).
- **Eggs:** where the giraffe hatches, at the Shadow Lion's odds (the Lion's legendary; the Lion and
  the Giraffe are both rare):
  - Safari Egg: 1 in 2,000.
  - Golden Egg: 1 in 400.
- Its model is the ForgeGUI one, skinned to the rig (decision 0102), `creature_giraffe_acacia_forge`.
- No save changes: a new variety is only a new id that saves may come to hold.

## Facts

- Variety tiers and twists: `StationConfig.TIERS` (legendary x2 and +40 on the twist stat).
- A variety no egg lists never hatches; a spec checks every variety is listed.

## Assumptions

- The draft odds match the Shadow Lion's; SHANNON can change either number.
