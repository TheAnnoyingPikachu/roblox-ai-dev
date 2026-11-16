"""The hub's centre as game models (decision 0060): the pieces of scenes/hub.py, the approved concept.

Each piece is built where it stands on the plaza (the plaza's middle is the origin, the ground z = 0,
north +Y) and exported uncentred, so the game stands every one of them on the same spot
(World.luau `CENTRE`); a piece that repeats (a plinth, a garden) is built once and turned there.
A piece is one painted `body` and, where it shines, a Neon `body_glow`. Not in the models: the Golden
Egg, the shrines' eggs and the statues, which the game makes from the models it already has.
"""

import importlib.util
import os
import random

import bpy

_spec = importlib.util.spec_from_file_location("scene_hub", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "hub.py"))
H = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(H)
S = H.S

ROAD_HALF = 9.2  # a gateway's piers stand on the edges of the game's roads, which are wider than the concept's


def made(maker, seed=7):
    """A build function: runs `maker(rng)` and sorts what it made into the painted body and the Neon glow."""

    def build():
        rng = random.Random(seed)
        maker(rng)
        groups = {"body": [], "body_glow": []}
        for ob in bpy.data.objects:
            if ob.type != "MESH":
                continue
            kind = ob.data.materials[0].name if ob.data.materials else ""
            if kind.startswith("words_"):  # lettering is painted on: plain white, no glow
                S.paint(ob, S.WHITE, rng, chance=0.0)
            groups["body_glow" if kind.startswith("neon_") else "body"].append(ob)
        if not groups["body_glow"]:
            del groups["body_glow"]
        return groups

    return build


def piece(name, maker, glow=None, note=""):
    return dict(name=name, build=made(maker), budget=20000, joints={}, glow={"body_glow": glow} if glow else {}, finalize={"center": False}, notes=note)


def gate(name, a, text, sign, banner, glow):
    return piece(name, lambda rng: H.gateway(rng, a, text, sign, banner, glow, half=ROAD_HALF, road=False), glow, f"The gateway across a road into the plaza: {text}.")


ASSETS = [
    piece("hub_paving", H.paving, note="The plaza's floor: kerb, three rings of slabs, tiled bands, the mosaic and the sunburst."),
    piece("hub_fountain", lambda rng: H.fountain(rng, cast=False), (150, 220, 255), "The Hatchery Fountain: two pools, the stem and bowl, the lotus. Its falling water is the glow."),
    piece("hub_plinth", lambda rng: H.plinth(rng, 22.5), note="A statue's plinth with its name plate and flowers; the first of eight, 45 degrees apart."),
    *[
        piece(f"hub_shrine_{egg}", lambda rng, q=q, tiles=tiles: H.shrine(rng, S.polar(32.2, q * 90 + 45, 0.3), q * 90 + 45, None, tiles), note=f"The {egg} egg's shrine, where it stands.")
        for q, (egg, tiles) in enumerate(H.EGGS)
    ],
    piece("hub_garden", lambda rng: H.garden(rng, 0), S.LANTERN, "A raised garden with its lamps, flags and benches; the first of four, 90 degrees apart."),
    gate("hub_gate_arena", 90, "WAVE ARENA", (64, 40, 104), (88, 52, 140), (150, 255, 70)),
    gate("hub_gate_welcome", 270, "WELCOME", (60, 120, 200), (70, 140, 220), S.LANTERN),
    gate("hub_gate_ranches", 0, "RANCHES", (70, 140, 80), (90, 170, 90), S.LANTERN),
    piece("hub_stalls", lambda rng: (H.stall(rng, (-13.5, 60, 0), -90, (226, 90, 80)), H.stall(rng, (13.5, 60, 0), 90, (80, 150, 220))), note="The two market stalls beside the arena road."),
]
