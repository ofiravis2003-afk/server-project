# Readies a Tripo character (GLB, T-pose, no rig) for Mixamo's auto-rigger:
# one mesh, standing on the floor at the origin, facing -Y (Mixamo's front), about 1.8 m tall,
# exported as FBX with its textures packed in.
# Run: blender -b --factory-startup --python prep_mixamo.py -- <in.glb> <out.fbx> <report.json>
import bpy, sys, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out, report = argv[0], argv[1], argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# Join into one object and bake its transforms
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi

lo, hi = bounds(body)
size = hi - lo
scale = 1.8 / size.z
body.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(scale=True)
lo, hi = bounds(body)
body.location = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
bpy.ops.object.transform_apply(location=True)
lo, hi = bounds(body)
size = hi - lo

bpy.ops.export_scene.fbx(filepath=out, use_selection=True, path_mode="COPY", embed_textures=True, apply_scale_options="FBX_SCALE_UNITS", add_leaf_bones=False)
with open(report, "w") as f:
    json.dump({"objects": len(meshes), "size_m": [size.x, size.y, size.z], "tpose_ratio_width_over_height": size.x / size.z,
               "verts": len(body.data.vertices), "materials": [m.name for m in body.data.materials if m]}, f)
