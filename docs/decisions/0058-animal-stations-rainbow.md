# 0058: Animal Stations: the rainbow coat, and a cleaner menu for adding animals

Status: accepted (SHANNON asked for it on 2026-11-16; the numbers are drafts)
Date: 2026-11-16. Tasks STATION-050 (the coat), STATION-049 (the menu).

## What SHANNON asked

"make a new add animals menu thats a bit cleaner and also add a rainbow texture that has a small
chance to apply to any animal on hatch".

## Decision

### The rainbow coat

- Any hatch, from any egg, of any animal or variant, comes out in a rainbow coat 1 time in 200
  (`StationConfig.RAINBOW_PPM = 5000`). It is rolled with the animal, when the egg is bought, after
  every other draw, so nothing else about a hatch changes.
- A look only. A rainbow animal has the stats, rarity, role and training of the same animal without
  the coat. It is named "Rainbow" on the card under the cursor and when it hatches, and carries a
  RAINBOW chip in the Animals menu.
- Economy value (rule 8): the chance. Fact: a Meadow Egg hatches in a minute and a Golden Egg in
  hours, and six eggs hatch at once. Assumption: at 1 in 200 a player who plays every day meets a
  rainbow in the first days, which keeps it a surprise without making it a rumour. Not playtested.
- Data schema (rule 8): an animal gains one optional field, `rainbow = true`. It is absent on every
  other animal, so nothing is added to old saves and they load unchanged; `sanitize` keeps only a
  true one. The field rides inside a bought egg and is never sent to the client before the egg opens.

### How the coat is made

- A second texture for the model that is already uploaded, one for each of the 24 animals and
  variants (`tools/blender/stations/rainbow.py`). The position of every texel is baked through the
  model's own UVs: the hue runs through the rainbow one and a half times from the nose and the top
  to the tail and the feet, and how light a texel is comes from the painted texture, stretched so a
  black animal is as bright a rainbow as a pale one. Spots, stripes, plates and facets stay.
- The smaller option was one shared rainbow image for every animal. Not taken: the models' UVs are
  an atlas of loose islands, so one image would come out as a patchwork, not a rainbow.
- The coats are uploaded as Decals of their own (`<asset>_rainbow`), and `StationAssets` gains
  `rainbowDecal` and `rainbowTexture`. `Creatures.spawn(..., rainbow)` swaps the texture of the
  painted pieces and adds a few sparkles; the client turns the Neon pieces of a rainbow animal
  through the colours. Its pictures use the coat too (`Portrait`, option `rainbow`).

### The menu for adding animals (decision 0049)

- A grid of tiles in place of the list of buttons: each animal and variant is its picture and its
  name in its rarity's colour, a species followed by its variants. One row on top picks the level of
  every stat (1, 10, 35, 70) and whether the new animal wears the rainbow coat; with the coat on,
  the pictures show it. Tapping a tile adds the animal and says so.
- Remote contract (rule 8): `admin_add` takes a third argument, a boolean: the rainbow coat. As
  before the server checks that the player is an admin and that every number is in range.

## Not done

- A rainbow animal is not stronger and is not worth more. Whether it should be is SHANNON's call.
- The Hexbound and the eggs have no rainbow coat.
- No sound, and no announcement to other players when one hatches.
