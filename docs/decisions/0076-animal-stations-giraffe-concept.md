# 0076: Animal Stations: the Giraffe (concept)

Status: the look accepted (SHANNON, 2026-11-17: "go ahead and make the regular giraffe and make a diamond
varient concept"); built and uploaded by STATION-077; hatchable with its variant since STATION-079 (decision 0079). Date: 2026-11-17.
Tasks STATION-074, STATION-077.

## What SHANNON asked

"make a giraffe concept art".

## What was made (`docs/concepts/giraffe-card.png`)

A faceted giraffe in the style of the other animals (`tools/blender/stations/assets/giraffes.py`,
`creature_giraffe`): a body high at the shoulders and sloping to narrow hips, very long legs with pale
lower halves and dark hooves, a long neck with a short dark mane down its back, a long head with a heavy
brow, a dark muzzle and amber eyes, two sharp horns with bare dark tips, and a thin tail with a dark
tuft. A cream coat under a net of chestnut patches. Jointed like every animal (head with the neck, four
legs, tail), so the game's walk and idle would fit it.

- Fact: about 22 studs tall at its draft size (the asset's scale, 2.9), taller than any animal now.
- Assumption: dangerous rather than cute (decision 0033): it reads as a fighter through its brow, its
  sharp horns and its size. Giraffes fight by swinging their heads.

## For SHANNON to decide

1. The look: go, or changes (for example darker patches, a heavier build, other horns).
2. What it is in the game: its rarity, which egg it hatches from, its role and its six stats; and
   whether it gets variants like the lions and cheetahs.
3. The go-ahead to build, upload and add it (a species in `StationConfig`, its attack clips).

## Built (STATION-077)

The Giraffe is built, exported and uploaded with its rainbow coat (`creature_giraffe`,
`creature_giraffe_rainbow`, decal 136160077733155 from upload-assets run 44184947829: it goes into
`uploaded.json` with the species, as a spec allows a coat only for an animal that hatches). It is not in `StationConfig.SPECIES` or any egg yet: every animal must have
a variant (decision 0037, checked by a spec), and its variant is the Diamond Giraffe, a concept waiting
for SHANNON (`docs/concepts/diamond-giraffe-card.png`: a silver-blue coat under faceted diamond plates
for patches, glowing diamond horns, a crest of glowing crystal down its neck, diamonds out of its
shoulders, glowing eyes).

Recommended draft numbers for when the two go in together (assumptions, for SHANNON to accept):

- Giraffe: rare, utility, pack (giraffes keep in herds), stats speed 50, strength 60, stamina 45, mana
  55, health 80, defence 25 (a total of 315, a little over the Lion's 310).
- Diamond Giraffe: mythic, its twist on defence.
- Eggs: the Safari Egg (wave 10) beside the Lion, and the Golden Egg; the Diamond Giraffe a rare drop of
  both, as rare as the Sun Lion.
- Its attack: the shared four-legged clip at first; a head swing of its own later.

## Not done

Nothing is uploaded or in the game. Its walk and attacks are not tried: the neck is part of the head
piece, as the cheetah's is, so a head-swing attack would swing the whole neck.
