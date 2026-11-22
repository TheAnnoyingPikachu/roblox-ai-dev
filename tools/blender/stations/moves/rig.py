"""Shared Blender setup: load a Stations creature's built FBX, pose it as Creatures.client does
(joint -> [pitch, yaw, roll, x, y, z], offsets in studs x the model's Scale), light, floor, camera,
and measure how far its legs sink under the floor (skinned models get no lift in the game)."""
import json
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))  # the repo (its build/ holds the FBX)
LEGS = ("leg_fl", "leg_fr", "leg_bl", "leg_br")


class Rig:
    def __init__(self, asset, view=(-0.8, -1.0, 0.3), res=(480, 400), dist=1.0):
        entry = json.load(open(f"{ROOT}/tools/blender/stations/manifest.json", encoding="utf-8"))[asset]
        j = entry["joints"]
        self.upright = j[f"{asset}_leg_fl"][1] > 2 * j[f"{asset}_leg_bl"][1]
        self.scale = j[f"{asset}_leg_bl" if self.upright else f"{asset}_leg_fl"][1] / 1.45
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=f"{ROOT}/build/blender/stations/{asset}.fbx", axis_forward="-Z", axis_up="Y",
                                 primary_bone_axis="Y", secondary_bone_axis="X")
        sc = self.sc = bpy.context.scene
        self.arm = next(o for o in sc.objects if o.type == "ARMATURE")
        self.body = next(o for o in sc.objects if o.type == "MESH")
        self.A = self.arm.matrix_world.to_3x3()
        pts = self.points()
        lo, hi = pts.min(0), pts.max(0)
        self.lo, self.hi = Vector(lo), Vector(hi)
        h = hi[2] - lo[2]
        self.unit = h / entry["size_studs"][1]
        self.floor = lo[2]
        # each vertex's strongest bone: the feet are the leg vertices (a flamingo's back legs are its wings)
        names = {g.index: g.name for g in self.body.vertex_groups}
        top = []
        for v in self.body.data.vertices:
            ws = sorted(((g.weight, names[g.group]) for g in v.groups), reverse=True)
            top.append(ws[0][1] if ws else "body")
        feet = ("leg_fl", "leg_fr") if "flamingo" in asset else LEGS
        if self.upright:
            feet = ("leg_bl", "leg_br")
        self.feet = np.array([t in feet for t in top])
        self.rest_feet = pts[self.feet].min(0)[2]
        self._scene(lo, hi, view, res, dist)

    def points(self):
        deps = bpy.context.evaluated_depsgraph_get()
        ev = self.body.evaluated_get(deps)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        co = co.reshape(-1, 3)
        M = np.array(self.body.matrix_world)
        return co @ M[:3, :3].T + M[:3, 3]

    def pose(self, pose):
        s = self.scale * self.unit
        for pb in self.arm.pose.bones:
            v = list(pose.get(pb.name, [])) + [0] * 6
            move = Vector((-v[3], v[5], v[4])) * s
            turn = (Matrix.Translation(move) @ Matrix.Rotation(math.radians(-v[0]), 4, "X")
                    @ Matrix.Rotation(math.radians(v[1]), 4, "Z") @ Matrix.Rotation(math.radians(v[2]), 4, "Y"))
            rest = (self.A @ pb.bone.matrix_local.to_3x3()).to_4x4()
            pb.matrix_basis = rest.inverted() @ turn @ rest
        bpy.context.view_layer.update()

    def sink(self):
        """studs the feet are under the floor (+) or above where they rest (-), at the moment's pose"""
        low = self.points()[self.feet].min(0)[2]
        return (self.rest_feet - low) / self.unit

    def _scene(self, lo, hi, view, res, dist):
        sc = self.sc
        w = bpy.data.worlds.new("w")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.22, 0.2, 0.27, 1)
        w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
        sc.world = w
        for rot, energy in (((math.radians(45), 0, math.radians(-35)), 3.2), ((math.radians(65), 0, math.radians(140)), 1.4)):
            d = bpy.data.lights.new("sun", "SUN")
            d.energy = energy
            ob = bpy.data.objects.new("sun", d)
            ob.rotation_euler = rot
            sc.collection.objects.link(ob)
        c = (lo + hi) / 2
        size = float(np.linalg.norm(hi - lo))
        r = size * 6
        fme = bpy.data.meshes.new("floor")
        fme.from_pydata([(c[0] - r, c[1] - r, lo[2]), (c[0] + r, c[1] - r, lo[2]), (c[0] + r, c[1] + r, lo[2]), (c[0] - r, c[1] + r, lo[2])], [], [(0, 1, 2, 3)])
        fob = bpy.data.objects.new("floor", fme)
        sc.collection.objects.link(fob)
        fm = bpy.data.materials.new("floor")
        fm.use_nodes = True
        bsdf = fm.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.16, 0.15, 0.19, 1)
        bsdf.inputs["Roughness"].default_value = 0.95
        fme.materials.append(fm)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.lens = 50
        sc.collection.objects.link(cam)
        sc.camera = cam
        h = hi[2] - lo[2]
        look = Vector((c[0], c[1] - (hi[1] - lo[1]) * 0.3, lo[2] + h * 0.55))  # ahead of it: moves travel forward
        cam.location = look + Vector(view).normalized() * size * 1.9 * dist
        cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
        engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
        sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.view_settings.view_transform = "Standard"

    def shot(self, path):
        self.sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
