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
    groups = {"body": [], "head": [], "tail": []}

    def hide(ob, tones, bulge=0.012):
        return rough(ob, tones, rng, bulge, FADE)

    def patches(target, into, centres, direction, size=0.24):
        """Chestnut patches on `target`, each a rough polygon, with a thin line of coat between them."""
        for c in centres:
            try:
                at, n = k.land(target, c, direction)
            except ValueError:
                continue  # the ray misses the piece here
            r, turn = size * rng.uniform(0.85, 1.1), rng.uniform(0, math.tau)
            outline = [(r * rng.uniform(0.8, 1.0) * math.cos(turn + i * math.tau / 6), r * rng.uniform(0.8, 1.0) * math.sin(turn + i * math.tau / 6)) for i in range(6)]
            into.append(plate("patch", at, k._frame(n), outline, 0.012, patch, rng, lift=0.016))

    # the torso: deep at the chest, sloping down to narrow hips
    torso = hide(loft("torso", [yring(*r) for r in ((-0.95, 3.4, 0.32, 0.32, 0.38, 0.11), (-0.6, 3.46, 0.48, 0.6, 0.64, 0.17), (0.35, 3.22, 0.46, 0.46, 0.56, 0.16), (1.3, 3.02, 0.42, 0.4, 0.44, 0.14), (1.72, 2.98, 0.26, 0.28, 0.28, 0.09))], coat, rng), coat)
    groups["body"].append(torso)
    for s in (1, -1):
        flank = [(0, -0.82 + i * 0.4 + (row % 2) * 0.2, 2.82 + row * 0.36 - i * 0.04) for row in range(4) for i in range(7)]
        patches(torso, groups["body"], flank, (s, 0, 0.05), 0.245)
        patches(torso, groups["body"], [(s * 0.17, -0.55 + i * 0.4, 3.6) for i in range(6)], (s * 0.5, 0, 0.87), 0.22)

    # legs: very long, the lower half pale, dark hooves; the upper half carries patches
    for s in (1, -1):
        x, side = s * 0.3, "l" if s > 0 else "r"
        arm = hide(loft("arm", [zring(x, -0.45, 3.1, 0.17, 0.26, 0.06), zring(x, -0.45, 1.7, 0.12, 0.15, 0.04)], coat, rng), coat)
        shank = hide(loft("shank", [zring(x, -0.45, 1.75, 0.11, 0.13, 0.035), zring(x, -0.47, 0.22, 0.1, 0.12, 0.035)], legs, rng), legs)
        thigh = hide(loft("thigh", [zring(x, HIND, 3.0, 0.2, 0.36, 0.07), zring(x, HIND - 0.05, 2.3, 0.17, 0.3, 0.06), zring(x, HIND + 0.05, 1.65, 0.12, 0.16, 0.04)], coat, rng), coat)
        shin = hide(loft("shin", [zring(x, HIND + 0.05, 1.7, 0.11, 0.14, 0.035), zring(x, HIND, 0.22, 0.1, 0.12, 0.035)], legs, rng), legs)
        groups["leg_f" + side] = [arm, shank]
        groups["leg_b" + side] = [thigh, shin]
        for name, y, limb in (("leg_f", -0.47, arm), ("leg_b", HIND, thigh)):
            groups[name + side].append(loft("hoof", [zring(x, y - 0.03, 0.24, 0.12, 0.15, 0.04), zring(x, y - 0.07, 0.0, 0.15, 0.2, 0.05)], dark, rng))
            groups[name + side].append(loft("knee", [zring(x, y, z, 0.125, 0.15, 0.04) for z in (0.98, 0.9)], T("legs_dark"), rng))
            top = 2.85 if name == "leg_f" else 2.7
            patches(limb, groups[name + side], [(0, y + 0.02, top - j * 0.42) for j in range(3)], (s, 0, 0), 0.15)

    # the neck: long, leaning forward, a mane of dark bristles down its back
    head = groups["head"]
    neck = hide(loft("neck", [zring(0, y, z, w, d, d * 0.35) for z, y, w, d in NECK], coat, rng), coat)
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
        head.append(shard(at - lean * 0.08, at + lean * (0.2 + 0.05 * math.sin(i * 1.7)), 0.18, 0.08, dark, rng, face=(1, 0, 0), at=0.35, name="mane"))

    # the head: long, a heavy brow, a dark muzzle
    first = len(head)
    skull = hide(loft("skull", [yring(*r) for r in ((-1.5, 6.82, 0.17, 0.17, 0.16, 0.06), (-1.75, 6.84, 0.24, 0.22, 0.22, 0.08), (-2.1, 6.74, 0.2, 0.17, 0.2, 0.07), (-2.42, 6.6, 0.16, 0.13, 0.17, 0.06))], coat, rng), coat, 0.008)
    head.append(skull)
    head.append(loft("muzzle", [yring(-2.4, 6.6, 0.165, 0.135, 0.175, 0.06), yring(-2.66, 6.53, 0.13, 0.1, 0.14, 0.05)], T("muzzle"), rng))
    head.append(shard((0, -1.95, 6.98), (0, -2.35, 6.82), 0.16, 0.06, coat, rng, face=(0, -0.3, 1), name="ridge"))  # the bump down its face
    for s in (1, -1):
        # horns: sharp, leaning back, bare dark tips (a fighter's, worn bald)
        base = Vector((s * 0.11, -1.62, 6.95))
        head.append(loft("horn", [zring(base.x, base.y, base.z, 0.065, 0.07, 0.02), zring(base.x + s * 0.02, base.y + 0.1, base.z + 0.42, 0.05, 0.055, 0.015)], coat, rng))
        head.append(shard(base + Vector((s * 0.02, 0.08, 0.36)), base + Vector((s * 0.04, 0.18, 0.72)), 0.13, 0.12, dark, rng, at=0.25, name="horn_tip"))
        # ears: long, flat, sticking out sideways and a little down
        fx, fy, fz = k._frame(Vector((0, -1, 0.3)), (s, 0, 0.2))
        ear = [(-0.06, 0.0), (0.06, 0.0), (0.08, 0.16), (0.0, 0.34), (-0.08, 0.16)]
        at = Vector((s * 0.2, -1.55, 6.88))
        frame = (Vector((0, 1, 0)), Vector((s, 0, -0.25)).normalized(), Vector((0, 0, 1)))
        head.append(plate("ear", at, frame, ear, 0.05, coat, rng))
        head.append(plate("ear", at + Vector((0, 0, 0.05)), frame, [(u * 0.6, 0.03 + v * 0.75) for u, v in ear], 0.015, T("ear_in"), rng))
        # a heavy brow over a narrow amber eye
        head.append(shard((s * 0.06, -2.0, 6.97), (s * 0.27, -1.78, 7.0), 0.15, 0.1, coat, rng, face=(0, -1, 0.5), name="brow"))
        eye, n = k.land(skull, (s * 0.2, -1.9, 6.88), (s * 0.8, -0.45, 0.2))
        ex, ey, ez = k._frame(n)
        head.append(plate("eye", eye, (ex * s, ey, ez), [(-0.07, -0.03), (0.01, 0.04), (0.1, 0.035), (0.03, -0.025)], 0.018, tone(p["iris"], F.WARM), rng, lift=0.011))
        head.append(plate("pupil", eye, (ex * s, ey, ez), [(0.0, -0.02), (0.024, 0.0), (0.02, 0.028), (-0.003, 0.01)], 0.009, tone(F.INK), rng, lift=0.03))
        head.append(plate("nostril", Vector((s * 0.07, -2.665, 6.6)), (Vector((s, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))), [(-0.03, -0.02), (0.03, -0.02), (0.02, 0.03), (-0.02, 0.03)], 0.01, tone(F.INK), rng))
        patches(skull, head, [(0, -1.72, 6.85)], (s, 0, 0.3), 0.1)

    top = Vector((0, -1.62, 6.62))
    grow = Matrix.Translation(top) @ Matrix.Scale(1.4, 4) @ Matrix.Translation(-top)
    for ob in head[first:]:
        ob.data.transform(grow)

    # the tail: thin and long, a heavy dark tuft
    t0, end = Vector((0, 1.72, 3.2)), Vector((0, 1.98, 1.6))
    groups["tail"].append(F.colour(k.tube([t0, Vector((0, 1.92, 2.6)), end], [0.06, 0.05, 0.04], m=F.material(), n=4, name="tail"), coat, rng))
    for i in range(4):
        d = Vector(((i - 1.5) * 0.25, 0.12, -1)).normalized()
        groups["tail"].append(shard(end - d * 0.05, end + d * 0.55, 0.18, 0.12, dark, rng, face=(0, 1, 0), at=0.4))

    joints = {"head": (0, -0.5, 3.45), "leg_fl": (0.3, -0.45, 3.0), "leg_fr": (-0.3, -0.45, 3.0), "leg_bl": (0.3, HIND, 2.9), "leg_br": (-0.3, HIND, 2.9), "tail": tuple(t0)}
    return {name: parts for name, parts in groups.items() if parts}, joints  # no empty pieces


def giraffe():
    """Giraffe: tall and cream under a net of chestnut patches, a dark mane, sharp dark-tipped horns."""
    return giraffe_model(
        dict(coat=(238, 212, 164), legs=(244, 228, 196), legs_dark=(214, 190, 150), dark=(54, 36, 28), patch=(150, 76, 36), muzzle=(120, 88, 66), ear_in=(214, 160, 130), iris=(240, 170, 40)),
        5,
    )


ASSETS = [
    F.asset("creature_giraffe", giraffe, 2.9, {}, "Giraffe (concept): a faceted cream giraffe under chestnut patches, a dark mane and sharp horns."),
]
