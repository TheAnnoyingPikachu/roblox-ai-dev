"""An animal pen for the ranch (concept, decision 0077): the herd lives in a fenced paddock behind the
Barn instead of in the middle of the homestead, and the meadow becomes a green to sit on.

The homestead of scenes/homestead.py with its `PEN` switched on: the pen stands behind the Barn (142 studs
out at 236 degrees of ValleyMap's plan, where the land now rises: it would be levelled), its front to the
Barn's back, its gate on its left end, where a short lane leaves the Strength Gym's path. It fills with
the Barn's level, as the meadow did: rails and a trough at first, then a shelter and a hay rack, then a
pond, a mud wallow and a shade tree. Concept only: nothing here is in the game.
"""

import importlib.util
import math
import os

from mathutils import Vector
from stage import actor, box, bush, disc, flowers, lantern, lump, post, rock, roof, tree, words

_spec = importlib.util.spec_from_file_location("scene_homestead_pen", os.path.join(os.path.dirname(os.path.abspath(__file__)), "homestead.py"))
HS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(HS)
S = HS.S

AT = (142, 236)  # (r, deg) of the pen's middle, in the plan
W, D = 60, 40  # its width along the ring and its depth outwards
GATE = 4.5  # half the gate's width
RAIL = (236, 226, 204)
GRASS = (128, 188, 90)
MUD = (122, 92, 64)
HAY = HS.HAY


def fence(a, b, rng, gap=None):
    """Posts and two rails from `a` to `b` (on the ground), leaving out the stretch `gap` = (from, to)
    along it."""
    a, b = Vector(a), Vector(b)
    span = (b - a).length
    yaw = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
    n = round(span / 5)
    for i in range(n + 1):
        t = i * span / n
        if gap and gap[0] + 0.5 < t < gap[1] - 0.5:
            continue
        p = a.lerp(b, i / n)
        post(0.32, 4.2, (p.x, p.y, 0.15), S.WOOD_DARK, rng, n=6)
    pieces = [(0, span)] if not gap else [(0, gap[0]), (gap[1], span)]
    for t0, t1 in pieces:
        mid = a.lerp(b, (t0 + t1) / 2 / span)
        for z in (1.6, 3.2):
            box((t1 - t0, 0.3, 0.45), (mid.x, mid.y, z), RAIL, rng, yaw=yaw, kind=S.PALE)


def pen(rng):
    """The pen round its own middle, its front (-Y) to the Barn and the meadow."""
    w, d = W / 2, D / 2
    HS.lv(0)
    box((W - 1, D - 1, 0.1), (0, 0, 0.12), GRASS, rng, chance=0.0)
    disc(6, (-w + 7, 0, 0.18), 0.08, (176, 150, 110), rng, n=10)  # worn in at the gate
    fence((-w, -d), (w, -d), rng)
    fence((w, -d), (w, d), rng)
    fence((w, d), (-w, d), rng)
    fence((-w, d), (-w, -d), rng, gap=(d - GATE, d + GATE))
    for sy in (-1, 1):  # the gate: two tall posts under a beam with its name
        post(0.55, 8.5, (-w, sy * (GATE + 0.6), 0.15), S.WOOD_DARK, rng, n=6)
    box((0.8, GATE * 2 + 3.2, 0.8), (-w, 0, 8.4), S.WOOD_DARK, rng)
    box((0.5, 13.2, 2.3), (-w - 0.3, 0, 5.6), S.WOOD, rng)
    words("ANIMAL PEN", (-w - 0.62, 0, 6.75), 1.2, S.WHITE, yaw=-90, glow=0.5)
    for sy in (-1, 1):  # the gate's two leaves, swung open against the fence
        box((0.25, GATE - 0.4, 3.0), (-w + 2.2, sy * (GATE + 1.6), 0.9), RAIL, rng, yaw=sy * 70, kind=S.PALE)
    box((7, 2.0, 1.5), (2, -d + 5, 0.15), S.WOOD, rng)  # a trough
    box((6.4, 1.4, 0.3), (2, -d + 5, 1.5), (110, 170, 220), rng, chance=0.0)
    for x in (w - 4, w - 7.5):
        box((3.2, 2.2, 1.8), (x, -d + 3, 0.15), HAY, rng, yaw=6)
    actor("creature_jackal", (-8, -6, 0.2), 210)
    actor("creature_meerkat", (-18, -11, 0.2), 150)
    actor("creature_tortoise", (5, -10, 0.2), 20)

    HS.lv(2)
    for sx in (-1, 1):  # an open shelter in the back corner
        for sy in (-1, 1):
            post(0.5, 7.5 if sy > 0 else 6.2, (16 + sx * 9, 13 + sy * 4.5, 0.15), S.WOOD_DARK, rng, n=6)
    box((19.5, 0.5, 6.0), (16, 17.6, 0.15), S.WOOD, rng)  # its back wall
    roof(22, 13, 2.6, (16, 13, 7.2), HS.ROOF_RED, rng, ridge=14)
    box((16, 7, 0.6), (16, 13, 0.15), HAY, rng)
    for x in (-4, 2):  # a hay rack
        post(0.25, 4.0, (x, 15, 0.15), S.WOOD_DARK, rng, n=5)
    box((7.0, 2.4, 1.8), (-1, 15, 2.2), HAY, rng)
    box((7.6, 0.25, 0.3), (-1, 13.8, 4.1), S.WOOD_DARK, rng)
    actor("creature_lion", (4, 2, 0.2), 250)
    actor("creature_flamingo", (-14, 4, 0.2), 80)
    actor("creature_cheetah", (-3, -13, 0.2), 290)

    HS.lv(4)
    disc(6.5, (-17, 11, 0.16), 0.1, S.WATER, rng, n=14, chance=0.0)  # a pond
    for i in range(10):
        a = math.radians(i * 36 + rng.uniform(-8, 8))
        rock((-17 + math.cos(a) * 7, 11 + math.sin(a) * 7, 0.15), rng, s=rng.uniform(0.8, 1.4))
    disc(5.5, (16, -10, 0.16), 0.12, MUD, rng, n=12, chance=0.2)  # a wallow
    tree((24, -2, 0.15), rng, s=1.9)
    lump((-24, -14, 0.9), (1.3, 1.0, 0.8), (236, 230, 236), rng)  # a salt lick
    for x in (-w - 2.4,):
        lantern((x, -GATE - 3, 0.15), rng, h=6)
    actor("creature_rhino", (15, -10, 0.2), 200)
    actor("creature_giraffe", (-1, 10.5, 0.2), 180)  # at the hay rack
    actor("creature_lion_sun", (13, 1, 0.2), 200)
    actor("creature_jackal_pharaoh", (-7, 1, 0.2), 60)
    actor("creature_flamingo_phoenix", (-12, 14, 0.2), 230)
    actor("creature_cheetah_lightning", (9, -16, 0.2), 100)


def world(x, y):
    """A point of the pen's own frame on the card."""
    r, deg = AT
    return HS.plan(r, deg) + Vector((math.sin(math.radians(deg)), math.cos(math.radians(deg)), 0)) * x + HS.plan(1, deg) * y


def lane(rng):
    """The pen, and the lane from the Strength Gym's path to its gate."""
    HS.lv(0)
    HS.place(pen, *AT, rng)
    g = world(-W / 2 - 1, 0)
    u = HS.plan(1, 206)
    on = u * g.dot(u)  # where the lane meets the Strength Gym's path
    mid, span = (g + on) / 2, (g - on).length
    box((span + 4, 7, 0.3), (mid.x, mid.y, 0.03), HS.PATH, rng, yaw=math.degrees(math.atan2(g.y - on.y, g.x - on.x)), kind=S.PALE, chance=0.3)
    for t in (0.3, 0.7):
        p = on.lerp(g, t) + Vector((-(g - on).y, (g - on).x, 0)).normalized() * 5
        bush((p.x, p.y, 0.15), rng, s=1.4)
        flowers((p.x, p.y, 0.15), rng, n=6, spread=2.0)


def build(rng):
    HS.PEN = AT
    HS.EXTRA[:] = [lane]
    HS.build(rng)


_P = world(0, 0)
_G = world(-W / 2 - 1, 0)
_OUT = (_G - _P).normalized()
_EYE = _G + _OUT * 26 + Vector((0, 0, 9))
SCENES = [
    dict(
        name="animal_pen",
        build=build,
        ground=(104, 164, 78),
        shots=[
            ((_P.x - 105, _P.y + 140, 105), (_P.x, _P.y, 2), 30, S.TOP),  # the pen behind the Barn, from over the meadow
            ((0, -1, 570), (0, 0, 0), 50, S.TOP),  # the plan
            ((_P.x - 70, _P.y + 95, 70), (_P.x, _P.y, 2), 30, 0),  # a new ranch
            ((_P.x - 70, _P.y + 95, 70), (_P.x, _P.y, 2), 30, 3),  # half way
            (tuple(_EYE), (_P.x, _P.y, 5), 30, S.TOP),  # at the gate
            ((0, -100, 11), (0, 45, 8), 24, S.TOP),  # the meadow, now a green
        ],
    ),
]
