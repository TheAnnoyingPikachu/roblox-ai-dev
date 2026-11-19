"""The Giraffe (a concept, decision 0076), in the faceted low-poly style of the lions, elephants, jackals
and cheetahs: a sloping body high at the shoulders, very long legs with dark hooves, a long neck with a
dark bristling mane, a long head with a heavy brow and two sharp dark-tipped horns (ossicones). A cream
coat under a net of big chestnut patches. Dangerous, not cute (decision 0033): giraffes fight by
swinging their heads like clubs.

Jointed like every creature: body, head (with the neck, horns and ears), four legs, tail. Facing
Blender -Y; left is +X.
"""

import math
import random

import facet as F
import kit as k
from mathutils import Matrix, Vector

loft, yring, zring, quad, shard, plate, tone, rough = F.loft, F.yring, F.zring, F.quad, F.shard, F.plate, F.tone, F.rough

HIND = 1.3  # how far behind the front legs the hind legs stand
FADE = 2.6  # the hide darkens below this height
NECK = ((3.35, -0.5, 0.33, 0.44), (4.3, -0.98, 0.25, 0.32), (5.4, -1.38, 0.21, 0.25), (6.55, -1.66, 0.18, 0.2))  # (z, y, half width, half depth)


def giraffe_model(p, seed):
    """The giraffe from a palette `p`. Returns (groups, joints)."""
    rng = random.Random(seed)
    T = lambda key: tone(p[key])  # noqa: E731
    coat, legs, dark, patch = T("coat"), T("legs"), T("dark"), T("patch")
    glow = k.glow(p["glow"]) if p.get("glow") else None
    groups = {"body": [], "head": [], "tail": [], "head_glow": [], "body_glow": []}

    def hide(ob, tones, bulge=0.012):
        return rough(ob, tones, rng, bulge, FADE)

    def patches(target, into, centres, direction, size=0.24):
        """Chestnut patches on `target`, each a rough polygon, with a thin line of coat between them."""
        for c in centres:
            try:
                at, n = k.land(target, c, direction)
            except ValueError:
                continue  # the ray misses the piece here
            r, turn = size * p.get("patch_scale", 1.0) * rng.uniform(0.85, 1.1), rng.uniform(0, math.tau)
            sides = 8 if p.get("gentle") else 6
            lo = 0.85 if p.get("gentle") else 0.8
            outline = [(r * rng.uniform(lo, 1.0) * math.cos(turn + i * math.tau / sides), r * rng.uniform(lo, 1.0) * math.sin(turn + i * math.tau / sides)) for i in range(sides)]
            into.append(plate("patch", at, k._frame(n), outline, p.get("patch_thick", 0.012), patch, rng, lift=0.016, surface=p.get("patch_surface")))

    # the torso: deep at the chest, sloping down to narrow hips
    torso = hide(loft("torso", [yring(*r) for r in ((-0.95, 3.4, 0.32, 0.32, 0.38, 0.11), (-0.6, 3.46, 0.48, 0.6, 0.64, 0.17), (0.35, 3.22, 0.46, 0.46, 0.56, 0.16), (1.3, 3.02, 0.42, 0.4, 0.44, 0.14), (1.72, 2.98, 0.26, 0.28, 0.28, 0.09))], coat, rng, surface=p.get("hide")), coat)
    groups["body"].append(torso)
    for s in (1, -1):
        flank = [(0, -0.82 + i * 0.4 + (row % 2) * 0.2, 2.82 + row * 0.36 - i * 0.04) for row in range(4) for i in range(7)]
        patches(torso, groups["body"], flank, (s, 0, 0.05), 0.245)
        patches(torso, groups["body"], [(s * 0.17, -0.55 + i * 0.4, 3.6) for i in range(6)], (s * 0.5, 0, 0.87), 0.22)

    # legs: very long, the lower half pale, dark hooves; the upper half carries patches
    for s in (1, -1):
        x, side = s * 0.3, "l" if s > 0 else "r"
        arm = hide(loft("arm", [zring(x, -0.45, 3.1, 0.17, 0.26, 0.06), zring(x, -0.45, 1.7, 0.12, 0.15, 0.04)], coat, rng, surface=p.get("hide")), coat)
        shank = hide(loft("shank", [zring(x, -0.45, 1.75, 0.11, 0.13, 0.035), zring(x, -0.47, 0.22, 0.1, 0.12, 0.035)], legs, rng, surface=p.get("hide")), legs)
        thigh = hide(loft("thigh", [zring(x, HIND, 3.0, 0.2, 0.36, 0.07), zring(x, HIND - 0.05, 2.3, 0.17, 0.3, 0.06), zring(x, HIND + 0.05, 1.65, 0.12, 0.16, 0.04)], coat, rng, surface=p.get("hide")), coat)
        shin = hide(loft("shin", [zring(x, HIND + 0.05, 1.7, 0.11, 0.14, 0.035), zring(x, HIND, 0.22, 0.1, 0.12, 0.035)], legs, rng, surface=p.get("hide")), legs)
        groups["leg_f" + side] = [arm, shank]
        groups["leg_b" + side] = [thigh, shin]
        for name, y, limb in (("leg_f", -0.47, arm), ("leg_b", HIND, thigh)):
            groups[name + side].append(loft("hoof", [zring(x, y - 0.03, 0.24, 0.12, 0.15, 0.04), zring(x, y - 0.07, 0.0, 0.15, 0.2, 0.05)], dark, rng))
            groups[name + side].append(loft("knee", [zring(x, y, z, 0.125, 0.15, 0.04) for z in (0.98, 0.9)], T("legs_dark"), rng))
            top = 2.85 if name == "leg_f" else 2.7
            patches(limb, groups[name + side], [(0, y + 0.02, top - j * 0.42) for j in range(3)], (s, 0, 0), 0.15)

    # the neck: long, leaning forward, a mane of dark bristles down its back
    head = groups["head"]
    neck = hide(loft("neck", [zring(0, y, z, w, d, d * 0.35) for z, y, w, d in NECK], coat, rng, surface=p.get("hide")), coat)
    head.append(neck)
    for s in (1, -1):
        for j in range(9):
            z = 3.55 + j * 0.34
            y = -0.6 - (z - 3.35) * 0.36
            patches(neck, head, [(0, y + (0.1 if j % 2 else -0.08), z)], (s, 0, 0), 0.2)
    for i in range(16):
        t = i / 15
        z = 3.75 + t * 2.75
        y = -0.6 - t * 1.05
        try:
            at, _ = k.land(neck, (0, y, z), (0, 1, 0.15))
        except ValueError:
            continue
        lean = Vector((0, 0.85, 0.5)).normalized()
        tip = at + lean * (0.2 + 0.05 * math.sin(i * 1.7)) * (1.6 if glow else 1.0)
        if p.get("gentle"):  # a short soft mane
            head.append(F.lump(at + lean * 0.04, (0.06, 0.1, 0.08), T("mane"), rng, surface="fur"))
        elif glow:  # a crest of glowing crystal
            groups["head_glow"].append(shard(at - lean * 0.08, tip, 0.2, 0.1, None, rng, face=(1, 0, 0), at=0.35, m=glow, name="mane"))
        else:
            head.append(shard(at - lean * 0.08, tip, 0.18, 0.08, dark, rng, face=(1, 0, 0), at=0.35, name="mane"))

    # the head: long, a heavy brow, a dark muzzle
    first, glow_first = len(head), len(groups["head_glow"])
    skull = hide(loft("skull", [yring(*r) for r in ((-1.5, 6.82, 0.17, 0.17, 0.16, 0.06), (-1.75, 6.84, 0.24, 0.22, 0.22, 0.08), (-2.1, 6.74, 0.2, 0.17, 0.2, 0.07), (-2.42, 6.6, 0.16, 0.13, 0.17, 0.06))], coat, rng, surface=p.get("hide")), coat, 0.008)
    head.append(skull)
    head.append(loft("muzzle", [yring(-2.4, 6.6, 0.165, 0.135, 0.175, 0.06), yring(-2.66, 6.53, 0.13, 0.1, 0.14, 0.05)], T("muzzle"), rng))
    head.append(shard((0, -1.95, 6.98), (0, -2.35, 6.82), 0.16, 0.06, coat, rng, face=(0, -0.3, 1), name="ridge"))  # the bump down its face
    for s in (1, -1):
        # horns: sharp, leaning back, bare dark tips (a fighter's, worn bald)
        base = Vector((s * 0.11, -1.62, 6.95))
        head.append(loft("horn", [zring(base.x, base.y, base.z, 0.065, 0.07, 0.02), zring(base.x + s * 0.02, base.y + 0.1, base.z + 0.42, 0.05, 0.055, 0.015)], coat, rng))
        if p.get("gentle"):  # a soft round tuft on each (a glowing gem on the diamond one's)
            tuft = base + Vector((s * 0.025, 0.11, 0.47))
            if glow:
                groups["head_glow"].append(F.lump(tuft, (0.09, 0.09, 0.1), None, rng, m=glow))
            else:
                head.append(F.lump(tuft, (0.085, 0.085, 0.08), T("mane"), rng, surface="fur"))
        elif glow:  # a diamond on each horn
            groups["head_glow"].append(shard(base + Vector((s * 0.02, 0.06, 0.3)), base + Vector((s * 0.06, 0.22, 0.95)), 0.2, 0.18, None, rng, at=0.3, m=glow, name="horn_tip"))
        else:
            head.append(shard(base + Vector((s * 0.02, 0.08, 0.36)), base + Vector((s * 0.04, 0.18, 0.72)), 0.13, 0.12, dark, rng, at=0.25, name="horn_tip"))
        # ears: long, flat, sticking out sideways and a little down
        fx, fy, fz = k._frame(Vector((0, -1, 0.3)), (s, 0, 0.2))
        ear = [(-0.06, 0.0), (0.06, 0.0), (0.08, 0.16), (0.0, 0.34), (-0.08, 0.16)]
        at = Vector((s * 0.2, -1.55, 6.88))
        frame = (Vector((0, 1, 0)), Vector((s, 0, -0.25)).normalized(), Vector((0, 0, 1)))
        head.append(plate("ear", at, frame, ear, 0.05, coat, rng))
        head.append(plate("ear", at + Vector((0, 0, 0.05)), frame, [(u * 0.6, 0.03 + v * 0.75) for u, v in ear], 0.015, T("ear_in"), rng))
        # a heavy brow over a narrow amber eye
        if not p.get("gentle"):
            head.append(shard((s * 0.06, -2.0, 6.97), (s * 0.27, -1.78, 7.0), 0.15, 0.1, coat, rng, face=(0, -1, 0.5), name="brow"))
        eye, n = k.land(skull, (s * 0.2, -1.9, 6.88), (s * 0.8, -0.45, 0.2))
        ex, ey, ez = k._frame(n)
        slit = [(-0.07, -0.03), (0.01, 0.04), (0.1, 0.035), (0.03, -0.025)]
        if p.get("gentle"):
            ring = lambda r, n_=10: [(r * math.cos(i * math.tau / n_), r * 1.1 * math.sin(i * math.tau / n_)) for i in range(n_)]  # noqa: E731
            head.append(plate("eye", eye, (ex * s, ey, ez), ring(0.097), 0.016, tone((250, 248, 240), F.PALE), rng, lift=0.008))
            head.append(plate("iris", eye, (ex * s, ey, ez), ring(0.074), 0.01, tone(p["iris"], F.WARM), rng, lift=0.024))
            head.append(plate("pupil", eye, (ex * s, ey, ez), ring(0.046), 0.008, tone(F.INK), rng, lift=0.034))
            head.append(plate("shine", eye + (ex * s) * -0.027 + ey * 0.034, (ex * s, ey, ez), ring(0.018, 6), 0.006, tone((255, 255, 255), F.PALE), rng, lift=0.042))
            cheek, cn = k.land(skull, (s * 0.12, -2.22, 6.66), (s, -0.2, 0))  # a little blush
            head.append(plate("blush", cheek, k._frame(cn), ring(0.06, 8), 0.006, tone((250, 160, 160), F.PALE), rng, lift=0.006))
            for j in range(3):  # lashes over the eye
                root = eye + ey * 0.1 + (ex * s) * (0.04 * (j - 1))
                head.append(shard(root, root + (ey * 0.9 + (ex * s) * (0.35 * (j - 1)) + ez * 0.3).normalized() * 0.07, 0.025, 0.012, tone(F.INK), rng, face=tuple(ez), name="lash"))
        elif glow:
            groups["head_glow"].append(plate("eye", eye, (ex * s, ey, ez), slit, 0.022, None, rng, lift=0.011, m=glow))
        else:
            head.append(plate("eye", eye, (ex * s, ey, ez), slit, 0.018, tone(p["iris"], F.WARM), rng, lift=0.011))
            head.append(plate("pupil", eye, (ex * s, ey, ez), [(0.0, -0.02), (0.024, 0.0), (0.02, 0.028), (-0.003, 0.01)], 0.009, tone(F.INK), rng, lift=0.03))
        head.append(plate("nostril", Vector((s * 0.07, -2.665, 6.6)), (Vector((s, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))), [(-0.03, -0.02), (0.03, -0.02), (0.02, 0.03), (-0.02, 0.03)], 0.01, tone(F.INK), rng))
        patches(skull, head, [(0, -1.72, 6.85)], (s, 0, 0.3), 0.1)

    top = Vector((0, -1.62, 6.62))
    grow = Matrix.Translation(top) @ Matrix.Scale(1.4, 4) @ Matrix.Translation(-top)
    for ob in head[first:] + groups["head_glow"][glow_first:]:
        ob.data.transform(grow)

    # the tail: thin and long, a heavy dark tuft
    t0, end = Vector((0, 1.72, 3.2)), Vector((0, 1.98, 1.6))
    groups["tail"].append(F.colour(k.tube([t0, Vector((0, 1.92, 2.6)), end], [0.06, 0.05, 0.04], m=F.material(), n=4, name="tail"), coat, rng))
    for i in range(4):
        d = Vector(((i - 1.5) * 0.25, 0.12, -1)).normalized()
        groups["tail"].append(shard(end - d * 0.05, end + d * 0.55, 0.18, 0.12, dark, rng, face=(0, 1, 0), at=0.4))

    if p.get("extra"):
        p["extra"](groups, torso, rng, glow)
    joints = {"head": (0, -0.5, 3.45), "leg_fl": (0.3, -0.45, 3.0), "leg_fr": (-0.3, -0.45, 3.0), "leg_bl": (0.3, HIND, 2.9), "leg_br": (-0.3, HIND, 2.9), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def diamond_extra(groups, torso, rng, glow):
    """Diamonds grown out of its shoulders and down its back, and clear crystal hooves' rims."""
    for i, (y, h) in enumerate(((-0.75, 0.7), (-0.5, 1.05), (-0.25, 0.85), (0.1, 0.6), (0.45, 0.5), (0.85, 0.4))):
        at, _ = k.land(torso, (0, y, 3.4), (0, 0, 1))
        for side in (-1, 1) if i < 3 else (0,):
            lean = Vector((side * 0.35, 0.25, 1)).normalized()
            groups["body_glow"].append(shard(at - lean * 0.1 + Vector((side * 0.12, 0, 0)), at + lean * h, 0.32, 0.26, None, rng, face=(1, 0, 0), at=0.3, m=glow, name="diamond"))


def ore_extra(groups, torso, rng, glow):
    """Diamond ore: cyan diamonds set all over the stone (most of them painted gem, some glowing),
    breaking out of the back, the flanks, the neck and the legs, and a cluster on each shoulder."""
    gem, ice = tone((70, 200, 245), F.COOL), tone((150, 232, 255), F.COOL)
    neck = next(ob for ob in groups["head"] if ob.name.startswith("neck"))

    def crystal(target, into, centre, direction, size):
        try:
            at, n = k.land(target, centre, direction)
        except ValueError:
            return
        lean = (n + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, 0.5)))).normalized()
        if rng.random() < 0.3:
            groups["body_glow" if into is not groups["head"] else "head_glow"].append(shard(at - lean * 0.05, at + lean * size, size * 0.5, size * 0.4, None, rng, face=(1, 0, 0), at=0.3, m=glow, name="diamond"))
        else:
            into.append(shard(at - lean * 0.05, at + lean * size, size * 0.55, size * 0.42, (gem, ice), rng, face=(1, 0, 0), at=0.3, name="diamond", surface="gem"))

    for _ in range(34):  # over the body
        y, z = rng.uniform(-0.9, 1.6), rng.uniform(2.75, 3.95)
        crystal(torso, groups["body"], (0, y, z), (rng.choice((-1, 1)), 0, rng.uniform(-0.2, 0.8)), rng.uniform(0.26, 0.55))
    for _ in range(16):  # up the neck
        t = rng.random()
        crystal(neck, groups["head"], (0, -0.55 - t * 1.05, 3.6 + t * 2.7), (rng.choice((-1, 1)), rng.uniform(-0.2, 0.6), 0.1), rng.uniform(0.2, 0.38))
    for leg in ("leg_fl", "leg_fr", "leg_bl", "leg_br"):  # and down each leg
        side = 1 if leg.endswith("l") else -1
        limb = groups[leg][0]
        y = -0.45 if leg.startswith("leg_f") else HIND
        for _ in range(4):
            crystal(limb, groups[leg], (0, y, rng.uniform(1.9, 2.9)), (side, rng.uniform(-0.3, 0.3), 0), rng.uniform(0.16, 0.3))
    diamond_extra(groups, torso, rng, glow)


def giraffe():
    """Giraffe: tall and cream under a net of chestnut patches, a dark mane, sharp dark-tipped horns."""
    return giraffe_model(
        dict(coat=(238, 212, 164), legs=(244, 228, 196), legs_dark=(214, 190, 150), dark=(54, 36, 28), patch=(150, 76, 36), muzzle=(120, 88, 66), ear_in=(214, 160, 130), iris=(240, 170, 40)),
        5,
    )


def diamond_giraffe():
    """Diamond Giraffe (decision 0083): diamond ore: grey stone all over set with diamonds, chips and
    crystals breaking out of the body, neck and legs, glowing diamond horns, crest and eyes."""
    return giraffe_model(ORE, 11)


DIAMOND = (90, 215, 255)


def gentle(**look):
    """A gentle giraffe (decision 0082): round eyes with lashes, soft tufts on its horns, a short soft mane."""
    base = dict(legs_dark=(226, 196, 150), dark=(92, 62, 44), muzzle=(196, 160, 128), ear_in=(240, 180, 160), iris=(110, 70, 40), gentle=True)
    return lambda: giraffe_model({**base, **look}, 5)


SUNNY = gentle(coat=(246, 204, 120), legs=(252, 230, 184), patch=(206, 112, 48), mane=(176, 96, 44))
SAVANNA = gentle(coat=(242, 226, 192), legs=(250, 240, 220), patch=(124, 72, 42), mane=(110, 66, 40))
GEM = gentle(coat=(196, 210, 236), legs=(222, 230, 246), legs_dark=(170, 184, 214), dark=(96, 110, 150), patch=(110, 200, 248), muzzle=(176, 186, 210),
             ear_in=(190, 220, 248), iris=(60, 120, 200), mane=(140, 170, 220), patch_surface="gem", patch_thick=0.04, glow=DIAMOND)

ORE = dict(coat=(118, 120, 130), legs=(98, 100, 110), legs_dark=(70, 72, 82), dark=(48, 50, 60), patch=(96, 214, 250), muzzle=(84, 86, 98), ear_in=(110, 180, 220),
           iris=(240, 170, 40), hide="rock", patch_surface="gem", patch_thick=0.07, patch_scale=0.55, glow=DIAMOND, extra=ore_extra)

ASSETS = [
    F.asset("concept_giraffe_sunny", SUNNY, 2.9, {}, "Giraffe concept (decision 0082): golden, warm orange patches, round eyes, soft horn tufts."),
    F.asset("concept_giraffe_savanna", SAVANNA, 2.9, {}, "Giraffe concept (decision 0082): cream, dark chocolate patches, round eyes, soft horn tufts."),
    F.asset("concept_giraffe_gem", GEM, 2.9, {"head_glow": DIAMOND}, "Diamond Giraffe concept (decision 0082): pale blue, gem patches, glowing gems on its horn tips."),
    F.asset("creature_giraffe", giraffe, 2.9, {}, "Giraffe: a faceted cream giraffe under chestnut patches, a dark mane and sharp horns."),
    F.asset("creature_giraffe_diamond", diamond_giraffe, 2.9, {"head_glow": DIAMOND, "body_glow": DIAMOND}, "Diamond Giraffe: diamond ore, grey stone set with diamonds all over, glowing diamond horns, crest and eyes (decision 0083)."),
]
