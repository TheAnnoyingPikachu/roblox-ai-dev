"""Scenery for the whole map (decision 0085, step 2): faceted low-poly trees, pines and bushes that take
the place of the plastic balls and wedges `World.luau` built them from. Each is built round its own
middle on the ground and centred, so the game stands one with `Creatures.still(name, foot, scale)`;
at scale 1 a tree is as tall as `World.kit.tree` at scale 1 (about 16 studs), a pine as `kit.pine` at 1
(about 12), a bush as `kit.bush` at 1 (about 3). One painted `body` each, no joints, no glow.
"""

import random

import stage as S
from stage import lump, post

LEAVES = ((76, 150, 64), (98, 166, 70), (64, 132, 74))
PINES = ((44, 112, 76), (58, 128, 84))
TRUNK = (104, 72, 46)


def round_tree(leaf, seed):
    """A broad tree: a tapering trunk with two boughs, a crown of five faceted clumps."""

    def make(rng):
        s = 1.8
        post(0.6 * s, 4.6 * s, (0, 0, 0), TRUNK, rng, n=6, r2=0.4 * s)
        for dx, dy, dz in ((1.0, 0.3, 3.6), (-0.9, -0.4, 3.9)):  # boughs into the crown
            post(0.22 * s, 1.6 * s, (dx * 0.4 * s, dy * 0.4 * s, dz * s), TRUNK, rng, n=5, rot=(dy * 30, -dx * 30, 0))
        for dx, dy, dz, r in ((0, 0, 6.2, 3.0), (1.7, 0.5, 5.2, 2.1), (-1.5, -0.7, 5.4, 2.2), (0.4, 1.4, 7.4, 1.9), (-0.6, -1.3, 7.2, 1.7)):
            tint = tuple(min(255, c * rng.uniform(0.9, 1.12)) for c in leaf)
            lump((dx * s, dy * s, dz * s), (r * s, r * s, r * s * 0.82), tint, rng)
        return seed

    return make


def tall_tree(leaf, seed):
    """A tall narrow tree: a slim trunk, a crown of clumps stacked up it."""

    def make(rng):
        s = 1.8
        post(0.45 * s, 6.0 * s, (0, 0, 0), TRUNK, rng, n=6, r2=0.3 * s)
        for k, (dz, r) in enumerate(((4.6, 1.9), (6.0, 1.8), (7.3, 1.5), (8.4, 1.1))):
            tint = tuple(min(255, c * rng.uniform(0.92, 1.14)) for c in leaf)
            off = 0.35 * s * (1 if k % 2 else -1)
            lump((off, -off * 0.6, dz * s), (r * s, r * s, r * s * 0.95), tint, rng)
        return seed

    return make


def pine(green, seed, tiers=4):
    """A pine: a short trunk and tiers of faceted cones, each turned a little from the last."""

    def make(rng):
        s = 1.55
        post(0.42 * s, 2.2 * s, (0, 0, 0), TRUNK, rng, n=6)
        for i in range(tiers):
            r = (2.6 - i * 0.55) * s
            tint = tuple(min(255, c * (1 + 0.05 * i)) for c in green)
            post(r, 2.9 * s, (0, 0, (1.5 + i * 1.55) * s), tint, rng, n=7, r2=0.0, rot=(0, 0, rng.uniform(0, 50)))
        return seed

    return make


def bush(leaf, seed):
    """A low bush of four clumps, with a few flowers on it."""

    def make(rng):
        for dx, dy, sz in ((0, 0, 1.0), (0.95, 0.35, 0.78), (-0.8, 0.5, 0.72), (0.2, -0.85, 0.7)):
            tint = tuple(min(255, c * rng.uniform(0.9, 1.1)) for c in leaf)
            lump((dx * 1.3, dy * 1.3, 0.85 * sz * 1.3), (1.25 * sz * 1.3, 1.25 * sz * 1.3, 0.95 * sz * 1.3), tint, rng)
        for _ in range(5):
            x, y = rng.uniform(-1.4, 1.4), rng.uniform(-1.2, 1.2)
            lump((x, y, 2.1), 0.22, ((255, 140, 185), (255, 225, 100), (250, 250, 250))[rng.randrange(3)], rng)
        return seed

    return make


def piece(name, maker, seed, note):
    asset = dict(name=name, budget=6000, joints={}, glow={}, finalize={"ao_floor": 0.7}, notes=note)

    def build():
        rng = random.Random(seed)
        maker(rng)
        return S.sort_pieces(rng, asset)

    asset["build"] = build
    return asset


ASSETS = [
    piece("scenery_tree_1", round_tree(LEAVES[0], 1), 1, "A broad faceted tree, mid green."),
    piece("scenery_tree_2", round_tree(LEAVES[1], 2), 2, "A broad faceted tree, light green."),
    piece("scenery_tree_3", tall_tree(LEAVES[2], 3), 3, "A tall narrow faceted tree, cool green."),
    piece("scenery_pine_1", pine(PINES[0], 4), 4, "A faceted pine, four tiers."),
    piece("scenery_pine_2", pine(PINES[1], 5, tiers=3), 5, "A faceted pine, three tiers."),
    piece("scenery_bush_1", bush(LEAVES[1], 6), 6, "A low faceted bush with a few flowers."),
]
