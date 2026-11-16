"""The hub's centre as game models (decision 0064): the gathering place of scenes/hub_commons.py.

Each piece is built where it stands on the plaza (the plaza's middle is the origin, the ground z = 0,
north +Y) and exported uncentred, so the game stands every one of them on the plaza's middle
(World.luau `CENTRE`). A piece is one painted `body` and a Neon piece for each colour that glows. Not
in the models: the eggs on the egg seller's cart and the animals, which the game makes from the models
it already has.
"""

import importlib.util
import os
import random

import stage as S

_spec = importlib.util.spec_from_file_location("scene_hub_commons", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "hub_commons.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)


def piece(name, maker, note):
    asset = dict(name=name, budget=20000, joints={}, glow={}, finalize={"center": False, "ao_floor": 0.7}, notes=note)

    def build():
        C.CAST = False
        rng = random.Random(7)
        maker(rng)
        return S.sort_pieces(rng, asset)

    asset["build"] = build
    return asset


ASSETS = [
    piece("hub_floor", C.floor, "The plaza's floor: warm cobbles in rings, a round of pale flags, a band of brick."),
    piece("hub_fire", C.fire, "The fire pit and the two rows of curved benches round it. Its flames are the glow."),
    piece("hub_market", C.stall_row, "The market: five striped stalls, crates and barrels, the egg seller's cart."),
    piece("hub_cafe", C.cafe, "The cafe: an open hut with a counter and an awning, four tables under parasols."),
    piece("hub_stage", C.stage, "The stage: a roofed platform with a painted back, lamps along its front, three rows of benches."),
    piece("hub_green", C.green, "The green: the meeting tree with its bench, swing and lanterns, a pond with a pier, a trough, picnic tables."),
    piece("hub_lights", C.lights, "Lamps on the kerb, strings of flags from a ring of poles, planters."),
    piece("hub_signs", C.signs, "A finger post at each road, the notice board, the arch over the south walk."),
]
