"""The style test: the engine, the Ember Kit and the village house together under the art bible's dusk
lighting (docs/game-design/game6-art-bible.md section 3), framed as a 16:9 thumbnail.

blender --background --factory-startup --python tools/blender/lantern/style_test.py

Imports the exported FBX and PNG files, as Garden's lineup.py does, so it also proves they load
with their parts and sizes. Glow parts render as Neon would (flat emission in the manifest colour)
with the PointLights the art bible gives them. build.py calls render() after a full build.
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402


def _load(name, entry):
    """Imports one asset, applies its texture, lights its glow parts, fits the manifest height."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(kit.ROOT, entry["fbx"]))
    meshes = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
    missing = set(entry["parts"]) - {o.name for o in meshes}
    if missing:
        raise RuntimeError(f"{name}: FBX lacks {sorted(missing)}")
    tex_mat = bpy.data.materials.new(f"{name}_tex")
    try:
        tex_mat.use_nodes = True
    except Exception:
        pass
    nt = tex_mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.55
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(kit.ROOT, entry["png"]), check_existing=False)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for ob in meshes:
        ob.data.materials.clear()
        rgb = entry["glow"].get(ob.name)
        ob.data.materials.append(kit.flat(tuple(rgb), emit=3.5) if rgb else tex_mat)
    bpy.context.view_layer.update()
    corners = [ob.matrix_world @ Vector(c) for ob in meshes for c in ob.bound_box]
    lo, hi = Vector(map(min, *corners)), Vector(map(max, *corners))
    scale = entry["size_studs"][1] / (hi.z - lo.z)
    for ob in meshes:
        ob.parent = None
        ob.matrix_world = (Matrix.Scale(scale, 4) @ ob.matrix_world).copy()
    return meshes


def _place(meshes, loc, yaw):
    m = Matrix.Translation(loc) @ kit.rot_z(yaw)
    for ob in meshes:
        ob.matrix_world = m @ ob.matrix_world
    bpy.context.view_layer.update()
    return m


def _glow_lights(meshes, glow, watts_per_area=60):
    """A PointLight in front of every connected piece of every glow mesh, as the game adds one
    per window or lamp: brightness by the piece's area."""
    for ob in meshes:
        rgb = glow.get(ob.name)
        if not rgb:
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.transform(ob.matrix_world)
        bm.verts.ensure_lookup_table()
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            stack, island = [v], []
            seen.add(v.index)
            while stack:
                w = stack.pop()
                island.append(w)
                for e in w.link_edges:
                    o = e.other_vert(w)
                    if o.index not in seen:
                        seen.add(o.index)
                        stack.append(o)
            faces = {f for w in island for f in w.link_faces}
            area = sum(f.calc_area() for f in faces)
            normal = sum((f.normal * f.calc_area() for f in faces), Vector()).normalized()
            centre = sum((w.co for w in island), Vector()) / len(island)
            _point(f"{ob.name}_light", centre + normal * 0.5, tuple(rgb), max(30, area * watts_per_area), 0.4)
        bm.free()


def _point(name, loc, rgb, watts, radius=0.3):
    light = bpy.data.lights.new(name, "POINT")
    light.color = kit.lin(rgb)[:3]
    light.energy = watts
    light.shadow_soft_size = radius
    ob = bpy.data.objects.new(name, light)
    ob.location = loc
    bpy.context.scene.collection.objects.link(ob)


def _sun(name, rgb, energy, rot, angle=12):
    light = bpy.data.lights.new(name, "SUN")
    light.color = kit.lin(rgb)[:3]
    light.energy = energy
    light.angle = math.radians(angle)
    ob = bpy.data.objects.new(name, light)
    ob.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.scene.collection.objects.link(ob)


def _sky(scene):
    """Dusk gradient on the view direction's height: warm horizon, teal band, violet zenith."""
    world = bpy.data.worlds.new("dusk")
    scene.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, kit.lin((70, 70, 110))
    els[1].position, els[1].color = 0.55, kit.lin(kit.DUSK_VIOLET)
    for pos, rgb in ((0.02, kit.HORIZON), (0.09, (196, 150, 170)), (0.2, kit.DUSK_TEAL), (0.36, (66, 80, 132))):
        e = els.new(pos)
        e.color = kit.lin(rgb)
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0


def _fog(lo, hi, density=0.03, rgb=None):
    """The rolling fog: a low volume box in FOG lilac, thick at the ground and thinning to nothing
    at the box's top, as the art bible's Atmosphere does in game."""
    m = bpy.data.materials.new("fog")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = kit.lin(rgb or kit.FOG)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    fall = nt.nodes.new("ShaderNodeMapRange")
    fall.inputs["From Min"].default_value = lo[2]
    fall.inputs["From Max"].default_value = hi[2]
    fall.inputs["To Min"].default_value = density
    fall.inputs["To Max"].default_value = 0.0
    nt.links.new(sep.outputs["Z"], fall.inputs["Value"])
    nt.links.new(fall.outputs["Result"], vol.inputs["Density"])
    vol.inputs["Emission Color"].default_value = kit.lin(rgb or kit.FOG)
    glow = nt.nodes.new("ShaderNodeMath")  # a faint self-glow, so the fog reads lilac, not murk
    glow.operation = "MULTIPLY"
    glow.inputs[1].default_value = 0.6
    nt.links.new(fall.outputs["Result"], glow.inputs[0])
    nt.links.new(glow.outputs[0], vol.inputs["Emission Strength"])
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    size = [h - l for l, h in zip(lo, hi)]
    centre = [(h + l) / 2 for l, h in zip(lo, hi)]
    return kit.box(size, centre, m=m, name="fog")


def _bloom(scene, threshold=0.9, strength=0.6):
    """Roblox Bloom stand-in: a compositor Glare (bloom) over the render. Skipped if the API differs."""
    try:
        tree = bpy.data.node_groups.new("bloom", "CompositorNodeTree")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        layers = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.inputs["Type"].default_value = "Bloom"
        glare.inputs["Threshold"].default_value = threshold
        glare.inputs["Strength"].default_value = strength
        glare.inputs["Size"].default_value = 0.7
        out = tree.nodes.new("NodeGroupOutput")
        tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], out.inputs[0])
        scene.compositing_node_group = tree
    except Exception as e:  # noqa: BLE001
        print(f"[lantern] style test without bloom: {e}", flush=True)


def _track(length=140):
    iron = kit.mat("st_rail", (92, 84, 104), kind="flat", rough=0.35)
    wood = kit.mat("st_sleeper", (84, 62, 56), kind="flat")
    ballast = kit.mat("st_ballast", (78, 76, 92), kind="noise", scale=6)
    kit.box((9.0, length, 0.5), (0, 0, -0.45), m=ballast, bevel=0.2)
    for x in (-3.0, 3.0):
        kit.box((0.35, length, 0.45), (x, 0, -0.02), m=iron)
    y = -length / 2
    while y < length / 2:
        kit.box((8.0, 1.0, 0.3), (0, y, -0.25), m=wood)
        y += 2.2


def render(manifest, samples=160, path=None):
    kit.reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.volume_step_rate = 4
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    _sky(scene)
    _bloom(scene)

    # The engine comes down the track (Y) towards the camera; the stop stands on the far side,
    # its platform facing the track; the Ember Kit waits on the near side, lantern up.
    engine = _load("train_engine", manifest["train_engine"])
    _place(engine, (0, 10, 0), 0)
    cottage = _load("house_cottage", manifest["house_cottage"])
    _place(cottage, (14.4, 8, 0), -90)  # platform edge 1 stud off the engine's side
    for name, meshes in (("train_engine", engine), ("house_cottage", cottage)):
        _glow_lights(meshes, manifest[name]["glow"])
    critter = _load("critter_emberkit", manifest["critter_emberkit"])
    # Its lantern is baked, not Neon: the game hangs a PointLight in it (critters.py NOTES).
    side = max((ob.matrix_world @ v.co for ob in critter for v in ob.data.vertices), key=lambda p: p.x)
    m = _place(critter, (-10.0, -14.0, -0.2), -6)  # nearly facing the camera, lantern towards the engine
    _point("kit_lamp", m @ (side - Vector((0.3, 0, 0))), kit.LAMP_GLOW, 80, 0.2)

    # The headlamp's beam, a SpotLight as in game (art bible section 3).
    lens = max((v for ob in engine if ob.name == "train_engine_lamp_glow" for v in (ob.matrix_world @ w.co for w in ob.data.vertices)), key=lambda p: -p.y)
    beam = bpy.data.lights.new("beam", "SPOT")
    beam.color = kit.lin(kit.LAMP_GLOW)[:3]
    beam.energy = 6000
    beam.spot_size = math.radians(50)
    beam.spot_blend = 0.6
    beam.shadow_soft_size = 0.5
    ob = bpy.data.objects.new("beam", beam)
    ob.location = lens + Vector((0, -0.3, 0))
    ob.rotation_euler = Vector((0, -1, -0.28)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(ob)

    _track()
    ground = kit.mat("st_ground", (54, 80, 84), kind="noise", scale=0.08, var=0.2)
    kit.cyl(220, 0.2, (0, 0, -0.3), m=ground, n=64)
    hills = kit.mat("st_hills", (52, 50, 104), kind="flat")
    for x, y, r, sx, sz in ((-90, 170, 60, 1.8, 0.42), (40, 190, 70, 1.6, 0.4), (-20, 230, 80, 2.2, 0.32)):
        kit.sphere(r, (x, y, -4), m=hills, scale=(sx, 0.6, sz), seg=48, rings=16)
    _fog((-200, 26, -1), (200, 260, 22), density=0.05)  # the fog wall rolling in behind the train
    _fog((-60, -40, -1), (60, 26, 3.0), density=0.014)  # a thin layer creeping round the wheels
    moon = kit.flat((255, 240, 214), emit=8.0)
    kit.sphere(5, (18, 172, 62), m=moon, seg=32, rings=16)

    # Dusk key (low, warm, from the front left), cool rim from behind.
    _sun("key", (255, 186, 140), 2.0, (74, 0, -50))
    _sun("rim", (150, 140, 255), 1.8, (62, 0, 160))

    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 30
    cam_data.clip_end = 600
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (-14.0, -25.0, 2.3)
    target = Vector((2.5, 2.0, 4.8))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    path = path or os.path.join(kit.OUT, "style_test.png")
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print(f"[lantern] style test: {path}", flush=True)


if __name__ == "__main__":
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        render(json.load(f))
