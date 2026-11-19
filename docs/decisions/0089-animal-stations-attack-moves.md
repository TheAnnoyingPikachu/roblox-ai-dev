# 0089: Animal Stations: a regular and a power attack for every species

Status: accepted (SHANNON, 2026-11-19: "start making the attack animations except change the meerkats
power attack so that it works when facing the enemy"); built by STATION-096.
Date: 2026-11-19. Task STATION-096.

## What SHANNON chose

The storyboarded moves (ForgeGUI storyboards, one per species): a regular attack and a power attack each.
The meerkat's power move changed: its crew no longer rings the target but pops up in a line between the
meerkat and the enemy, facing the enemy, and pelts it from there.

| Species | Regular (0.95 s, hit at 0.44 s) | Power (1.6 s, hit at 0.92 s) |
|---|---|---|
| Jackal | Snap Lunge | Pack Howl: two ghost jackals streak into the target |
| Tortoise | Shell Bash | Shell Spin: three turns tucked in its shell, a shockwave and rock |
| Meerkat | Burrow Pop: under the ground, up under the target | Sentinel Call: a crew of four between it and the enemy throws pebbles |
| Cheetah | Pounce Swipe | Blur Dash: a zig-zag streak to the target, claw marks |
| Rhino | Horn Toss | Stampede Charge: pawing, dust all the way, rock under the target |
| Flamingo | Beak Jab | Flamingo Twirl: two turns on one leg, a whirl of feathers into the target |
| Lion | Claw Maul | King's Roar: a cone of shockwaves |
| Giraffe | Neck Swing | Sky Stomp: rears and slams, rock under the target |
| Elephant | Trunk Slam | Titan Quake: glowing cracks and rock under the target |

## How (facts)

- All in `src/stations-client/Creatures.client.luau`, display only, the way the clips already worked
  (method 1 of the concept page): poses on the seven pieces, and `cues`, effects each clip fires once at
  a time into it (`CUES`). A clip with `under` sinks into the ground (nothing lifts its feet).
- Each animal's effects take a colour from `FX` (by asset, then species): the ForgeGUI models (0088) have
  no Neon pieces to read a colour from. Lava, Fire and Phoenix are `MOLTEN`.
- `WaveShow` sets `AimAt` (the target's middle) on an animal as its power attack starts, so the ghosts,
  the crew's pebbles, the streak and the roar reach the target. Nothing reads it to decide anything.
- Angles now ease the short way round, so a spin that ends on whole turns stops there.

## Not done (facts)

- The variants' own twists from the concept page (Storm's lightning, Phoenix's fire tornado and so on):
  for now a variant plays its species' moves in its own colour.
- The tortoise, cheetah and rhino travel only a few studs in their poses; the effects carry the rest.
  Moving the animal itself to the target would be a server change in `WaveShow`.
- Assumption: the poses read well on the new models; checked by build and lint, not yet seen in Studio.
