"""render_magic.py with the better-visuals directions added (magicv.py).
blender --background --factory-startup --python render_v.py -- <asset> <out dir> keys|full v1_core,v2_element,v3_arcane"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import magicv  # noqa: E402,F401  (adds the directions to magic.CONCEPTS)

path = os.path.join(HERE, "render_magic.py")
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
