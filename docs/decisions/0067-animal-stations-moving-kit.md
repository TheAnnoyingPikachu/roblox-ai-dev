# 0067: Animal Stations: the training kit moves, and the menu shows a taken ground

Status: accepted (SHANNON, 2026-11-16: "can you make all the kit animations and menu grey effect",
and for the Speed Track "get rid of the finish line gate thingy and just have the checker on the floor
and get rid of this random bench"). Task STATION-060.

## What moves

In time with the animal that trains there (it rests when none does):

| Station | Kit | What it does |
|---|---|---|
| Strength Gym | the barbell (from level 2) | comes down off its stands onto the animal's back, sinks and rises with each lift |
| Strength Gym | the boulder (a new ranch and level 1) | is shoved along as the animal drives, and rolls back |
| Guard Yard | the first ram (from level 1) | hangs at the height of the animal's head and swings: it lands as the animal is thrown back |
| Guard Yard | the two straw men (a new ranch) | lurch at the animal as the blow lands |
| Magic Library | the great crystal (from level 3) | turns and bobs, faster while an animal reads |
| Speed Track | the runner | kicks up dust |
| Swim Pool | the swimmer | splashes at the water's top |

All the time, with no animal needed: the library's rings of light turn and its runes and font
glow and dim, candles and braziers flicker, the spring's channels and lanterns pulse and steam
rises off its water, the track's arrows pulse, and the guard yard's two throwers lob balls at the
shields they face (from level 3).

## How

- A piece that moves must be a model of its own. Three are new: `kit_gym_bar`,
  `kit_library_crystal`, `kit_guard_ram` (one model hangs in all three frames). They were cut out
  of five area models, which were built and uploaded again without them. Two whole area models
  move as they are (the boulder, the straw men). A Neon piece of an area model can glow, dim or
  turn by itself, since each glow colour is a piece of its own.
- The rams' ropes are drawn by the game (Beams from the frame to the log), so they follow the log
  when it is lowered and when it swings.
- The server stands every piece and says how it moves (`Kit` attribute, tag "Kit") and, on the
  station's folder, what its animal works at and how big it is. Each client moves the kit
  (`stations-client/Kit.client.luau`).
- The animal's clip and its kit are drawn by two scripts from one clock and one set of curves
  (`src/shared/TrainFx.luau`, with a spec), which is what keeps the ram's blow and the animal's
  flinch together.
- Display only: nothing here decides or delays any training.

## Fitting the animal

- The barbell comes down to the animal's back and a ram to its head, whatever its size. The
  barbell's discs are 13 studs across, so it cannot come lower than 6.8 studs: over a small animal
  it hangs above its back. SHANNON has since asked for training fitted to each animal's size
  (small animals should not be under the big barbell): that is the next task, not this one.

## The menu

In the Animals menu, a ground that another animal is training at is greyed out on every other
animal's card and reads "in use". Tapping it still asks the server, which refuses and says why.

## The Speed Track

Its finish gantry is gone (the chequered line on the ground stays) and so is the bench by the
fence. Level 4 now brings the stand alone.

## Not done

- No sound.
- The library's drifting books, the pool's floats, flags and bunting do not move.
- The second and third rams hang still: only the first has a pad an animal braces on.
