"""The homestead's eight buildings as game models (decision 0072): the makers of scenes/homestead.py, each
in its three looks.

A building is built round its own middle on the ground (z = 0), its front towards -Y, and exported
uncentred, so the game stands it on its place round the meadow, front to the middle
(src/stations/Ranch.luau). It is one painted `body` and a Neon piece for each colour that glows
(windows, lamps, flames). Not in the models: the eggs, their nests and racks, the Titan and the
windmill's sails, which the game stands itself (`LIVE` off).
"""

import importlib.util
import os
import random

import stage as S

_spec = importlib.util.spec_from_file_location("scene_homestead", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "homestead.py"))
HS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(HS)

LOOKS = (
    ("house", HS.house, ("The Ranch House: a timber cottage on a fieldstone footing, with a stone chimney and a stoop.", "The Ranch House: a farmhouse, fieldstone below and timber above, two dormers, a porch the length of its front.", "The Ranch House: a great farmhouse with a cross wing, two chimneys, a cupola and a long porch.")),
    ("barn", HS.barn, ("The Barn: a shed with its hay.", "The Barn: a barn with a silo.", "The Barn: a great barn with two silos, a weather vane and a hay cart.")),
    ("hatchery", HS.hatchery, ("The Hatchery: an open shed under a gabled canvas, over a bed of straw.", "The Hatchery: a round pavilion.", "The Hatchery: a great pavilion under a two-tiered roof, with lanterns.")),
    ("cellar", HS.cellar, ("The Egg Cellar: the egg storage greenhouse.", "The Egg Cellar: a cellar dug into a grassy mound, the greenhouse beside it.", "The Egg Cellar: a bigger mound with two doors and a grander greenhouse.")),
    ("brooder", HS.brooder, ("The Brooder: two warm beds under heat lamps and a glass roof.", "The Brooder: four warm beds.", "The Brooder: six warm beds and a boiler.")),
    ("windmill", HS.windmill, ("The Windmill: a post mill, without its sails.", "The Windmill: a stone tower mill, without its sails.", "The Windmill: a tall tower mill with a gallery and a store, without its sails.")),
    ("lodge", HS.lodge, ("The Trophy Lodge: a first cup between two banners.", "The Trophy Lodge: a hall of three cups.", "The Trophy Lodge: a great hall with the great cup in the middle.")),
    ("den", HS.den, ("The Titan's Den: a timber frame in the mouth of a cave in a hill.", "The Titan's Den: a stone gate into a hall dug into a hill.", "The Titan's Den: a great stone gate with tusks, banners and braziers.")),
)


def piece(name, maker, note):
    asset = dict(name=name, budget=20000, joints={}, glow={}, finalize={"center": False, "ao_floor": 0.7}, notes=note)

    def build():
        HS.LIVE = False
        rng = random.Random(7)
        maker(rng)
        return S.sort_pieces(rng, asset)

    asset["build"] = build
    return asset


ASSETS = [piece(f"home_{key}_{t + 1}", maker(t), notes[t]) for key, maker, notes in LOOKS for t in range(3)]
