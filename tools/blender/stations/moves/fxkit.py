"""Magic effects drawn fresh each frame in Blender, from shapes Roblox can also make (Neon parts, beams,
rings, particles, a Highlight round the body). Units are studs (the scene's units times U)."""
import math
import random

import bpy
import numpy as np
from mathutils import Matrix, Vector

UP = Vector((0, 0, 1))
GAIN = 0.4  # emission strength per unit of `glow` (the compositor's bloom picks up what passes 1.2)
# "Hot core" (SHANNON's pick, 2026-11-22): glowing shapes in layers, a white-hot core in a coloured body in a soft
# glowing edge (a ForceField-material shell in Roblox), and a star flash with a crisp shock ring on every hit
HOT = False
WHITE = (1.0, 1.0, 1.0)


def ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def seg(t, a, b):
    """0..1 through [a, b], None outside"""
    if t < a or t > b:
        return None
    return (t - a) / max(1e-6, b - a)


def env(t, a, b, c, d):
    """0 before a, rising to 1 at b, 1 until c, falling to 0 at d"""
    if t <= a or t >= d:
        return 0.0
    if t < b:
        return ease((t - a) / (b - a))
    if t <= c:
        return 1.0
    return 1 - ease((t - c) / (d - c))


def bez(a, c, b, u):
    return a * (1 - u) ** 2 + c * 2 * u * (1 - u) + b * u * u


def mix(a, b, u):
    return a + (b - a) * u


class Kit:
    def __init__(self, rig, U, cam_from):
        self.r, self.U = rig, U
        self.cam_from = cam_from
        self.col = bpy.data.collections.new("fx")
        bpy.context.scene.collection.children.link(self.col)
        self.mats = {}
        self.prims = {}
        for kind in ("sphere", "ico", "cube", "cyl", "cone", "octa"):
            self.prims[kind] = self._prim(kind)
        self.posed = None

    # -- building blocks ------------------------------------------------------------------------------------
    def _prim(self, kind):
        if kind == "sphere":
            bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=18, ring_count=9)
        elif kind == "ico":
            bpy.ops.mesh.primitive_ico_sphere_add(radius=1, subdivisions=1)
        elif kind == "cube":
            bpy.ops.mesh.primitive_cube_add(size=1)
        elif kind == "cyl":
            bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, vertices=14)
        elif kind == "cone":
            bpy.ops.mesh.primitive_cone_add(radius1=1, radius2=0, depth=1, vertices=8)
        elif kind == "octa":
            bpy.ops.mesh.primitive_cone_add(radius1=1, radius2=0, depth=1, vertices=4)
        ob = bpy.context.object
        me = ob.data
        if kind == "octa":  # a diamond: two four-sided cones base to base
            me = bpy.data.meshes.new("octa")
            me.from_pydata([(1, 0, 0), (0, 1, 0), (-1, 0, 0), (0, -1, 0), (0, 0, 0.5), (0, 0, -0.5)], [],
                           [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)])
        me.use_fake_user = True
        me.materials.append(bpy.data.materials.new("slot"))  # one slot, which each object fills with its own
        for p in me.polygons:
            p.use_smooth = kind in ("sphere",)
        bpy.data.objects.remove(ob, do_unlink=True)
        return me

    def mat(self, rgb, glow=4.0, alpha=1.0):
        key = (tuple(round(c, 3) for c in rgb), round(glow, 1), round(alpha, 2))
        m = self.mats.get(key)
        if m is None:
            m = bpy.data.materials.new("fx")
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (*rgb, 1)
            b.inputs["Roughness"].default_value = 0.6
            if glow:
                b.inputs["Emission Color"].default_value = (*rgb, 1)
                b.inputs["Emission Strength"].default_value = glow * GAIN
            if alpha < 1:
                b.inputs["Alpha"].default_value = max(0.0, alpha)
                m.surface_render_method = "BLENDED"
                m.use_transparency_overlap = True
            self.mats[key] = m
        return m

    def rim(self, rgb, glow, alpha):
        """see-through in the middle, glowing at the edges (a Highlight's look)"""
        key = ("rim", tuple(round(c, 3) for c in rgb), round(glow, 1), round(alpha, 2))
        m = self.mats.get(key)
        if m is None:
            m = bpy.data.materials.new("rim")
            m.use_nodes = True
            nt = m.node_tree
            b = nt.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (*rgb, 1)
            b.inputs["Emission Color"].default_value = (*rgb, 1)
            b.inputs["Emission Strength"].default_value = glow * GAIN
            lw = nt.nodes.new("ShaderNodeLayerWeight")
            lw.inputs["Blend"].default_value = 0.45
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY_ADD"
            mul.inputs[1].default_value = alpha
            mul.inputs[2].default_value = alpha * 0.18
            nt.links.new(lw.outputs["Facing"], mul.inputs[0])
            nt.links.new(mul.outputs[0], b.inputs["Alpha"])
            m.surface_render_method = "BLENDED"
            self.mats[key] = m
        return m

    def _obj(self, kind, rgb, glow, alpha, loc, rot=None, scale=(1, 1, 1)):
        if alpha <= 0.01:
            return None
        ob = bpy.data.objects.new(kind, self.prims[kind])
        self.col.objects.link(ob)
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = self.mat(rgb, glow, alpha)
        ob.location = loc
        if rot is not None:
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = rot
        ob.scale = scale
        return ob

    def _mesh(self, verts, faces, rgb, glow, alpha):
        if alpha <= 0.01 or not faces:
            return None
        me = bpy.data.meshes.new("fx")
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.materials.append(self.mat(rgb, glow, alpha))
        ob = bpy.data.objects.new("fx", me)
        self.col.objects.link(ob)
        return ob

    def clear(self):
        for ob in list(self.col.objects):
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if isinstance(data, bpy.types.Light):
                bpy.data.lights.remove(data)
        for me in [m for m in bpy.data.meshes if m.users == 0 and not m.use_fake_user]:
            bpy.data.meshes.remove(me)

    # -- effects (sizes in studs) ---------------------------------------------------------------------------
    def shell(self, p, r, rgb, glow, alpha):
        """a soft glowing edge (a ForceField-material shell in Roblox)"""
        ob = self._obj("sphere", rgb, glow, alpha, p, scale=(r * self.U,) * 3)
        if ob:
            ob.material_slots[0].material = self.rim(rgb, glow, alpha)

    def star(self, p, R, rgb, alpha, n=8, spin=0.3):
        """an impact flash: thin streaks out from p, facing the camera, long and short in turn"""
        if alpha <= 0.01:
            return
        view = (self.cam_from - p).normalized()
        a = view.cross(Vector((1, 0, 0)) if abs(view.x) < 0.9 else Vector((0, 1, 0))).normalized()
        b = view.cross(a)
        for i in range(n):
            ang = spin + i / n * math.tau
            d = a * math.cos(ang) + b * math.sin(ang)
            L = R * (1.0 if i % 2 == 0 else 0.5)
            self._spike(p, p + d * L, 0.05 * R, WHITE, 11, alpha)
            self._spike(p, p + d * L * 0.85, 0.11 * R, rgb, 7, 0.55 * alpha)

    def shock(self, p, R, w, rgb, alpha, normal=UP):
        """a crisp shock ring: a bright leading edge with a fainter wash behind it"""
        if alpha <= 0.01:
            return
        self._ring(p, R, w, WHITE, 9, alpha, normal)
        self._ring(p, R * 0.94, w * 2.0, rgb, 6, 0.55 * alpha, normal)
        self._ring(p, R * 0.8, w * 0.7, rgb, 4, 0.25 * alpha, normal)

    def converge(self, p, R, rgb, u0, n=3):
        """rings closing in on p as it charges (u0 0 -> 1), facing the camera"""
        if u0 is None:
            return
        view = (self.cam_from - p).normalized()
        for i in range(n):
            u = (u0 * 2.2 + i / n) % 1
            self._ring(p, R * (1 - u) + 0.05, 0.05 * R * (0.6 + u), rgb, 7, u * 0.9, view)

    def orb(self, p, r, rgb, glow=6, alpha=1.0, core=True, light=0.0):
        U = self.U
        if HOT and glow >= 3 and alpha > 0.01:
            if core:  # a ball of energy: core, body, edge
                self._obj("sphere", WHITE, glow * 1.3, alpha, p, scale=(r * 0.42 * U,) * 3)
                self._obj("sphere", rgb, glow, alpha * 0.5, p, scale=(r * 0.8 * U,) * 3)
                self.shell(p, r * 1.35, rgb, glow * 0.7, alpha * 0.8)
            else:  # a dome or a glow: a soft glowing edge
                self.shell(p, r, rgb, glow, min(1.0, alpha * 1.3))
            if light:
                self.light(p, rgb, light * r * r)
            return
        self._obj("sphere", rgb, glow, alpha * 0.55 if core else alpha, p, scale=(r * U,) * 3)
        if core:
            self._obj("sphere", (1, 1, 1), glow * 1.6, alpha, p, scale=(r * 0.5 * U,) * 3)
        if light:
            self.light(p, rgb, light * r * r)

    def ball(self, p, r, rgb, glow=0.0, alpha=1.0):  # a plain solid sphere (rock, cloud puff)
        self._obj("sphere", rgb, glow, alpha, p, scale=(r * self.U,) * 3)

    def spark(self, p, r, rgb, glow=8, alpha=1.0):
        self._obj("ico", rgb, glow, alpha, p, scale=(r * self.U,) * 3)

    def burst(self, p, u, n, reach, rgb, seed=1, size=0.16, rise=0.4, glow=8):
        """sparks thrown out from p as u goes 0 -> 1, fading"""
        if u is None or u >= 1:
            return
        rng = random.Random(seed)
        for _ in range(n):
            d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1) + rise)).normalized()
            q = p + d * reach * ease(min(1, u * 1.4)) * rng.uniform(0.5, 1.0) * self.U - UP * 2.5 * u * u * self.U
            self.spark(q, size * (1 - 0.6 * u), rgb, glow, 1 - u)

    def box(self, p, size, rgb, glow=0.0, alpha=1.0, rot=None):
        self._obj("cube", rgb, glow, alpha, p, rot=rot, scale=tuple(s * self.U for s in size))

    def diamond(self, p, r, h, rgb, glow=4, alpha=1.0, spin=0.0, axis=None):
        self._diamond(p, r, h, rgb, glow, alpha, spin, axis)
        if HOT and glow >= 4:
            self._diamond(p, r * 0.45, h * 0.6, WHITE, glow * 1.3, alpha, spin, axis)

    def _diamond(self, p, r, h, rgb, glow=4, alpha=1.0, spin=0.0, axis=None):
        rot = None
        if axis is not None:
            rot = axis.normalized().to_track_quat("Z", "Y")
        q = (rot or Matrix.Identity(3).to_quaternion()) @ Matrix.Rotation(spin, 3, "Z").to_quaternion()
        self._obj("octa", rgb, glow, alpha, p, rot=q, scale=(r * self.U, r * self.U, h * self.U))

    def _along(self, a, b):
        d = b - a
        return (a + b) / 2, d.normalized().to_track_quat("Z", "Y"), d.length

    def beam(self, a, b, r, rgb, glow=6, alpha=1.0, core=True):
        mid, q, n = self._along(a, b)
        if n < 1e-4:
            return
        if HOT and glow >= 3:  # core, body, edge
            self._obj("cyl", WHITE, glow * 1.3, alpha, mid, rot=q, scale=(r * 0.32 * self.U, r * 0.32 * self.U, n))
            self._obj("cyl", rgb, glow, alpha * 0.5, mid, rot=q, scale=(r * 0.75 * self.U, r * 0.75 * self.U, n))
            ob = self._obj("cyl", rgb, glow, alpha, mid, rot=q, scale=(r * 1.3 * self.U, r * 1.3 * self.U, n))
            if ob:
                ob.material_slots[0].material = self.rim(rgb, glow * 0.7, alpha * 0.8)
            return
        self._obj("cyl", rgb, glow, alpha * (0.5 if core else 1), mid, rot=q, scale=(r * self.U, r * self.U, n))
        if core:
            self._obj("cyl", (1, 1, 1), glow * 1.5, alpha, mid, rot=q, scale=(r * 0.4 * self.U, r * 0.4 * self.U, n))

    def spike(self, base, tip, r, rgb, glow=0.0, alpha=1.0):
        self._spike(base, tip, r, rgb, glow, alpha)
        if HOT and glow >= 4:
            self._spike(base, base.lerp(tip, 0.75), r * 0.38, WHITE, glow * 1.3, alpha)

    def _spike(self, base, tip, r, rgb, glow=0.0, alpha=1.0):
        mid, q, n = self._along(base, tip)
        if n < 1e-4:
            return
        self._obj("cone", rgb, glow, alpha, mid, rot=q, scale=(r * self.U, r * self.U, n))

    def tube(self, pts, r, rgb, glow=4, alpha=1.0, closed=False, sides=6, taper=None):
        """a round tube along points (radius r, or r * taper(i/n) along it); hot, a white core runs inside"""
        self._tube(pts, r, rgb, glow, alpha, closed, sides, taper)
        if HOT and glow >= 4 and alpha > 0.05:
            self._tube(pts, r * 0.38, WHITE, glow * 1.3, min(1.0, alpha * 1.2), closed, 5, taper)

    def _ring(self, p, R, w, rgb, glow, alpha, normal):
        normal = normal.normalized()
        a = normal.cross(Vector((1, 0, 0)) if abs(normal.x) < 0.9 else Vector((0, 1, 0))).normalized()
        b = normal.cross(a)
        pts = [p + (a * math.cos(i / 36 * math.tau) + b * math.sin(i / 36 * math.tau)) * R * self.U for i in range(36)]
        self._tube(pts, w, rgb, glow, alpha, closed=True)

    def _tube(self, pts, r, rgb, glow=4, alpha=1.0, closed=False, sides=6, taper=None):
        n = len(pts)
        if n < 2:
            return
        verts, faces = [], []
        for i, p in enumerate(pts):
            a = pts[(i + 1) % n] if (closed or i + 1 < n) else p
            b = pts[i - 1] if (closed or i > 0) else p
            d = (a - b)
            d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
            side = d.cross(UP if abs(d.dot(UP)) < 0.95 else Vector((1, 0, 0))).normalized()
            up = side.cross(d).normalized()
            rr = r * (taper(i / max(1, n - 1)) if taper else 1.0) * self.U
            for k in range(sides):
                ang = k / sides * math.tau
                verts.append(p + (side * math.cos(ang) + up * math.sin(ang)) * rr)
        last = n if closed else n - 1
        for i in range(last):
            j = (i + 1) % n
            for k in range(sides):
                k2 = (k + 1) % sides
                faces.append((i * sides + k, i * sides + k2, j * sides + k2, j * sides + k))
        self._mesh(verts, faces, rgb, glow, alpha)

    def ring(self, p, R, w, rgb, glow=5, alpha=1.0, normal=UP, arc=(0.0, math.tau), n=40):
        normal = normal.normalized()
        a = normal.cross(Vector((1, 0, 0)) if abs(normal.x) < 0.9 else Vector((0, 1, 0))).normalized()
        b = normal.cross(a)
        closed = abs(arc[1] - arc[0] - math.tau) < 1e-3
        steps = n if closed else max(3, int(n * (arc[1] - arc[0]) / math.tau) + 1)
        pts = []
        for i in range(steps if closed else steps + 1):
            ang = arc[0] + (arc[1] - arc[0]) * i / steps
            pts.append(p + (a * math.cos(ang) + b * math.sin(ang)) * R * self.U)
        self.tube(pts, w, rgb, glow, alpha, closed=closed, taper=None if closed else (lambda x: math.sin(math.pi * x) ** 0.6 + 0.05))

    def disc(self, p, R, rgb, glow=2, alpha=0.6, n=36, lift=0.03):
        verts = [p + UP * lift * self.U] + [p + UP * lift * self.U + Vector((math.cos(k / n * math.tau), math.sin(k / n * math.tau), 0)) * R * self.U for k in range(n)]
        faces = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
        self._mesh(verts, faces, rgb, glow, alpha)

    def circle(self, p, R, rgb, spin, glow=6, alpha=1.0, spokes=8):
        """a magic circle on the ground: two rings, runes between them, spokes"""
        p = p + UP * 0.05 * self.U
        self.ring(p, R, 0.07 * R, rgb, glow, alpha)
        self.ring(p, R * 0.72, 0.05 * R, rgb, glow, alpha)
        for k in range(spokes):
            ang = spin + k / spokes * math.tau
            d = Vector((math.cos(ang), math.sin(ang), 0))
            self.box(p + d * R * 0.86 * self.U, (0.14 * R, 0.05 * R, 0.03 * R), rgb, glow, alpha,
                     rot=Matrix.Rotation(ang, 3, "Z").to_quaternion())
            a2 = -spin * 0.7 + (k + 0.5) / spokes * math.tau
            d2 = Vector((math.cos(a2), math.sin(a2), 0))
            self.tube([p + d2 * R * 0.18 * self.U, p + d2 * R * 0.7 * self.U], 0.025 * R, rgb, glow, alpha * 0.8)

    def crescent(self, p, R, w, rgb, normal, facing, glow=6, alpha=1.0):
        """a crescent blade: an arc of 220 degrees whose middle points along `facing`"""
        normal = normal.normalized()
        facing = (facing - normal * facing.dot(normal)).normalized()
        side = normal.cross(facing)
        pts = []
        for i in range(25):
            ang = -1.9 + 3.8 * i / 24
            pts.append(p + (facing * math.cos(ang) + side * math.sin(ang)) * R * self.U)
        self.tube(pts, w, rgb, glow, alpha, taper=lambda x: math.sin(math.pi * x) ** 0.7 + 0.03)

    def bolt(self, a, b, rgb, r=0.12, jag=0.18, n=9, seed=1, glow=10, alpha=1.0, fork=0):
        rng = random.Random(seed)
        d = b - a
        side = d.cross(UP if abs(d.normalized().dot(UP)) < 0.9 else Vector((1, 0, 0))).normalized()
        up = side.cross(d.normalized()).normalized()
        pts = [a]
        for i in range(1, n):
            u = i / n
            off = (side * rng.uniform(-1, 1) + up * rng.uniform(-1, 1)) * jag * d.length
            pts.append(a + d * u + off)
        pts.append(b)
        self.tube(pts, r, (1, 1, 1), glow * 1.4, alpha)
        self.tube(pts, r * 2.6, rgb, glow, alpha * 0.45)
        for f in range(fork):
            i = rng.randrange(2, n - 1)
            end = pts[i] + (side * rng.uniform(-1, 1) + up * rng.uniform(-0.6, 0.6) + d.normalized() * 0.5).normalized() * d.length * 0.25
            self.bolt(pts[i], end, rgb, r * 0.6, jag, 4, seed + 7 * f + 1, glow, alpha, 0)

    def trail(self, pts, w, rgb, glow=4, alpha=0.6):
        """a flat ribbon through pts (newest first) facing the camera, thinning toward its end"""
        self._trail(pts, w, rgb, glow, alpha)
        if HOT and glow >= 4:
            self._trail(pts, w * 0.3, WHITE, glow * 1.3, min(1.0, alpha * 1.4))

    def _trail(self, pts, w, rgb, glow=4, alpha=0.6):
        if len(pts) < 2:
            return
        verts, faces = [], []
        for i, p in enumerate(pts):
            nb = pts[i + 1] if i + 1 < len(pts) else pts[i - 1]
            d = (p - nb) if i + 1 < len(pts) else (nb - p) * -1
            d = d.normalized() if d.length > 1e-6 else UP
            view = (self.cam_from - p).normalized()
            s = d.cross(view).normalized() * w * self.U * (1 - i / len(pts))
            verts += [p + s, p - s]
            if i:
                faces.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
        self._mesh(verts, faces, rgb, glow, alpha)

    def vortex(self, p, R, H, rgb, t, n=4, glow=4, alpha=0.6, turns=1.6, w=0.12):
        for k in range(n):
            pts = []
            for i in range(30):
                u = i / 29
                ang = t * 9 + k / n * math.tau + u * turns * math.tau
                rr = R * (0.35 + 0.65 * u)
                pts.append(p + Vector((math.cos(ang) * rr, math.sin(ang) * rr, u * H)) * self.U)
            self.tube(pts, w, rgb, glow, alpha, taper=lambda x: 0.3 + 0.7 * math.sin(math.pi * x))

    def cloud(self, p, R, rgb, seed=1, alpha=1.0, glow=0.3):
        rng = random.Random(seed)
        for _ in range(9):
            q = p + Vector((rng.uniform(-1, 1), rng.uniform(-0.6, 0.6), rng.uniform(-0.25, 0.3))) * R * self.U
            self.ball(q, R * rng.uniform(0.35, 0.6), rgb, glow, alpha)

    def light(self, p, rgb, energy):
        if energy <= 0:
            return
        d = bpy.data.lights.new("fx", "POINT")
        d.color = rgb
        d.energy = energy * 25 * self.U * self.U
        d.shadow_soft_size = 0.5 * self.U
        ob = bpy.data.objects.new("fx", d)
        ob.location = p
        self.col.objects.link(ob)

    def ghost(self, pose, offset, rgb, glow=3, alpha=0.4, scale=1.0, yaw=0.0, now=None):
        """a see-through copy of the animal in `pose`, moved by `offset` (studs), scaled and turned about its middle"""
        r = self.r
        if pose is not None:
            r.pose(pose)
        dep = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(r.body.evaluated_get(dep))
        if pose is not None and now is not None:
            r.pose(now)
        me.materials.clear()
        me.materials.append(self.rim(rgb, glow, alpha))
        for poly in me.polygons:
            poly.material_index = 0
        ob = bpy.data.objects.new("fx", me)
        self.col.objects.link(ob)
        c = r.mid
        ob.matrix_world = (Matrix.Translation(offset * self.U + c) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
                           @ Matrix.Translation(-c) @ r.body.matrix_world)
        return ob

    def aura(self, rgb, alpha=0.3, glow=4, grow=1.05):
        """the animal outlined in light (a Highlight in the game): its own pose, slightly larger"""
        if alpha > 0.01:
            self.ghost(None, Vector(), rgb, glow, alpha, scale=grow)
