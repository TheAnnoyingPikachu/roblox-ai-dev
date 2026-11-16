# 0062: Animal Stations: a better-looking tortoise (proposal)

Status: proposed (cards for SHANNON; the three tortoises in the game are unchanged).
Date: 2026-11-16. Task STATION-054.

## What SHANNON asked

"after that could you try improve on the turtles looks?"

## What was wrong

Looked at on the cards of the three tortoises (`docs/concepts/tortoise-card.png` and the two variants):

- The shell was a plain dome with twenty-eight six-sided plates stuck on it apart from each other, like
  buttons; bare shell showed between them.
- The head was a blunt blob with a small beak; the legs were plain columns.

## What is proposed (`docs/concepts/tortoise-rework.png`: before above, after below)

All three tortoises share one body, so all three change.

- A shell of plates that share their edges, laid out like a real tortoise's: five down the spine,
  four down each flank, one over the neck and one over the tail, twenty-four round the rim. Each is
  raised in tiers that follow the shell's curve, so the plates meet in dark grooves and no bare
  shell shows.
- The Tortoise: a keel of bone spikes swept back down the spine, a spike on every other rim plate.
- The Gemshell Tortoise: every plate is now a cut gem in a gold setting, in the plate's own shape;
  the spine's still glow.
- The Island Tortoise: every plate is mossy stone with grass on top; its tree, rocks and flowers
  stand as before.
- A broader head with a heavy brow, two horns behind each eye and one on each cheek, a hooked upper
  beak over a shorter lower one, nostrils, a ribbed neck.
- Legs bent at the knee on broad feet with five claws; the forelegs wear rows of large scales.
- A spike on the tail, and a pale belly plate under the shell.

Where its joints are has not changed, so its animations fit as they are.

## If SHANNON approves

Not started. The three models would be built, baked and exported again, their three rainbow coats
painted again, and the six files uploaded by the Upload Blender assets workflow; the three old
models and six old images would then be unused (the images can be archived, the models cannot be
through the API). By the build's numbers the Tortoise would be 10.1 studs long where it is 9.0 (a
longer beak, a spike on the tail); not measured on a built model.

## Not done

- Not seen in the game engine, in a fight, as a statue on the hub's fountain, or in the menus'
  pictures.
- `tools/blender/stations/assets/tortoises.py` now holds the proposed build, so a rebuild of the
  tortoises gives the new look: do not rebuild them before this is decided. The previous file is the
  commit before this one.
