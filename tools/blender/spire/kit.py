"""Shared Blender helpers for the Neon Spire assets (docs/assets/spire-blender-plan.md).

Reuses the proven Night kit (tools/blender/night/kit.py: materials, primitives, finalize, bake,
preview, contact sheet) with Spire output folders and the Neon Spire palette (art bible 2,
src/spire-client/ClientState.luau 494-505). Conventions as Night: 1 unit = 1 stud, front faces
+Y (exported as Roblox -Z), origin at base centre.

Neon pieces go in a separate `glow` part (mesh `<asset>_glow`, or `_glow2` for a second colour):
the game leaves them untextured and sets them to Neon in the asset's glow colour, so they bloom.
"""

import importlib.util
import math
import os

_spec = importlib.util.spec_from_file_location(
    "nightkit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "night", "kit.py")
)
_night = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_night)

# Re-export the Night primitives and pipeline.
for _name in dir(_night):
    if not _name.startswith("__"):
        globals()[_name] = getattr(_night, _name)

ROOT = _night.ROOT
OUT = os.path.join(ROOT, "build", "blender", "spire")
PREVIEWS = os.path.join(OUT, "previews")
_night.OUT = OUT
_night.PREVIEWS = PREVIEWS

# Palette (sRGB 0-255), art bible 2.
ASPHALT = (11, 15, 26)
STEEL = (28, 35, 51)
GUNMETAL = (52, 60, 78)
CHROME = (120, 132, 150)
SMOG = (42, 27, 61)
CYAN = (0, 240, 255)
MAGENTA = (255, 42, 109)
VIOLET = (123, 47, 255)
AMBER = (255, 184, 0)
LIME = (182, 255, 59)
WHITE = (232, 246, 255)
CORAL = (255, 107, 74)
ICE = (159, 216, 255)
GLASS = (40, 70, 110)
LEAF = (30, 120, 90)


def metal(name="steel", rgb=STEEL, var=0.14, scale=6.0):
    """Wet dark painted metal with a little mottling."""
    return mat(name, rgb, var=var, scale=scale, rough=0.35)


def neon(rgb, name=None, emit=4.0):
    """Bright flat emissive (baked bright; the glow part is Neon in game anyway)."""
    return mat(name or f"neon_{rgb[0]}_{rgb[1]}_{rgb[2]}", rgb, kind="flat", emit=emit)


def strip(a, b, w, m, h=None, name="strip"):
    """Square bar from point a to point b (neon tubes, rails, struts)."""
    a, b = _night.Vector(a), _night.Vector(b)
    d = b - a
    length = d.length
    yaw = math.degrees(math.atan2(-d.x, d.y))
    pitch = math.degrees(math.atan2(d.z, math.hypot(d.x, d.y)))
    return box((w, length, h or w), tuple((a + b) / 2), (pitch, 0, yaw), m=m, name=name)


def rounded(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None, r=0.2):
    """Bevelled box with a soft 2-segment edge: the friendly hard-surface look."""
    return box(size, loc, rot, m=m, bevel=r, seg=2)
