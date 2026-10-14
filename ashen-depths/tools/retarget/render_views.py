# Renders a model from the front and the side (orthographic, flat light) with a 0.1-unit grid behind it.
import bpy, sys, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
src, out_prefix = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.endswith(".glb"):
    bpy.ops.import_scene.gltf(filepath=src)
else:
    bpy.ops.import_scene.fbx(filepath=src)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
pts = []
for o in scene.objects:
    if o.type == "MESH":
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
size = max(hi.x - lo.x, hi.z - lo.z) * 1.1
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = size
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
for name, direction in (("front", Vector((0, -1, 0))), ("side", Vector((1, 0, 0)))):
    cam.location = center + direction * 10
    cam.rotation_euler = (direction * -1).to_track_quat("-Z", "Z").to_euler()
    scene.render.filepath = f"{out_prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)
with open(out_prefix + "_bounds.txt", "w") as f:
    f.write(f"lo {tuple(lo)} hi {tuple(hi)}")
