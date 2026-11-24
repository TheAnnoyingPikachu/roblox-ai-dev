# 0112: Animal Stations: release and fusion

Status: accepted (SHANNON, 2026-11-24); the numbers are Claude's draft, for the QA pass. Task STATION-132.
Date: 2026-11-24.

## Context

- Fact: the Barn holds 10 and nothing removed an animal, so after ten hatches eggs could not be opened.
- SHANNON: "option A but also add the ability to trade 4 animals into the next rarity of shiny animal eg 4 normal
  becomes 1 coat variant".

## What

- Release (`StationProgress.release`): an idle animal goes for `RELEASE_PAY` coins by rarity (common 10 up to
  secret 15,000), twice that with a coat. Never one in the team or the Titan's slot, training, locked, or the last.
  The animal panel asks twice ("Sure? +N").
- Fusion (`StationProgress.fuse`): four idle animals of the same species, variant and coat tier become one: the
  first, wearing a coat of the next tier, each stat level the average of the four (rounded down). The coat tiers are
  `StationConfig.COATS` grouped by rarity, commonest first: the five stat coats, Rainbow, Gilded or Galaxy,
  Spectral, Prismatic. A plain animal fuses into a stat coat; Prismatic is the top. The server picks which coat of
  the tier at random. The panel shows "Fuse 4" when four match.
- Remote contract: `release(id)`, `fuse(id, id, id, id)`.

## To confirm at the checkpoint

1. The ladder: plain, stat coat, Rainbow, Gilded or Galaxy, Spectral, Prismatic (so 4^5 = 1,024 plain animals make
   one Prismatic). Rejected: fewer steps, or a choice of coat instead of the server's pick.
2. Fusing averages the levels rather than keeping the best (so fusing never trains an animal for free).
3. The release pay.
