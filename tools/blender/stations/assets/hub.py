"""The hub's centre as game models (decision 0095): the watering hole of scenes/watering_hole.py.

Each piece is built where it stands on the plaza (the plaza's middle is the origin, the lawn z = 0.05,
north +Y) and exported uncentred, so the game stands every one of them on the plaza's middle
(World.luau `CENTRE`). A piece is one painted `body` and a Neon piece for each colour that glows. Not in
the models: the statue of the month's rainbow animal, the Hall of Fame's animals and the visitors, which
the game makes from the creature models it already has, and the notice board's writing.
"""

import importlib.util
import os
import random

import stage as S

_spec = importlib.util.spec_from_file_location("scene_watering_hole", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "watering_hole.py"))
W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(W)

NOTES = {
    "hub_ground": "The lawn, the ring path of cobbles, the four roads in, the stone kerb.",
    "hub_pond": "The watering hole: water in a sandy rim, stones, lily pads, reeds, the acacia, and the rock the month's rainbow statue stands on.",
    "hub_trading": "The Trading Post: a striped stall with two stools at its counter.",
    "hub_gifts": "The Gift Stand: a striped stall with a prize wheel on its back wall and gift boxes.",
    "hub_fame": "The Hall of Fame: four marble pedestals under an arch.",
    "hub_board": "The notice board: a roofed board the game writes on.",
    "hub_camp": "The campfire where players arrive: a stone ring, flames, four logs, lanterns.",
    "hub_lights": "Lamps round the ring path with strings of flags, flowers on the lawn.",
}


def piece(name, maker):
    asset = dict(name=name, budget=20000, joints={}, glow={}, finalize={"center": False, "ao_floor": 0.7}, notes=NOTES[name])

    def build():
        rng = random.Random(7)
        maker(rng)
        return S.sort_pieces(rng, asset)

    asset["build"] = build
    return asset


ASSETS = [piece(name, maker) for name, maker in W.MAKERS]
