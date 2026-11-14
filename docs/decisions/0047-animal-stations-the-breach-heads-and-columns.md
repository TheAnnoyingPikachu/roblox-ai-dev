# 0047: Animal Stations: the Breach, a detailed demon head and carved columns

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0046.

## Decision

From SHANNON: "add a large portal behind the arena, some sort of gateway that the enemies have breached
into the world from, also give more detail to the existing structure such as a more detailed head on the
top and better looking pillars".

- **The Breach** (`Breach.luau`). Behind the Hexbound's gate the canyon runs on, about 100 studs, to a
  vast ruined portal, the gateway the Hexbound tore open to come through:
  - A great stone ring, 116 studs across and 120 high, spans the canyon: 28 blocks with iron bands and
    violet runes down the face, horns round the rim, three blocks torn out of the upper right (one
    lies at its foot, two hang askew), a crown of five great horns and a huge demon head at the top.
  - Seething red-violet energy fills it (a shimmering field, a deeper layer, a hot core that lights
    the ground, smoke and sparks blowing out toward the arena), and chunks of rock still hang in the air round the tear.
  - Broad stone steps climb from the road to its foot, between two spired, carved obelisks.
  - A scorched road leads to it from the gate, with glowing fissures, scorch marks, torn banners on
    poles, two burning, wrecked siege towers, great bone mounds and dark boulders that hide the hills.
  The Hexbound's gate in the arena is now the door into this corridor: its back wall is cut to two
  wings, so looking through the shimmering portal shows the road and the Breach beyond. The arena's
  enemies still walk out of the gate's portal; the portal and the ring are not the same thing.
- **A detailed demon head** (`ArenaKit.demonHead`, about 60 parts): a cracked, thorn-crowned cranium, a heavy
  brow with spikes, deep sockets with glowing eyes, cheekbones and cheek spines, a nose cavity, an
  open jaw of fangs, ridged three-segment horns and a glowing rune on the brow. It crowns the entrance
  gatehouse (the big one, 6.5 scale), the Hexbound's gate (4.5) and the Breach's ring (9), and a small
  one leers from each entrance tower as a gargoyle.
- **Carved columns** (`ArenaKit.column`): a stepped plinth, a drum base, a fluted shaft with iron
  rings and a violet rune band, and a capital with an abacus. They are the Hexbound's gate towers and
  the Breach's obelisks, stand at the corners of the entrance towers and hold up every brazier. The
  entrance towers also got stone bands, glowing arrow slits and a stepped overhang.
- **The fight camera** looks from a little lower (31 degrees) and less to the side (34), so the glow of
  the Breach shows over the gate. It also no longer gives up if the radius reaches the client after the
  focus (attributes arrive one at a time): that left the first fight of a session without the camera.

## Why

- The gate now has a reason to be there: they came through something, and you can see it.
- Heads and pillars are what players see first and most; they should be the best-made things in the place.

## Costs and limits

- The arena is now about 1,800 parts (the Breach about 450, and the heads and columns about 450 more) and
  loads whole with the rest of the world. Not measured on a phone; this is the first thing to trim
  (the Breach's debris, the columns' flutes, the gargoyles) if it is too much there.
- The ring's blocks are stacked rectangles, so its curve is faceted close up.
- The ring and the road are scenery: nothing walks out of the Breach, and nothing in the rules knows it.
- Nothing is animated: the ring's energy and smoke move, the stone does not.
