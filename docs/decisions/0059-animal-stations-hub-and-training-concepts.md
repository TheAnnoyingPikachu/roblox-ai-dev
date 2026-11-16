# 0059: Animal Stations: a finished hub centre and a large area for each training activity (concepts)

Status: proposed (concepts for SHANNON; nothing is in the game)
Date: 2026-11-16. Task STATION-051.

## What SHANNON asked

"start making concepts for a highly detailed finish centre of the map and then some concepts for
large areas specific for each training activity on the ranches, concept only for now".

## What was made

Seven places, built in Blender in the faceted style of the animals and eggs and rendered as cards: a
wide view over three closer ones (`docs/concepts/`). The game's own animals and eggs stand in them,
built by their asset files, so every size is true: a stud on a card is a stud in the game.

### The hub's centre (`hub-centre-card.png`)

The plaza keeps its size (48 studs to the kerb) and its four roads, so it fits where the plain one is.

- The Hatchery Fountain: the Golden Egg, 13 studs tall, on a pink lotus above two pools. Eight spouts
  fall from the upper bowl, four stone tortoises on the lip spit into the lower pool, lilies and koi.
- A sunburst of sixteen rays in the paving, three rings of slabs, bands of teal tiles, a mosaic ring.
- A ring of marble statues, one of each of the eight animals, on gilded plinths with name plates.
- Four round shrines on the diagonals, one for each egg, its roof in the egg's colour.
- Raised gardens between the roads: trees, hedges, flowers, benches with planters, sixteen lamps
  strung with flags.
- A gateway across each road, named for where it leads (WAVE ARENA in the Hexbound's purple and
  green, RANCHES, WELCOME), and two market stalls on the arena road.

### The six training areas (`training-family.png`, one card each)

Each is a fenced yard 64 by 48 studs behind a gateway in its stat's colour, with its name on it.

- Speed Track (blue): a four-lane clay oval, hurdles, a finish gantry with lights and a chequered
  band, glowing arrows through the bends, hay bales, a slalom and a tyre run in the infield, a
  covered stand, a timing tower with a great stopwatch.
- Strength Gym (red): a lifting deck under a timber frame with a barbell of stone discs, a boulder
  run on rails with a bell at its end, five stones on plinths from light to heavy, a log sled and
  yoke, tyres, a striking post, a climbing rope, kettlebells, braziers.
- Swim Pool (violet): a five-lane pool cut into a tiled deck, lane ropes, starting blocks, ladders,
  a three-board diving tower, a tube slide winding down from its own tower, a lifeguard's chair,
  parasols and loungers, palms.
- Magic Library (cyan): a floor of slate rings with a rune circle and a gold star, a great crystal
  turning over an open book with books adrift round it, a half ring of tall bookcases between
  columns, a window of coloured light, an orrery, a telescope turret, a font of mana, an hourglass.
- Healing Spring (green): three rock pools stepping down a hill with falls between them, steam, a
  crystal at the source, lilies and stepping stones, a bath house, a red arched bridge, stone
  lanterns, a herb garden, bamboo and blossom trees.
- Guard Yard (orange): a palisade with two gate towers, a rank of straw men behind shields, a log
  ram slung from a frame against a braced shield wall, a thrower that lobs sacks, sandbags, crossed
  stakes, racks of shields and armour.

### How they are made

`tools/blender/stations/stage.py` builds and renders whole places from small faceted pieces (one tone
a face, like `facet.py`), and can stand any asset in a scene at its real size, alive or as a statue.
The scenes are in `tools/blender/stations/scenes/`. Nothing is baked, exported or uploaded.

## For SHANNON to decide

1. The looks: approve, or ask for changes, place by place.
2. Room on the ranch. Fact: a ranch is a fenced square 150 studs across (`World.RANCH_HALF = 75`)
   and today's six courts are pads of 12 to 14 studs in one row. Six yards of 64 by 48 need about
   200 by 100 studs on their own. They do not fit beside the house, barn, hatchery and roaming
   field. Options: (a) a bigger ranch island with the areas round the edge (recommended: the island
   is already 350 studs across, so the fence can move out); (b) smaller yards, about 40 by 30, which
   lose the track's oval and the pool's lanes; (c) one area open at a time, chosen by the player.
3. What an area does. Today an animal trains from a menu and nothing shows it. The concepts assume
   animals are seen training in their area (running the track, pushing the boulder). That needs new
   animation clips and is a design decision of its own.
4. Upgrades. Today a court has a look for each of five levels. A large area would need its own
   stages (bare ground, then the pieces arriving). Not designed here.

## What putting them in the game would take (not started)

- Each place split into pieces for the game: big simple shapes from parts as today, the detailed
  pieces (statues, shrines, the fountain, the slide, the bookcases) as uploaded models through the
  normal build. Assumption: the hub centre is about 25 models and each area 8 to 15; not counted.
- The statues and shrine eggs reuse models that are already uploaded.
- Performance is not measured: the hub scene is 132,000 triangles as rendered, far more than the
  game's plaza today, and phones have not been tried.

## Not done

- No night views, no sound, no signs for the vendors.
- The plaza's surroundings beyond the kerb are sketched (trees, mountains), not designed.
