# 0060: Animal Stations: the hub's centre in the game, a smaller hub, nearer ranches

Status: the centre is replaced by decision 0064 (the gathering place) and the ranches' distance by
0065 (840); the smaller hub stands. Accepted by SHANNON, 2026-11-16: "go ahead with the centre area,
make the grass area in the hub a bit smaller and bring the ranches in a tad". Task STATION-052.

## The centre

The concept of decision 0059 (`docs/concepts/hub-centre-card.png`) is now what stands on the plaza.

- It is twelve models, built by `tools/blender/stations/assets/hub.py` from the very functions that
  drew the concept (`scenes/hub.py`): the paving, the fountain, a statue's plinth (stood eight times),
  a shrine for each of the four eggs, a raised garden with its lamps, flags and benches (stood four
  times), the three gateways (WAVE ARENA, WELCOME, RANCHES twice) and the pair of market stalls.
- Each model is built where it stands on the plaza and exported uncentred (`finalize: center False`),
  so the game stands every one on the plaza's middle and only turns the ones that repeat
  (`CENTRE` in `World.luau`). A model is one painted `body` and, where it shines, a Neon `body_glow`,
  like an egg, and goes through the same build, upload and `StationAssets` as the animals.
- Made from models the game already has: the Golden Egg on the lotus, the egg in each shrine
  (`World.kit.eggModel`), and the statues. A statue is an animal's own model with no texture, in
  pale limestone (`Creatures.statue`; Roblox's marble showed dark veins like cracks): one of each of the eight animals on the plinths, with its name on the
  plate, and four small tortoises on the fountain's lip.
- The models take no collisions. `World.luau` adds unseen parts for what is solid: the floor, the
  pools and their lip, the plinths, the shrines' floors, the garden beds, tree trunks, benches, the
  gateways' piers and the stalls.

### Changed from the concept

- A gateway's piers stand 9.2 studs either side of the road's middle, not 7: the game's roads are
  18 studs wide, the concept's sketched road was 10.5.
- The Golden Egg faces south, to the walk players arrive by.
- The fountain's upper bowl holds water (the concept's had a stone lid by mistake), and its lotus is
  a stronger pink: the first bake came out grey in the game, so the fountain was built and uploaded
  twice. The first upload is listed in the register as replaced; it is not archived.
- A player can step over the lower pool's lip and wade to the stem.
- Gone from the old plaza: the plain basin and pedestal, the eight rim lamps, the benches with brick
  planters, and the "Welcome to Animal Stations!" board on the south walk (the WELCOME gateway
  replaces it).

### Not done

- The lamps and gateway lanterns glow (Neon) but cast no light of their own: the hub is always in
  daylight. One light per lamp is a small addition if nights come.
- If a model fails to load, its piece is simply missing (the eggs still fall back to plain shells);
  the unseen walls stay.
- Assumption, not measured: the whole centre is about 110,000 triangles with its statues and eggs.
  Phones have not been tried.

## A smaller hub, nearer ranches

Reading of the request: "the grass area in the hub" is the hub's lawn, the walkable ground between
the plaza and the mountains. If the raised gardens on the plaza were meant, that is a change to the
garden model instead.

| Number (`World.luau`) | Was | Is |
|---|---|---|
| `HUB_RADIUS`, the plaza's middle to the hub's wall | 300 | 250 |
| `RANCH_DIST`, the plaza's middle to a ranch's middle | 900 | 780 |
| The walk from the plaza's kerb to a ranch's gate | 777 | 657 |

- The pass up to a ranch is 70 studs shorter; its climb is as long and as steep as before
  (`PASS_TOP` is now the island's edge, `PASS_RAMP` 165 studs before it).
- The hub's groves, forest ring and flower beds follow `HUB_RADIUS`.
- The wave arena has not moved: its place is also written into the client's dusk fade
  (`ArenaMood`), and it was not asked for. The north road now runs 80 studs inside the canyon's
  mouth before the arena, where it ran 30.
