# 0069: Animal Stations: training fitted to an animal's size

Status: accepted (SHANNON, 2026-11-16: "make a unique training animation for each creature and their
varients that works with their size etc", then "if creatures are of similar size then reuse the
animations, its just that small creatures look weird training strength under a large barbell", and
"go with the size fitted animation"). Task STATION-062.

## Three sizes

An animal's size class comes from its model's height (`Areas.class`):

| Class | Height | Who (of the 24) |
|---|---|---|
| Small | under 6.5 studs | the jackals, the cheetahs, the Tortoise and the Gemshell Tortoise, the Meerkat |
| Middling | 6.5 to 12 | the lions, the rhinos, the flamingos, the Storm and Star Meerkats, the Island Tortoise |
| Large | 12 and over | the three elephants |

Animals of one class train the same way; the clips are the six of decision 0066, which already
scale to an animal's own legs. What changes with the class is the kit it trains at and where.

## What each class trains at

| Station | Small | Middling | Large |
|---|---|---|---|
| Strength Gym, a new ranch and level 1 | a boulder 4 studs across | one 8 across | the great one, 14 across |
| Strength Gym, from level 2 | a barbell 15 studs long, on the floor before the deck | one 26 long, beside it | the great one, 42 long, on its stands |
| Guard Yard, from level 1 | the ram's log at under half size | at seven tenths | full size |
| Magic Library, from level 1 | sits on the cushions with a book of its own floating before it | at the great book | at the great book |

- The barbell rides the animal's back and the ram hangs at its head, whatever the class (decision
  0067); the class decides how big the piece is.
- Unchanged, since they suit any size: the Speed Track, the Swim Pool, the Healing Spring, the
  library's book on its stand and the guard yard's straw men on a new ranch.

## How

- No new models. The smaller boulders and barbells are the same models stood at a smaller size
  (`COPIES` in `Areas.luau`); the ram's log is made smaller and larger as animals come and go
  (`Areas.fit`, about the face of its head, so it still meets the animal's nose); the small
  reader's book is two plain parts.
- A piece now answers to a name (`Answers`: `bar1`, `bar2`, `bar3`) and the station's `Work` names
  the one its animal uses, so only that one moves.
- Display only: nothing here decides or delays any training.

## Not done

- No clip is different between the classes: a jackal and an elephant lift with the same motion at
  their own size.
- The flamingos are tall and thin: they are middling by height and use the middling kit.
- The two smaller boulders and barbells stand in the gym at every level, used or not.
