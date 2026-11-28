"""Shared by the board scripts: poses a quadrig.py rig from plain numbers, measures stretch, renders.
Every angle is about the world's axes (relative to the parent), so a pose reads the same on any animal:
  body  [fwd, up, pitch(nose up +), yaw, roll, side]   the hips and everything on them; feet stay planted
  spine [pitch, yaw, roll]  arch, split over spine and chest
  neck  [pitch, yaw]        split over the neck bones
  head  [pitch, yaw, roll]
  tail  [up, sway, curl]    up and sway spread along the tail; curl grows towards the tip
  fl fr hl hr [side, fwd, up]   each foot's target, from where it stands
  carry [fl, fr, hl, hr]    0..1: how far each foot is carried with the body (a leap, a rear-up) instead of planted
  root  [roll, pivot_x, pivot_z, up, yaw]  the whole animal (a fall onto its side, a spin in the air)
Distances are in the model's units (the cheetah is about 0.96 long)."""
import bpy, math
import numpy as np
from mathutils import Vector, Matrix

FEET = ("fl", "fr", "hl", "hr")


def R(pitch=0.0, yaw=0.0, roll=0.0):
    return Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(-pitch), 3, "X") @ Matrix.Rotation(math.radians(roll), 3, "Y")


class Rig:
    def __init__(self):
        self.arm = bpy.data.objects["rig"]
        self.body = bpy.data.objects["body"]
        self.kit = bpy.data.objects.get("kit")
        if self.arm.animation_data:
            self.arm.animation_data.action = None
        self.P, self.B = self.arm.pose.bones, self.arm.data.bones
        for pb in self.P:
            pb.rotation_mode = "QUATERNION"
        self.hip = self.B["hips"].head_local.copy()
        self.ank = {n: self.B[f"ik_{n}"].head_local.copy() for n in FEET}
        self.tails = sorted([b.name for b in self.B if b.name.startswith("tail")], key=lambda s: int(s[4:]))
        self.necks = sorted([b.name for b in self.B if b.name.startswith("neck")])
        self.floor = self.B["root"].head_local.z
        me = self.body.data
        # how far the body can sink before its belly is on the ground: the underside between the legs, along the middle
        co = np.array([v.co[:] for v in me.vertices])
        y0, y1 = sorted((self.ank["fl"].y, self.ank["hl"].y))
        under = co[(co[:, 1] > y0 + 0.04) & (co[:, 1] < y1 - 0.04) & (np.abs(co[:, 0]) < 0.4 * abs(self.ank["fl"].x))]
        self.clear = float(np.percentile(under[:, 2], 2) - self.floor) if len(under) else 0.1
        self.edges = np.array([e.vertices[:] for e in me.edges])
        eid = {tuple(sorted(e)): i for i, e in enumerate(self.edges.tolist())}
        self.face_edges = [[eid[tuple(sorted(k))] for k in p.edge_keys] for p in me.polygons]
        self.area = np.array([p.area for p in me.polygons])
        self.apply({})
        self.rest_len = self.lengths()

    def setrot(self, name, M3):
        Rr = self.B[name].matrix_local.to_3x3()
        self.P[name].rotation_quaternion = (Rr.inverted() @ M3 @ Rr).to_quaternion()

    def setloc(self, name, v):
        self.P[name].location = self.B[name].matrix_local.to_3x3().inverted() @ Vector(v)

    def ik(self, on):
        for n in FEET:
            for b in (f"lower_{n}", f"foot_{n}"):
                for c in self.P[b].constraints:
                    c.mute = not on

    def apply(self, pose):
        def g(k, n):
            v = list(pose.get(k, []))[:n]
            return v + [0.0] * (n - len(v))
        for pb in self.P:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)  # (a matrix set on a bone leaves a little scale behind: it must not build up)
        rr, px, pz, up, ry = g("root", 5)
        if rr or up or ry:
            M = Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rr), 3, "Y")
            p = Vector((px, 0, pz))
            self.setrot("root", M)
            self.setloc("root", p - M @ p + Vector((0, 0, up)))
        f, u, pi, ya, ro, si = g("body", 6)
        u -= g("drop", 1)[0] * self.clear  # "drop": [1] lays the belly on the ground, whatever the animal's build
        Mb = R(pi, ya, ro)
        self.setrot("hips", Mb)
        self.setloc("hips", (si, -f, u))
        sp, sy, sr = g("spine", 3)
        for b in ("spine", "chest"):
            self.setrot(b, R(sp / 2, sy / 2, sr / 2))
        npi, nya = g("neck", 2)
        for b in self.necks:
            self.setrot(b, R(npi / len(self.necks), nya / len(self.necks)))
        hp, hy, hr = g("head", 3)
        self.setrot("head", R(hp, hy, hr))
        tu, ts, tc = g("tail", 3)
        n = len(self.tails)
        for i, b in enumerate(self.tails):
            k = (i + 1) / n
            self.setrot(b, R(-(tu / n + tc * k * 2 / n), ts / n * (1 + k)))
        carry = g("carry", 4)
        for j, ft in enumerate(FEET):
            s, fw, up_ = g(ft, 3)
            moved = self.hip + Mb @ (self.ank[ft] - self.hip) + Vector((si, -f, u))
            self.setloc(f"ik_{ft}", carry[j] * (moved - self.ank[ft]) + Vector((s, -fw, up_)))
        bpy.context.view_layer.update()
        # planted feet stay planted: when a pose pulls a foot's target out of its leg's reach (a straight-legged
        # animal leaning forward), the hips sink by just enough, as a real animal's would, instead of the foot floating
        if not (rr or ry):
            drop = 0.0
            for j, ft in enumerate(FEET):
                if carry[j] > 0.5:
                    continue
                top, tgt = self.P[f"upper_{ft}"].head, self.P[f"ik_{ft}"].head
                L = self.B[f"upper_{ft}"].length + self.B[f"lower_{ft}"].length
                d = tgt - top
                flat = math.hypot(d.x, d.y)
                if d.length > L * 0.999 and flat < L * 0.97 and d.z < 0:
                    drop = max(drop, -d.z - math.sqrt(L * L - flat * flat))
            if drop > 1e-5:
                self.setloc("hips", (si, -f, u - drop))
                bpy.context.view_layer.update()

    # --- baked clips -------------------------------------------------------------------------------------------------
    def floppy(self):
        """The bones that are not driven but dragged (follow-through): tails, and any ear, banner, crest, mane or wing
        tip bones a species adds. Parents before children."""
        keys = ("tail", "ear", "banner", "crest", "mane", "flop")
        order = []
        def walk(b):
            if b.name.startswith(keys):
                order.append(b.name)
            for c in b.children:
                walk(c)
        walk(self.B["root"])
        return order

    def bake(self, fn, secs, loop, fps=60, spring=(2.6, 0.32), limit=55.0):
        """A clip as it will play: fn(t) posed at every 1/fps, then follow-through simulated on the floppy bones: each
        one's tip is a point on a damped spring (spring = [Hz, damping]) chasing where its keyed pose puts it, so a tail
        lags behind the hips, swings past and settles, and is never stiff. A loop runs once before it is recorded, so it
        comes round to where it began. Returns one {bone: its matrix in the armature} a frame, every bone but the IK
        helpers (their work is in the legs' matrices)."""
        mods = [m for o in (self.body, self.kit) if o for m in o.modifiers if m.type == "ARMATURE"]
        for m in mods:
            m.show_viewport = False  # (nothing reads the skin while the bones are simulated)
        self.ik(True)
        flops = self.floppy()
        w, z = spring[0] * math.tau, spring[1]
        names = [b.name for b in self.B if not b.name.startswith(("ik_", "pole_"))]
        n = max(2, round(secs * fps) + (0 if loop else 1))
        dt = 1.0 / fps
        state, frames = {}, []
        for i in range(-n if loop else 0, n):
            t = (i % n) * dt if loop else i * dt
            self.apply(fn(t))
            for b in flops:
                pb = self.P[b]
                head, tip = pb.head.copy(), pb.tail.copy()
                if b not in state:
                    state[b] = [tip.copy(), Vector((0, 0, 0))]
                q, v = state[b]
                v += (w * w * (tip - q) - 2 * z * w * v) * dt
                q += v * dt
                want, have = q - head, tip - head
                if want.length > 1e-6:
                    rot = have.rotation_difference(want)
                    if rot.angle > math.radians(limit):
                        rot = Matrix.Rotation(math.radians(limit), 3, rot.axis).to_quaternion()
                    turned = rot @ have
                    state[b][0] = head + turned  # (the point stays a bone's length from its joint)
                    m = pb.matrix.copy()
                    m3 = (rot @ m.to_quaternion()).to_matrix()  # (a pure turn: no scale or shear creeps in)
                    new = m3.to_4x4(); new.translation = m.translation
                    pb.matrix = new
                    bpy.context.view_layer.update()
            if i >= 0:
                frames.append({b: self.P[b].matrix.copy() for b in names})
        for m in mods:
            m.show_viewport = True
        return frames

    def show(self, frame):
        """Pose the rig from a baked frame: each bone's own turn worked out from its and its parent's matrices."""
        self.ik(False)
        for b, M in frame.items():
            bone = self.B[b]
            if bone.parent:
                rest = bone.parent.matrix_local.inverted() @ bone.matrix_local
                basis = rest.inverted() @ (frame[bone.parent.name].inverted() @ M)
            else:
                basis = bone.matrix_local.inverted() @ M
            self.P[b].matrix_basis = Matrix.LocRotScale(basis.translation, basis.to_quaternion(), None)
        for b in self.P:
            if b.name.startswith(("ik_", "pole_")):
                b.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()

    def lengths(self):
        ev = self.body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        co = co.reshape(-1, 3)
        return np.linalg.norm(co[self.edges[:, 0]] - co[self.edges[:, 1]], axis=1)

    def stretch(self, split=False):
        """The share of the body's surface whose faces have an edge stretched or squashed by a quarter (skin_forge's
        measure), and which faces. With split: (both, stretched only, squashed only, bad faces)."""
        now = self.lengths()
        ok = self.rest_len > 1e-6
        r = np.ones(len(now))
        r[ok] = np.maximum(now[ok], 1e-9) / self.rest_len[ok]
        lim = 1.25
        long_ = np.array([max(r[i] for i in fe) > lim for fe in self.face_edges])
        short = np.array([min(r[i] for i in fe) < 1 / lim for fe in self.face_edges])
        bad = long_ | short
        tot = self.area.sum()
        pct = lambda m: float(self.area[m].sum() / tot * 100)
        if split:
            return pct(bad), pct(long_), pct(short), long_
        return pct(bad), bad


# How a key's pose is arrived at (timing): a blow accelerates into its impact, a wind-up settles, a recoil goes past
# its pose and comes back.
EASES = {
    "smooth": lambda u: u * u * (3 - 2 * u),
    "linear": lambda u: u,
    "in": lambda u: u ** 3,  # accelerates: lands at full speed (a strike, a stamp)
    "out": lambda u: 1 - (1 - u) ** 3,  # decelerates: settles into a held pose (a wind-up, a recovery)
    "over": lambda u: 1 + 2.70158 * (u - 1) ** 3 + 1.70158 * (u - 1) ** 2,  # 10 % past the pose, then back
}


def ease(u):
    return EASES["smooth"](max(0.0, min(1.0, u)))


def sample(keys, t):
    """keys: [(time, pose[, ease])]: each pose is arrived at by its own ease (EASES; "smooth" when not given) from the
    key before it; a missing part is zero."""
    if t <= keys[0][0]:
        return keys[0][1]
    for k0, k1 in zip(keys, keys[1:]):
        (t0, a), (t1, b) = k0[:2], k1[:2]
        if t <= t1:
            u = EASES[k1[2] if len(k1) > 2 else "smooth"](max(0.0, min(1.0, (t - t0) / (t1 - t0))))
            out = {}
            for k in set(a) | set(b):
                va, vb = list(a.get(k, [])), list(b.get(k, []))
                m = max(len(va), len(vb))
                va += [0.0] * (m - len(va)); vb += [0.0] * (m - len(vb))
                out[k] = [x + (y - x) * u for x, y in zip(va, vb)]
            return out
    return keys[-1][1]


def keyed(keys, cap=0.04):
    """A one-shot clip from keys, with stepping: a planted foot whose target moves along the ground between two keys
    is lifted in an arc on the way (timed by the same ease, so it lands on the key), so a step is a step and never a
    slide. A foot's 4th value (drag) of 1 keeps it on the ground: a paw scraping the dirt."""
    def fn(t):
        pose = dict(sample(keys, t))
        for k0, k1 in zip(keys, keys[1:]):
            if k0[0] <= t <= k1[0]:
                e = EASES[k1[2] if len(k1) > 2 else "smooth"](max(0.0, min(1.0, (t - k0[0]) / (k1[0] - k0[0]))))
                ca, cb = (list(k0[1].get("carry", [])) + [0] * 4), (list(k1[1].get("carry", [])) + [0] * 4)
                for j, ft in enumerate(FEET):
                    va, vb = (list(k0[1].get(ft, [])) + [0] * 4)[:4], (list(k1[1].get(ft, [])) + [0] * 4)[:4]
                    moved = math.hypot(vb[0] - va[0], vb[1] - va[1])
                    if moved > 1e-4 and max(ca[j], cb[j]) < 0.5 and max(va[3], vb[3]) < 0.5:
                        v = (list(pose.get(ft, [])) + [0] * 4)[:4]
                        v[2] += min(cap, 0.7 * moved) * math.sin(math.pi * e)
                        pose[ft] = v
                break
        return pose
    return fn


def stage(floor, res=(480, 320), bg=(0.62, 0.64, 0.68)):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 50
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(-30))
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, floor))
    fm = bpy.data.materials.new("floor"); fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.31, 0.36, 1)  # pale animals read against it
    bpy.context.object.data.materials.append(fm)
    sc.render.engine = "BLENDER_EEVEE"; sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = "Standard"
    return cam


def aim(cam, mid, d, dist):
    v = Vector(d).normalized()
    cam.location = Vector(mid) + v * dist
    cam.rotation_euler = (Vector(mid) - cam.location).to_track_quat("-Z", "Y").to_euler()


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
