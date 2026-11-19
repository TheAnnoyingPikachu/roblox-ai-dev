"""The team's pen (concept, decision 0080): the meadow in the middle of the homestead, as it is now, but
fenced round as a pen that only the player's team of three is in. A rail fence follows the edge of the
meadow, inside the ring path; its one gate faces the road in from the hub, under a "YOUR TEAM" board.
The rest of the herd is not shown on the homestead; the Titan sleeps in its den.

The homestead of scenes/homestead.py with its `TEAM` switch set: its card and models are unchanged.
Concept only: nothing here is in the game.
"""

import importlib.util
import math
import os

from stage import actor, box, flowers, lantern, post, words

_spec = importlib.util.spec_from_file_location("scene_homestead_team", os.path.join(os.path.dirname(os.path.abspath(__file__)), "homestead.py"))
HS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(HS)
S = HS.S

FENCE = HS.MEADOW - 1.0  # the fence's radius, inside the meadow's edge
GATE = 270  # the gate's angle in the plan: towards the hub's road
GAP = 10  # degrees either side of the gate left open
RAIL = (236, 226, 204)
STEP = 8  # degrees between posts


def team(rng):
    """The pen round the meadow, its gate, and the team of three in it."""
    angles = [a for a in range(0, 360, STEP) if abs((a - GATE + 180) % 360 - 180) >= GAP]
    for a in angles:
        p = HS.plan(FENCE, a)
        post(0.35, 4.4, (p.x, p.y, 0.15), S.WOOD_DARK, rng, n=6)
        b = a + STEP
        if abs((b - GATE + 180) % 360 - 180) < GAP:
            continue  # no rail across the gate
        q = HS.plan(FENCE, b)
        mid, yaw = (p + q) / 2, math.degrees(math.atan2(q.y - p.y, q.x - p.x))
        for z in (1.7, 3.4):
            box(((q - p).length, 0.3, 0.45), (mid.x, mid.y, z), RAIL, rng, yaw=yaw, kind=S.PALE)
    g = HS.plan(FENCE, GATE)  # the gate, on the -Y side: its board reads from the road
    for sx in (-1, 1):
        post(0.6, 9.0, (g.x + sx * 6.2, g.y, 0.15), S.WOOD_DARK, rng, n=6)
        lantern((g.x + sx * 8.4, g.y - 1.4, 0.15), rng, h=5.5)
        flowers((g.x + sx * 9.5, g.y + 1.5, 0.15), rng, n=8, spread=1.8)
    box((14.2, 0.8, 0.8), (g.x, g.y, 9.0), S.WOOD_DARK, rng)
    box((11.4, 0.5, 2.5), (g.x, g.y - 0.4, 6.2), S.WOOD, rng)
    words("YOUR TEAM", (g.x, g.y - 0.72, 7.45), 1.25, S.WHITE, glow=0.5)
    # the team: three, whichever they are (here a Lion, a Lightning Cheetah and a Rhino)
    actor("creature_lion", (-14, 10, 0.2), 150)
    actor("creature_cheetah_lightning", (2, -16, 0.2), 20)
    actor("creature_rhino", (16, -12, 0.2), 230)
    for x, y in ((-15, 1), (-3, -22), (21, -18)):  # a bed of straw for each
        HS.disc(3.2, (x, y, 0.2), 0.15, HS.HAY, rng, n=10)


def build(rng):
    HS.TEAM = team
    HS.build(rng)


_G = HS.plan(FENCE, GATE)
SCENES = [
    dict(
        name="team_pen",
        build=build,
        ground=(104, 164, 78),
        shots=[
            ((-70, -95, 60), (0, 0, 2), 34, S.TOP),  # the pen in the middle, from over the road in
            ((0, -1, 570), (0, 0, 0), 50, S.TOP),  # the plan
            ((0, -70, 40), (0, 0, 2), 34, 0),  # a new ranch
            ((_G.x - 6, _G.y - 26, 8), (0, 0, 4), 30, S.TOP),  # at the gate
        ],
    ),
]
