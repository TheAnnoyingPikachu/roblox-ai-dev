"""Hero swords for the run Tool (src/night/Gear.luau), their saya and the legendary Blade Art blades.

Assets:
- katana, kodachi, nodachi: <name> (textured hilt), <name>_blade (Neon, Blade Art colour 1) and
  <name>_glow (hamon, shinogi and yokote lines, Neon, colour 2). Roblox ignores Color on a textured
  MeshPart, so the temper detail is thin geometry on the blade, not a texture.
- <weapon>_saya: textured scabbard, worn on the hip while the sword is held.
- blade_<art>: one blade per legendary art, built at katana size in the katana's frame. The game
  stretches it about the blade root per weapon (width factor across, blade length along), so six
  meshes cover all three weapons instead of eighteen. Below BASE the cross-section matches the hero
  blade, so the habaki hides the joint.

Frame: sword along +z with the tsuka below z = 0, edge toward +Y, spine toward -Y, flats facing +-X.
"""

import bisect
import math
import random

import bmesh
from mathutils import Vector

import kit as k

Z0 = 0.12  # blade root height: top of the upper seppa
HABAKI = 0.34  # habaki top, z
BASE = 0.22  # blade length hidden in the habaki
KATANA_W = 0.32
STEEL = ((220, 225, 235), (140, 150, 165))
SILVER = (188, 192, 202)
IRON = (58, 56, 62)
SHAKUDO = (40, 34, 46)

# width must match SHAPES in src/night/Gear.luau; length = blade + grip + 0.24 as before.
WEAPONS = {
    "katana": dict(
        blade=4.2, grip=1.4, width=0.32, sori=0.2, saki=0.74, r=0.165, tsuba="maru", ito=(30, 34, 78), metal=k.GOLD,
        guard=IRON, rim=k.GOLD, saya=(24, 22, 32), flake=k.GOLD, cord=(66, 84, 190), bands=0, step=0.06,
    ),
    "kodachi": dict(
        blade=2.6, grip=1.0, width=0.28, sori=0.09, saki=0.78, r=0.15, tsuba="aoi", ito=(150, 24, 30), metal=SILVER,
        guard=k.GOLD, rim=SHAKUDO, saya=(176, 34, 26), flake=(120, 20, 18), cord=(26, 22, 30), bands=0, step=0.06,
    ),
    "nodachi": dict(
        blade=6.0, grip=2.0, width=0.38, sori=0.32, saki=0.7, r=0.19, tsuba="mokko", ito=(26, 24, 30), metal=k.GOLD,
        guard=IRON, rim=k.GOLD, saya=(20, 20, 26), flake=(120, 22, 26), cord=(150, 70, 200), bands=3, step=0.095,
    ),
}


def lerp(a, b, t):
    return a + (b - a) * t


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def st(s, ys, w, t, **extra):
    """One horizontal slice of a blade: height s above the root, spine y, width, thickness.
    Optional: back, dzb (spine pushed out and along), dze (edge along), g (groove depth 0-1).
    w = 0 is the single tip vertex."""
    return dict(s=s, ys=ys, w=w, t=t, **extra)


class Blade:
    """Blade as a grid of rings. profile: [(v, half-thickness factor)] from spine (v = 0) to edge
    (v = 1), one side, mirrored for the other. ridge: profile index kept as a crease."""

    def __init__(self, stations, profile, m, ridge=None, yokote=None, flat=False):
        self.st, self.prof, self.m = stations, profile, m
        self.ridge, self.yokote, self.flat = ridge, yokote, flat
        self.ss = [s["s"] for s in stations]
        self.vs = [p[0] for p in profile]

    def _p(self, i, p, side):
        s = self.st[i]
        v, xf = self.prof[p]
        if callable(xf):
            xf = xf(s)
        y, z = s["ys"] + v * s["w"], Z0 + s["s"]
        if p == 0:
            y -= s.get("back", 0)
            z += s.get("dzb", 0)
        if p == len(self.prof) - 1:
            z += s.get("dze", 0)
        return Vector((side * xf * s["t"], y, z))

    def mesh(self):
        bm = bmesh.new()
        n = len(self.prof)
        order = [(p, 1) for p in range(n)] + [(p, -1) for p in range(n - 2, 0, -1)]
        rings = []
        for i, s in enumerate(self.st):
            if s["w"] <= 0:
                rings.append([bm.verts.new(self._p(i, 0, 1))])
            else:
                rings.append([bm.verts.new(self._p(i, p, side)) for p, side in order])
        count = len(order)
        for a, b in zip(rings, rings[1:]):
            for q in range(count):
                r = (q + 1) % count
                bm.faces.new((a[q], a[r], b[0]) if len(b) == 1 else (a[q], a[r], b[r], b[q]))
        bm.faces.new(list(reversed(rings[0])))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if self.flat:
            for e in bm.edges:
                e.smooth = False
        elif self.ridge is not None:
            for a, b in zip(rings, rings[1:]):
                if len(b) == count:
                    for q, (p, _) in enumerate(order):
                        if p == self.ridge:
                            bm.edges.get((a[q], b[q])).smooth = False
            if self.yokote is not None:
                ring = rings[self.yokote]
                for q in range(count):
                    r = (q + 1) % count
                    if order[q][0] >= self.ridge and order[r][0] >= self.ridge:
                        bm.edges.get((ring[q], ring[r])).smooth = False
        return k._obj("blade", bm, self.m)

    def _span(self, s):
        i = max(0, min(bisect.bisect_right(self.ss, s) - 1, len(self.ss) - 2))
        return i, max(0.0, min(1.0, (s - self.ss[i]) / (self.ss[i + 1] - self.ss[i])))

    def w(self, s):
        i, f = self._span(s)
        return lerp(self.st[i]["w"], self.st[i + 1]["w"], f)

    def at(self, s, v, side, lift):
        """Point on the mesh surface at height s and fraction v across, lifted off the face."""
        v = max(0.0, min(1.0, v))
        i, f = self._span(s)
        p = max(0, min(bisect.bisect_right(self.vs, v) - 1, len(self.vs) - 2))
        g = (v - self.vs[p]) / (self.vs[p + 1] - self.vs[p])
        low = self._p(i, p, side).lerp(self._p(i, p + 1, side), g)
        high = self._p(i + 1, p, side).lerp(self._p(i + 1, p + 1, side), g)
        return low.lerp(high, f) + Vector((side * lift, 0, 0))

    def strip(self, pairs, side, lift=0.008):
        """Flat strip on one face; pairs: [((s, v), (s, v))] across the strip, in order."""
        bm = bmesh.new()
        rows = [(bm.verts.new(self.at(*a, side, lift)), bm.verts.new(self.at(*b, side, lift))) for a, b in pairs]
        for (a0, b0), (a1, b1) in zip(rows, rows[1:]):
            bm.faces.new((a0, b0, b1, a1))
        bm.normal_update()
        if sum(f.normal.x for f in bm.faces) * side < 0:
            bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        return k._obj("glow", bm, self.m)

    def line(self, vfn, half, a, b, step=0.06, sides=(1, -1), lift=0.008):
        """Line of half-width `half` studs at v = vfn(s) from s = a to b, on both faces. Also
        samples the mesh's own stations, so the line follows every kink."""
        count = max(2, round((b - a) / step))
        ss = sorted({a + (b - a) * i / count for i in range(count + 1)} | {x for x in self.ss if a < x < b})
        out = []
        for side in sides:
            pairs = []
            for s in ss:
                h = half / max(self.w(s), 0.06)
                pairs.append(((s, vfn(s) - h), (s, vfn(s) + h)))
            out.append(self.strip(pairs, side, lift))
        return out

    def star(self, s, v, size, lift=0.008):
        """Small diamond; v < 0 picks the -x face."""
        side = 1 if v > 0 else -1
        v = abs(v)
        h = size / max(self.w(s), 0.06)
        bm = bmesh.new()
        corners = [(s - size, v), (s, v + h), (s + size, v), (s, v - h)]
        face = bm.faces.new([bm.verts.new(self.at(a, b, side, lift)) for a, b in corners])
        bm.normal_update()
        if face.normal.x * side < 0:
            bmesh.ops.reverse_faces(bm, faces=[face])
        return k._obj("glow", bm, self.m)


# Hero blades --------------------------------------------------------------------------------

KATANA_PROFILE = [(0, 0), (0.05, 0.36), (0.30, 0.5), (0.64, 0.34), (1, 0)]


def hero_stations(w):
    length, w0 = w["blade"] + 0.02, w["width"]
    wf = w0 / KATANA_W
    w1, t0, t1 = w0 * w["saki"], 0.072 * wf, 0.052 * wf
    tip = 1.45 * w1  # kissaki length

    def ys(s):
        return -w0 / 2 - w["sori"] * (s / length) ** 1.7

    body = max(12, round((length - tip) / 0.25))
    out = []
    for i in range(body + 1):
        s = (length - tip) * i / body
        out.append(st(s, ys(s), lerp(w0, w1, s / (length - tip)), lerp(t0, t1, s / (length - tip))))
    for i in range(1, 7):
        t = i / 7
        s = length - tip + tip * t
        out.append(st(s, ys(s), w1 * (1 - t * t), t1 * (1 - t * t) ** 0.6))
    out.append(st(length, ys(length), 0, 0))
    return out, length, tip, body


def hamon(s):
    return 0.73 + 0.055 * math.sin(s * 6.3 + 0.4) + 0.03 * math.sin(s * 14.1 + 1.1)


def hero_blade(w, m):
    stations, length, tip, body = hero_stations(w)
    blade = Blade(stations, KATANA_PROFILE, m, ridge=2, yokote=body)
    wf = w["width"] / KATANA_W
    yokote = length - tip
    glow = blade.line(hamon, 0.02 * wf, BASE, length - 0.25 * tip, step=w["step"])

    def shinogi(s):  # just on the spine side of the crease, so the strip stays on one flat face
        return 0.30 - 0.012 * wf / max(blade.w(s), 0.06)

    glow += blade.line(shinogi, 0.011 * wf, BASE, length - 0.12 * tip, step=0.4)
    for side in (1, -1):
        h = 0.012 * wf
        glow.append(blade.strip([((yokote - h, v), (yokote + h, v)) for v in (0.31, 0.5, 0.7, 0.97)], side))
    return [blade.mesh()], glow


# Hilt ---------------------------------------------------------------------------------------


def oval(rx, ry, n=16):
    return [(rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def polar(fn, n=32, sy=1.0):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = fn(a)
        out.append((r * math.cos(a), r * sy * math.sin(a)))
    return out


def petal(angle, r0, r1, width):
    """Sakura petal cut-out, notched at the outer end."""
    shape = [(0, 0), (0.15, 0.22), (0.4, 0.38), (0.7, 0.42), (0.92, 0.32), (1, 0.12), (0.86, 0), (1, -0.12),
             (0.92, -0.32), (0.7, -0.42), (0.4, -0.38), (0.15, -0.22)]
    c, s = math.cos(angle), math.sin(angle)
    out = []
    for a, b in shape:
        r, t = r0 + a * (r1 - r0), b * width
        out.append((r * c - t * s, r * s + t * c))
    return out


def heart(cx, cy, angle, size, n=10):
    """Inome (boar's eye) cut-out; the point faces `angle`."""
    c, s = math.cos(angle), math.sin(angle)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        y = math.sin(t) ** 3 * size
        x = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16 * size
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def crescent(angle, r, span, depth, n=7):
    """Crescent window: outer arc, then a shallower inner arc back."""
    out = []
    for i in range(n):
        a = angle - span + 2 * span * i / (n - 1)
        out.append((r * math.cos(a), r * math.sin(a)))
    for i in range(n - 2, 0, -1):
        a = angle - span + 2 * span * i / (n - 1)
        q = r - depth * math.sin(math.pi * i / (n - 1))
        out.append((q * math.cos(a), q * math.sin(a)))
    return out


def tsuba(w, iron, rim):
    design = w["tsuba"]
    if design == "maru":  # round, five sakura petals cut through
        outline = oval(0.43, 0.47, 32)
        holes = [petal(math.pi / 2 + i * 2 * math.pi / 5, 0.2, 0.39, 0.24) for i in range(5)]
    elif design == "aoi":  # four heart lobes on the axes, deep notches on the diagonals
        rr = 0.36

        def shape(a):
            c = abs(math.cos(2 * a))
            return rr * (0.68 + 0.32 * c**0.55 + 0.05 * c**12)

        outline = polar(shape, 32)
        holes = [heart(0.24 * math.cos(i * math.pi / 2), 0.24 * math.sin(i * math.pi / 2), i * math.pi / 2, 0.075) for i in range(4)]
    else:  # mokko: big, four broad lobes on the diagonals, shallow notches on the axes
        rr = 0.6

        def shape(a):
            return rr * (0.87 + 0.13 * abs(math.sin(2 * a)) ** 0.55)

        outline = polar(shape, 32, 1.06)
        holes = [crescent(math.pi / 4 + i * math.pi / 2, 0.47, 0.5, 0.11) for i in range(4)]
    out = [k.plate([outline] + holes, 0.076, loc=(0, 0, 0.06), m=iron)]
    pts = [(x, y, 0.06) for x, y in outline]
    out.append(k.tube(pts + [pts[0]], 0.042, m=rim, n=4, cap=False))
    return out


def loft(rings, m, name="loft"):
    """Closed solid through rings of equal length; a one-point ring closes that end."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    for a, b in zip(vs, vs[1:]):
        count = max(len(a), len(b))
        for q in range(count):
            r = (q + 1) % count
            if len(b) == 1:
                bm.faces.new((a[q], a[r], b[0]))
            elif len(a) == 1:
                bm.faces.new((a[0], b[r], b[q]))
            else:
                bm.faces.new((a[q], a[r], b[r], b[q]))
    if len(vs[0]) > 1:
        bm.faces.new(list(reversed(vs[0])))
    if len(vs[-1]) > 1:
        bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return k._obj(name, bm, m)


def habaki(w, m):
    wf = w["width"] / KATANA_W
    w0, t = w["width"], 0.072 * wf / 2
    y0 = -w0 / 2

    def ring(z0, z1, g):
        pts = [(0, y0 - 0.03 - g), (t + 0.03 - g, y0 - 0.005), (t + 0.036 - g, y0 + 0.32 * w0), (t + 0.022 - g, y0 + w0),
               (0, y0 + w0 + 0.03 - g), (-t - 0.022 + g, y0 + w0), (-t - 0.036 + g, y0 + 0.32 * w0), (-t - 0.03 + g, y0 - 0.005)]
        return [(x, y, lerp(z0, z1, (y - y0) / w0)) for x, y in pts]

    return loft([ring(Z0, Z0, 0), ring(0.22, 0.2, -0.004), ring(HABAKI, HABAKI - 0.04, 0.012)], m, "habaki")


def hilt(w):
    grip, r = w["grip"], w["r"]
    a, b = 0.8 * r, r
    metal = k.mat("metal", w["metal"], var=0.14, scale=9)
    ito = k.mat("ito", w["ito"], var=0.3, scale=38, kind="wood")
    same = k.mat("same", (240, 234, 216), var=0.16, scale=70, kind="cells")
    iron = k.mat("guard", w["guard"], var=0.28, scale=14)
    rim = k.mat("rim", w["rim"], var=0.12, scale=9)
    squash = (0.8, 1, 1)
    parts = []
    # Kashira, tsuka core with its slight waist, fuchi.
    kashira = [(0, -grip - 0.1), (0.5 * r, -grip - 0.097), (0.84 * r, -grip - 0.08), (1.04 * r, -grip - 0.05),
               (1.08 * r, -grip - 0.015), (1.05 * r, -grip + 0.035)]
    parts.append(k.lathe(kashira, m=metal, n=14, scale=squash))
    parts.append(k.lathe([(1.0 * r, -grip + 0.02), (0.94 * r, -grip / 2), (1.0 * r, -0.12)], m=same, n=14, scale=squash))
    parts.append(k.lathe([(1.04 * r, -0.14), (1.09 * r, -0.125), (1.09 * r, -0.02), (1.15 * r, -0.008), (1.15 * r, 0)], m=metal, n=14, scale=squash))
    # Seppa either side of the tsuba, tsuba, habaki.
    washer = oval(1.34 * a, 1.42 * b, 14)
    parts.append(k.plate([washer], 0.022, loc=(0, 0, 0.011), m=metal))
    parts.append(k.plate([washer], 0.022, loc=(0, 0, 0.109), m=metal))
    parts += tsuba(w, iron, rim)
    parts.append(habaki(w, metal))

    # Ito: two crossing cords per turn on each flat; the windows between them show the same.
    lo, hi = -grip + 0.05, -0.15
    turns = max(3, round((hi - lo) / 0.2))
    pitch = (hi - lo) / turns
    cord = 0.54 * pitch

    def waist(z):
        return 1 - 0.06 * math.sin(math.pi * (z - lo) / (hi - lo))

    def ribbon(zi, sigma, rising, over):
        def fn(u, v):
            phi = math.radians(-90 + 180 * u) * sigma
            z = zi + pitch * (u if rising else 1 - u) + (v - 0.5) * cord
            lift = 1 + (0.012 + 0.024 * math.sin(math.pi * v) + (0.012 * math.sin(math.pi * u) if over else 0)) / r
            s = lift * waist(z)
            return (sigma * a * s * math.cos(phi), b * s * math.sin(phi), z)

        return k.surface(5, 2, fn, m=ito, name="ito")

    for i in range(turns):
        zi = lo + i * pitch
        for sigma in (1, -1):
            parts.append(ribbon(zi, sigma, True, True))
            parts.append(ribbon(zi, sigma, False, False))
    for i in range(turns + 1):
        z = lo + i * pitch
        for side in (1, -1):
            parts.append(k.sphere(0.05, (0, side * (b * waist(z) + 0.012), z), m=ito, scale=(1.3, 0.6, 0.85), seg=6, rings=2))

    # Menuki: small gold blossoms in the middle windows, one on each flat.
    gold = k.mat("menuki", k.GOLD, var=0.14, scale=20)
    mid = turns // 2
    blossom = polar(lambda t: 0.088 * (0.7 + 0.3 * abs(math.cos(2.5 * t)) ** 0.6), 20)
    for sigma, i in ((1, mid), (-1, mid - 1)):
        z = lo + i * pitch
        x = sigma * (a * waist(z) + 0.03)
        parts.append(k.plate([blossom], 0.024, loc=(x, 0, z), rot=(0, 90, 0), m=gold))
        parts.append(k.sphere(0.03, (x + sigma * 0.012, 0, z), m=metal, scale=(0.6, 1, 1), seg=6, rings=2))
    return parts


def hero(w):
    def build():
        blade, glow = hero_blade(w, k.mat("steel", STEEL[0], kind="flat"))
        return {"": hilt(w), "blade": blade, "glow": glow}

    return build


# Saya ---------------------------------------------------------------------------------------


def saya(w):
    def build():
        _, length, _, _ = hero_stations(w)
        w0, sori = w["width"], w["sori"]
        wf = w0 / KATANA_W
        ax, ay = 0.036 * wf + 0.075, w0 / 2 + 0.065
        end = length + 0.14
        lacquer = k.mat("lacquer", w["saya"], kind="patches", scale=130, rgb2=w["flake"])
        ramp = next(n for n in lacquer.node_tree.nodes if n.type == "VALTORGB")
        ramp.color_ramp.elements[1].position = 0.7
        horn = k.mat("horn", (30, 26, 30), var=0.2, scale=12)
        metal = k.mat("metal", w["metal"], var=0.14, scale=9)
        cord = k.mat("cord", w["cord"], var=0.3, scale=60, kind="wood")
        ink = k.mat("slot", (6, 5, 8), kind="flat")

        def cy(s):
            return -sori * (s / length) ** 1.7 + 0.012

        def ring(s, sc=1.0, n=12):
            f = sc * (1 - 0.1 * s / end)
            return [(ax * f * math.cos(2 * math.pi * i / n), cy(s) + ay * f * math.sin(2 * math.pi * i / n), Z0 + s) for i in range(n)]

        steps = max(10, round(length / 0.42))
        parts = [loft([ring(0.1 + (end - 0.2) * i / steps) for i in range(steps + 1)], lacquer, "saya")]
        parts.append(loft([ring(0, 1.03), ring(0.012, 1.09), ring(0.12, 1.09), ring(0.135, 1.03)], horn, "koiguchi"))
        tip = (0, cy(end), Z0 + end + 0.03)
        parts.append(loft([ring(end - 0.2, 1.03), ring(end - 0.185, 1.08), ring(end - 0.05, 1.08), ring(end - 0.008, 0.82), [tip]], metal, "kojiri"))
        wide = 0.072 * wf * 1.15
        slot = [(xf * wide, -w0 / 2 + v * w0) for v, xf in KATANA_PROFILE]
        slot += [(-xf * wide, -w0 / 2 + v * w0) for v, xf in reversed(KATANA_PROFILE[1:-1])]
        parts.append(k.plate([slot], 0.004, loc=(0, 0, Z0 - 0.002), m=ink))
        for i in range(w["bands"]):
            s = length * (0.42 + 0.17 * i)
            parts.append(loft([ring(s - 0.05, 1.0), ring(s - 0.04, 1.05), ring(s + 0.04, 1.05), ring(s + 0.05, 1.0)], metal, "band"))

        # Kurikata knob on the outer flat (-X, away from the body on the left hip), sageo coiled
        # round the body with two tails that hang toward the spine, which is down when worn.
        sk = 0.5 + 0.06 * length
        kx = ax * (1 - 0.1 * sk / end)
        parts.append(k.box((0.075, 0.09, 0.18), (-kx - 0.03, cy(sk) + 0.3 * ay, Z0 + sk), m=horn, bevel=0.025))
        pitch, turns, each = 0.15, 2.5, 12
        coil = []
        for i in range(int(turns * each) + 1):
            a = 2 * math.pi * i / each
            s = sk + 0.14 + pitch * i / each
            f = 1 - 0.1 * s / end
            coil.append((-(ax * f + 0.028) * math.cos(a), cy(s) + (ay * f + 0.028) * math.sin(a), Z0 + s))
        link = [(-kx - 0.05, cy(sk) + 0.3 * ay, Z0 + sk + 0.06), (-kx - 0.05, cy(sk) + 0.2 * ay, Z0 + sk + 0.1)]
        parts.append(k.tube(link + coil, 0.031, m=cord, n=5))
        ex, ey, ez = coil[-1]
        for side, drop in ((1, 0.42), (-1, 0.34)):
            pts = [(ex, ey, ez), (ex + side * 0.03, ey - 0.06, ez + 0.08), (ex + side * 0.06, ey - 0.13, ez + drop * 0.55), (ex + side * 0.07, ey - 0.16, ez + drop)]
            parts.append(k.tube(pts, [0.031, 0.031, 0.034, 0], m=cord, n=5))
        return parts

    return build


# Legendary blades (katana size, katana frame) -------------------------------------------------

LENGTH = 4.22
ROOT_Y = -KATANA_W / 2
FLAT_PROFILE = [(0, 0), (0.05, 0.38), (0.42, 0.5), (1, 0)]


def base(ys):
    """The stretch inside the habaki, as the hero blade."""
    return [st(0, ys(0), KATANA_W, 0.072), st(BASE, ys(BASE), KATANA_W, 0.072)]


def bipyramid(c, axis, length, radius, m, sides=4):
    axis = Vector(axis).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    c = Vector(c)
    bm = bmesh.new()
    ring = []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        ring.append(bm.verts.new(c + axis * length * 0.3 + (side * math.cos(a) + other * math.sin(a) * 0.7) * radius))
    top = bm.verts.new(c + axis * length)
    low = bm.verts.new(c - axis * length * 0.25)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring[i], ring[j], top))
        bm.faces.new((ring[j], ring[i], low))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for e in bm.edges:
        e.smooth = False
    return k._obj("shard", bm, m)


def inferno():
    m = k.mat("art", (255, 255, 200), kind="flat")

    def ys(s):
        return ROOT_Y - 0.16 * (s / LENGTH) ** 1.7

    def wb(s):
        return KATANA_W + 0.07 * math.sin(math.pi * min(s / 3.3, 1))

    stations = base(ys)
    flames, a, b = 7, 0.34, 3.62
    period = (b - a) / flames
    for i in range(flames):
        s0 = a + i * period
        amp = 0.09 + 0.12 * math.sin(math.pi * (i + 0.5) / flames)
        thick = lerp(0.072, 0.058, s0 / b)
        s1, s2 = s0 + 0.5 * period, s0 + 0.82 * period
        stations.append(st(s0, ys(s0), wb(s0), thick))
        stations.append(st(s1, ys(s1), wb(s1) + 0.42 * amp, thick))
        stations.append(st(s2, ys(s2), wb(s2) + amp, thick, dze=0.17 * period))
    stations.append(st(b, ys(b), wb(b), 0.056))
    for t in (0.22, 0.45, 0.68, 0.86):  # flame-tongue tip curling back
        s = b + (LENGTH - b) * t
        stations.append(st(s, ys(s) - 0.1 * t * t, wb(b) * (1 - t**1.4), 0.056 * (1 - t * t) ** 0.5))
    stations.append(st(LENGTH, ys(LENGTH) - 0.1, 0, 0))
    blade = Blade(stations, FLAT_PROFILE, m, ridge=2)
    glow = blade.line(lambda s: 0.66, 0.024, 0.3, 4.0, step=0.1)
    glow += blade.line(lambda s: 0.41, 0.012, BASE, 4.0, step=0.5)
    return {"blade": [blade.mesh()], "glow": glow}


def lightning():
    m = k.mat("art", (255, 255, 140), kind="flat")
    knots = [(0, 0), (0.34, 0), (1.42, 0.02), (1.62, 0.26), (2.56, 0.17), (2.78, -0.1), (3.5, -0.02), (3.68, 0.17), (LENGTH, 0.1)]

    def ys(s):
        for (s0, y0), (s1, y1) in zip(knots, knots[1:]):
            if s <= s1:
                return ROOT_Y + lerp(y0, y1, (s - s0) / (s1 - s0))
        return ROOT_Y + knots[-1][1]

    stations = base(ys)
    # The bolt's kinks plus sharp notches on the edge that bite toward the root.
    marks = [(0.34, 0.33, 0), (0.86, 0.36, 0), (1.12, 0.46, 0.1), (1.16, 0.34, 0), (1.42, 0.36, 0), (1.62, 0.32, 0),
             (1.98, 0.34, 0), (2.26, 0.44, 0.1), (2.3, 0.3, 0), (2.56, 0.3, 0), (2.78, 0.36, 0), (3.1, 0.32, 0),
             (3.3, 0.4, 0.08), (3.34, 0.27, 0), (3.5, 0.26, 0), (3.68, 0.24, 0)]
    for s, w, dz in marks:
        stations.append(st(s, ys(s), w, lerp(0.074, 0.05, s / LENGTH), dze=dz))
    stations.append(st(LENGTH, ys(LENGTH) + 0.05, 0, 0))
    blade = Blade(stations, FLAT_PROFILE, m, ridge=2)

    def bolt(s):
        phase = (s / 0.34) % 2
        return 0.48 + 0.2 * (phase - 0.5 if phase < 1 else 1.5 - phase)

    samples = [BASE + 0.17 * i for i in range(21)]
    glow = []
    for side in (1, -1):
        glow.append(blade.strip([((s, bolt(s) - 0.05), (s, bolt(s) + 0.05)) for s in samples], side))
    return {"blade": [blade.mesh()], "glow": glow}


def void():
    rng = random.Random(7)
    m = k.mat("art", (24, 18, 30), kind="flat")

    def ys(s):
        return ROOT_Y - 0.1 * (s / LENGTH) ** 1.5

    def wb(s):
        return lerp(0.33, 0.36, s / 1.5) if s < 1.5 else lerp(0.36, 0.3, (s - 1.5) / 2.2)

    stations = base(ys)
    s = 0.34
    spike = False
    while s < 3.72:
        t = 0.074 * (1 + rng.uniform(-0.15, 0.2))
        if spike:
            stations.append(st(s, ys(s), wb(s) + rng.uniform(0.07, 0.2), t, dze=rng.uniform(-0.04, 0.09), back=rng.uniform(0, 0.06), dzb=rng.uniform(-0.05, 0.05)))
        else:
            stations.append(st(s, ys(s), wb(s) - rng.uniform(0, 0.05), t))
        spike = not spike
        s += rng.uniform(0.15, 0.27)
    stations += [st(3.84, ys(3.84) - 0.03, 0.26, 0.06), st(4.0, ys(4.0) + 0.04, 0.13, 0.04), st(LENGTH, ys(LENGTH) + 0.02, 0, 0)]
    blade = Blade(stations, [(0, 0), (0.1, 0.42), (0.5, 0.5), (1, 0)], m, flat=True)
    shards = []
    for s, out, axis, size in ((2.15, 0.2, (0.15, 0.5, 1), 0.28), (2.75, 0.3, (-0.2, 0.3, 1), 0.34), (3.25, 0.2, (0.1, 0.6, 1), 0.24),
                               (3.82, 0.34, (-0.1, 0.15, 1), 0.26), (2.5, -0.26, (0.2, -0.5, 1), 0.22), (3.4, -0.22, (-0.2, -0.4, 1), 0.18)):
        y = ys(s) + (wb(s) + 0.14 + out if out > 0 else out)
        shards.append(bipyramid((0.02, y, Z0 + s), axis, size, 0.07 * (0.8 + size), m))
    glow = []
    for side, seed in ((1, 3), (-1, 11)):
        r = random.Random(seed)
        for a, b in ((0.3, 1.5), (1.4, 2.7), (2.6, 3.8)):
            v = r.uniform(0.3, 0.7)
            s, pairs = a, []
            while s <= b:
                h = 0.016 / max(blade.w(s), 0.08)
                pairs.append(((s, v - h), (s, v + h)))
                s += r.uniform(0.1, 0.17)
                v = max(0.14, min(0.86, v + r.choice((-1, 1)) * r.uniform(0.1, 0.24)))
            glow.append(blade.strip(pairs, side))
    return {"blade": [blade.mesh()] + shards, "glow": glow}


def galaxy():
    m = k.mat("art", (40, 0, 90), kind="flat")

    def ys(s):
        return ROOT_Y

    knots = [(0.5, 0.42, 0.13), (1.0, 0.46, 0.14), (1.6, 0.44, 0.135), (2.2, 0.47, 0.14), (2.9, 0.41, 0.125), (3.4, 0.36, 0.11), (3.76, 0.3, 0.09)]
    stations = base(ys) + [st(s, ROOT_Y + (KATANA_W - w) / 2, w, t) for s, w, t in knots]
    stations.append(st(LENGTH, ROOT_Y + KATANA_W / 2, 0, 0))
    blade = Blade(stations, [(0, 0), (0.5, 0.5), (1, 0)], m, flat=True)
    mid = ROOT_Y + KATANA_W / 2
    crystals = []
    for s, y, axis, size, r in ((0.62, 0.24, (0.1, 0.55, 1), 1.0, 0.1), (0.8, -0.23, (-0.1, -0.5, 1), 0.82, 0.09), (1.1, 0.24, (-0.2, 0.42, 1), 0.72, 0.075),
                                (1.3, -0.21, (0.2, -0.36, 1), 0.56, 0.065), (0.72, 0.07, (0.62, 0.15, 1), 0.62, 0.075), (0.84, -0.06, (-0.62, -0.1, 1), 0.56, 0.07)):
        crystals.append(bipyramid((0, mid + y, Z0 + s), axis, size, r, m, sides=5))
    rng = random.Random(21)
    glow = blade.line(lambda s: 0.5, 0.012, BASE, 4.05, step=0.6, lift=0.01)
    for i in range(52):
        s = rng.uniform(0.35, 3.85)
        v = rng.uniform(0.14, 0.86)
        if abs(v - 0.5) < 0.05:
            v += 0.12
        glow.append(blade.star(s, v if i % 2 else -v, rng.choice((0.018, 0.024, 0.024, 0.036)), lift=0.01))
    return {"blade": [blade.mesh()] + crystals, "glow": glow}


def gold():
    m = k.mat("art", (255, 230, 120), kind="flat")

    def ys(s):
        return ROOT_Y - 0.17 * (s / LENGTH) ** 1.7

    def groove(s):
        return lerp(0.5, 0.26, s.get("g", 0))

    tipk = 0.36
    edge = LENGTH - tipk
    stations = base(ys)
    for i in range(1, 15):
        s = BASE + (edge - BASE) * i / 14
        stations.append(st(s, ys(s), lerp(0.36, 0.27, i / 14), lerp(0.078, 0.058, i / 14), g=ease((edge - 0.1 - s) / 0.3)))
    for i in range(1, 6):
        t = i / 6
        s = edge + tipk * t
        stations.append(st(s, ys(s), 0.27 * (1 - t * t), 0.058 * (1 - t * t) ** 0.6))
    stations.append(st(LENGTH, ys(LENGTH), 0, 0))
    profile = [(0, 0), (0.05, 0.36), (0.13, 0.5), (0.16, groove), (0.28, groove), (0.31, 0.5), (0.64, 0.34), (1, 0)]
    blade = Blade(stations, profile, m, ridge=5)

    # Kurikara: a dragon coiled round the lower blade, head on the outer flat looking up it. It
    # lives in the glow part so the darker art colour lifts it off the blade.
    d = k.mat("dragon", (200, 140, 20), kind="flat")
    count = 30
    coil, radii = [], []
    for i in range(count):
        u = i / (count - 1)
        s = 0.38 + 1.2 * u
        phi = -math.pi / 2 + 2.25 * 2 * math.pi * u
        w = blade.w(s)
        coil.append((0.135 * math.cos(phi), ys(s) + w / 2 + (w / 2 + 0.075) * math.sin(phi), Z0 + s))
        radii.append(lerp(0.016, 0.085, ease(u * 1.8)))
    x, y, z = coil[-1]
    head = [(x + 0.012, y, z + 0.09), (x + 0.022, y, z + 0.2), (x + 0.03, y, z + 0.33), (x + 0.03, y, z + 0.46), (x + 0.024, y, z + 0.56)]
    dragon = [k.tube(coil + head, radii + [0.1, 0.116, 0.088, 0.062, 0], m=d, n=6)]
    jaw = [(x + 0.06, y, z + 0.16), (x + 0.1, y, z + 0.28), (x + 0.098, y, z + 0.42)]
    dragon.append(k.tube(jaw, [0.042, 0.032, 0], m=d, n=5))
    for side in (1, -1):
        horn = [(x, y + side * 0.06, z + 0.2), (x - 0.015, y + side * 0.13, z + 0.12), (x - 0.02, y + side * 0.18, z - 0.02)]
        dragon.append(k.tube(horn, [0.042, 0.03, 0], m=d, n=5))
        dragon.append(k.sphere(0.022, (x + 0.075, y + side * 0.06, z + 0.26), m=d, seg=6, rings=2))

    def scroll(s):
        return 0.62 + 0.09 * math.sin(s * 9)

    glow = blade.line(lambda s: 0.22, 0.016, BASE, edge - 0.2, step=0.7, lift=0.006)
    glow += blade.line(scroll, 0.016, 2.25, edge - 0.05, step=0.05)
    for s in (2.5, 3.05, 3.6):
        glow.append(blade.star(s, 0.86, 0.04))
        glow.append(blade.star(s, -0.86, 0.04))
    return {"blade": [blade.mesh()], "glow": glow + dragon}


def shadow():
    m = k.mat("art", (120, 0, 40), kind="flat")

    def ys(s):
        return ROOT_Y - 0.52 * (s / LENGTH) ** 2

    def wb(s):
        return KATANA_W - 0.02 * s if s < 1.1 else lerp(0.298, 0.48, ease((s - 1.1) / 2.3))

    thorns = {1.0: 0.17, 1.55: 0.2, 2.1: 0.23, 2.65: 0.25, 3.2: 0.2}
    marks = {0.36: {}, 0.52: {"w": -0.09}, 0.72: {"w": 0.05, "dze": -0.05}, 0.82: {}}
    for at in thorns:
        for ds in (-0.1, 0, 0.06):
            marks.setdefault(round(at + ds, 3), {})
    for s in (1.3, 1.82, 2.37, 2.92, 3.45):
        marks.setdefault(s, {})
    stations = base(ys)
    for s in sorted(marks):
        extra = dict(marks[s])
        w = wb(s) + extra.pop("w", 0)
        if s in thorns:
            extra.update(back=thorns[s], dzb=-0.14)
        stations.append(st(s, ys(s), w, lerp(0.078, 0.066, s / LENGTH), **extra))
    for t in (0.2, 0.42, 0.62, 0.8, 0.92):  # hooked tip, sweeping back to the spine
        s = 3.5 + (LENGTH - 3.5) * t
        stations.append(st(s, ys(s) - 0.14 * t * t, wb(3.5) * (1 - t**1.25), 0.062 * (1 - t * t) ** 0.5))
    stations.append(st(LENGTH, ys(LENGTH) - 0.15, 0, 0))
    blade = Blade(stations, FLAT_PROFILE, m, ridge=2)

    def vein(s):
        return 0.58 + 0.13 * math.sin(s * 5.3) + 0.05 * math.sin(s * 13.1)

    glow = blade.line(vein, 0.018, 0.3, 3.86, step=0.07)
    for s0 in (1.05, 1.75, 2.45, 3.1):
        v0 = vein(s0)
        for side in (1, -1):
            pairs = []
            for i in range(5):
                u = i / 4
                s = s0 + 0.32 * u
                v = v0 + 0.3 * u + 0.03 * math.sin(u * 7)
                h = lerp(0.016, 0.003, u) / blade.w(s)
                pairs.append(((s, v - h), (s, v + h)))
            glow.append(blade.strip(pairs, side))
    for side in (1, -1):  # demon's eye near the root
        s, v, a, b = 0.62, 0.34, 0.1, 0.16
        rows = [(-a, 0), (-0.5 * a, 0.7 * b), (0, b), (0.5 * a, 0.7 * b), (a, 0)]
        glow.append(blade.strip([((s + d, v - h), (s + d, v + h)) for d, h in rows], side))
    return {"blade": [blade.mesh()], "glow": glow}


# Colours from src/shared/NightProgress.luau (first two of each art), for previews only.
ARTS = {
    "inferno": (inferno, ((255, 255, 200), (255, 120, 0))),
    "lightning": (lightning, ((255, 255, 140), (120, 160, 255))),
    "void": (void, ((0, 0, 0), (90, 0, 140))),
    "galaxy": (galaxy, ((40, 0, 90), (160, 60, 255))),
    "gold": (gold, ((255, 230, 120), (200, 140, 20))),
    "shadow": (shadow, ((120, 0, 40), (20, 0, 30))),
}

GEAR = "src/night/Gear.luau buildTool"
ASSETS = []
for i, (name, w) in enumerate(WEAPONS.items()):
    ASSETS.append(dict(
        name=name, build=hero(w), budget=3000, size=[1, round(w["blade"] + w["grip"] + 0.24, 2), 1], priority=2, order=22 + i * 0.1,
        root=(0, -w["width"] / 2, Z0), tint=STEEL, replaces=f"{name} Tool parts in {GEAR}",
        notes="<name>_blade Neon, Blade Art colour 1; <name>_glow Neon, colour 2 (both untextured: Roblox ignores Color on a textured MeshPart). Trail attachments in code. Pommel at the bottom.",
    ))
    ASSETS.append(dict(
        name=f"{name}_saya", build=saya(w), budget=1500, size=[1, round(w["blade"] + 0.3, 2), 1], priority=2, order=22.5 + i * 0.1,
        replaces="New: scabbard on the left hip while the sword is held (src/night/Gear.luau)",
        notes="Built in the sword's frame: edge toward -Z, mouth at the bottom, kurikata on -X. Gear turns it edge up on the left hip, mouth forward.",
    ))
for i, (art, (fn, tint)) in enumerate(ARTS.items()):
    ASSETS.append(dict(
        name=f"blade_{art}", build=fn, budget=1800, size=[1, 4.2, 1], priority=2, order=22.8 + i * 0.01,
        root=(0, -KATANA_W / 2, Z0), tint=tint, replaces=f"{art} Blade Art: replaces only the blade in {GEAR}",
        notes="Untextured. Katana size: Gear stretches it about `root` per weapon (blade length along, width factor across).",
    ))
