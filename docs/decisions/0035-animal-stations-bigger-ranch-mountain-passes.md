# 0035: Animal Stations bigger ranch plot, mountain passes to the ranches, mountains with shape

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Changes 0029 (ranches reached only by teleport) and the world layout of 0030.

## Decision

From SHANNON: "the ranch is great but make it a bit larger as to fit everything a bit more
spaciously, also make the surrounding mountain more detailed as to conceal the area better and
make it look better", "also make it possible to walk through the mountains to the main area and
teleport as eventually we will add animal riding and controlling", "make all the signs fit
better".

- **Bigger plot.** The fenced ranch is 150 studs across (was 120). Buildings keep their size, so
  everything has more room: `Ranch.luau` keeps its layout numbers and stretches them by
  `World.RANCH_HALF / 60`.
- **A pass to every ranch.** Each ranch can be reached on foot as well as by teleport: a road
  leaves the hub, runs through its own canyon and climbs 22 studs to the ranch gate. About 525
  studs from the hub's edge to the gate, half a minute on foot.
- To make that work the ranches moved: **900 studs out (was 1,200)**, and they lie **south, east
  and west**. The north ranch moved south, because the wave arena already fills the north canyon.
  The hub's teleport pad moved beside the south road.
- **Mountains with shape.** A mountain is no longer one smooth dome: it has two higher peaks with
  snow, lumps and ledges of rock on the slope, and grassy foothills with pines on the side it is
  seen from. A ranch has a second, taller row behind the first. Terrain grass now matches the
  lawns.
- **Signs.** Sign text keeps clear of the posts and edges on every board (it used to fill the
  whole board, so the posts covered the first and last letters), and the tight boards are wider.

## Why

- Riding and controlling animals is coming, and a ride needs somewhere to go: the passes give
  the world a real journey between the hub and home.
- Closer ranches keep that journey short enough to walk.

## Costs and limits

- Other players can now walk into a ranch. Only its owner can use its upgrade pads; nothing else
  is protected, because nothing else there can be used yet.
- About 14,800 parts in the world with one ranch fully upgraded (the mountains are about 6,000
  of them). Fine on a computer; not checked on phones.
- The pass floors are parts laid over the terrain, so there is a faint line where they meet it.
- Not walked end to end by a player in this session: checked by rays (no invisible wall crosses
  any road, both canyon sides are walled, the ground is unbroken with no step over 2.5 studs).
