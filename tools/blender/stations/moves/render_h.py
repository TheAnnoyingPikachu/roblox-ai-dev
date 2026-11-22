"""Each animal's picked spell in the Hot core look (fxkit.HOT), rings closing in on where it casts from as it charges.
blender --background --factory-startup --python render_h.py -- <asset> <out dir> keys|full"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fxkit  # noqa: E402
import magic as M  # noqa: E402
from fxkit import seg  # noqa: E402
from magic import Z  # noqa: E402

fxkit.HOT = True
C = M  # colours
HOT = {  # asset: (its picked spell, where it casts from, the colour its charge rings take)
    "creature_jackal_forge": ("m_pack", "nose", C.AQUA),
    "creature_tortoise_forge": ("m_nova", "back", C.JADE),
    "creature_meerkat_forge": ("m_sunorb", "paws", C.SUN),
    "creature_cheetah_forge": ("m_blades", "paw_r", C.MINT),
    "creature_rhino_forge": ("m_lance", "horn", C.AMBER),
    "creature_flamingo_forge": ("m_darts", "back", C.PINK),
    "creature_lion_forge": ("m_roar", "nose", C.GOLD),
    "creature_giraffe_forge": ("m_lance", "horn", C.LAV),
    "creature_elephant_forge": ("m_orb", "trunk", C.VIOLET),
    "creature_jackal_pharaoh_forge": ("m_anubis", "crown", C.TURQ),
    "creature_jackal_sphinx_forge": ("m_sand", "crown", C.SAND),
    "creature_tortoise_gemshell_forge": ("m_gems", "back", C.AQUA),
    "creature_tortoise_island_forge": ("m_surge", "chest", C.SEA),
    "creature_meerkat_star_forge": ("m_comet", "paw_r", C.STAR),
    "creature_meerkat_storm_forge": ("m_ufo", "paw_r", C.ALIEN),
    "creature_cheetah_lightning_forge": ("m_chain", "tail", C.ELEC),
    "creature_cheetah_thunder_forge": ("m_thunder", "back", C.STORM),
    "creature_rhino_lava_forge": ("m_magma", "horn", C.LAVA),
    "creature_rhino_crystal_forge": ("m_prism", "horn", C.DIAMOND),
    "creature_flamingo_peacock_forge": ("m_fan", "tail", C.GOLD),
    "creature_flamingo_phoenix_forge": ("m_firebird", "back", C.FIRE),
    "creature_lion_sun_forge": ("m_solar", "crown", C.SUN),
    "creature_lion_shadow_forge": ("m_claws", "paws", C.SHADOW),
    "creature_giraffe_acacia_forge": ("m_thorns", "chest", C.LEAF),
    "creature_giraffe_diamond_forge": ("m_prison", "horn", C.DIAMOND),
    "creature_elephant_frost_forge": ("m_tomb", "trunk", C.FROST),
    "creature_elephant_war_forge": ("m_axe", "trunk", C.EMBER),
}

args = sys.argv[sys.argv.index("--") + 1 :]
asset = args[0]
key, src, rgb = HOT[asset]
label, text, keys, flags, draw = M.CONCEPTS[asset][1][key]


def hot(f):
    draw(f)
    p = (f.A["paw_l"] + f.A["paw_r"]) / 2 + Z(0.5 * f.k) if src == "paws" else f.A[src]
    f.kit.converge(p, 2.4 * f.k, rgb, seg(f.t, 0.25, 0.84))


M.CONCEPTS[asset][1]["h_" + key] = (label, text, keys, flags, hot)
sys.argv = sys.argv[: sys.argv.index("--") + 1] + args[:3] + ["h_" + key]
path = os.path.join(HERE, "render_magic.py")
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
