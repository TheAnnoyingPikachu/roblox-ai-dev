"""The training areas as game models (decision 0065): the six areas of scenes/training.py.

An area grows with the Training Grounds upgrade, so it is not one model but one for each stretch of
levels its pieces stand at: `area_track_2_5` is everything of the Speed Track that arrives at level 2
and stays, `area_track_0_1` what stands only at levels 0 and 1. The game stands every model of an area
whose stretch holds the ranch's level (Areas.luau reads the stretch from the name).

Each is built where it stands in its yard (the yard's middle is the origin, the ground z = 0, the
gateway on -Y) and exported uncentred, like the hub's pieces; one painted `body` and a Neon piece for
each colour that glows. The animals of the concept cards are left out: the game stands its own.
"""

import importlib.util
import os
import random

import bpy
import stage as S

_spec = importlib.util.spec_from_file_location("scene_training", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "training.py"))
T = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(T)

# station id (StationConfig.STATIONS), the area's maker, and the stretches of levels its pieces stand at
AREAS = (
    ("track", "speed", ((0, 0), (0, 1), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5))),
    ("gym", "strength", ((0, 0), (0, 1), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5))),
    ("pool", "stamina", ((0, 0), (0, 1), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5))),
    ("library", "mana", ((0, 0), (0, 1), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5))),
    ("spring", "health", ((0, 0), (0, 1), (1, 5), (2, 3), (2, 5), (3, 5), (4, 5), (5, 5))),
    ("guard", "defence", ((0, 0), (0, 1), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5))),
)


def piece(station, maker, stretches, first, last):
    span = f"level {first}" if first == last else f"levels {first} to {last}"
    asset = dict(name=f"area_{station}_{first}_{last}", budget=20000, joints={}, glow={}, finalize={"center": False, "ao_floor": 0.7}, notes=f"The {station}'s training area: what stands at {span} of the Training Grounds.")

    def build():
        rng = random.Random(7)
        T.area(getattr(T, maker), rng, animals=False)
        found = set()
        for ob in list(bpy.data.objects):
            if ob.type == "MESH":
                found.add((ob["first"], ob["last"]))
                if (ob["first"], ob["last"]) != (first, last):
                    bpy.data.objects.remove(ob)
        if found != set(stretches):  # the scene changed: a stretch with no model would never show in the game
            raise ValueError(f"{station}: its pieces stand at {sorted(found)}, AREAS lists {sorted(stretches)}")
        return S.sort_pieces(rng, asset)

    asset["build"] = build
    return asset


ASSETS = [piece(station, maker, stretches, first, last) for station, maker, stretches in AREAS for first, last in stretches]
