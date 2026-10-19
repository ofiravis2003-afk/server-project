# Applies fix_weights.py to the Mixamo rig and exports it the way clean_rigged.py does.
# Run: blender -b --factory-startup --python export_fixed.py -- <in.fbx> <fix_weights.py> <out.fbx> <report.txt>
import bpy, sys
src, fix, out, report = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
mesh = next(o for o in bpy.data.objects if o.type == "MESH")
exec(open(fix).read())
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
for mat in list(bpy.data.materials):
    mat.use_nodes = False
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, path_mode="STRIP", embed_textures=False,
                         add_leaf_bones=False, bake_anim=False, apply_scale_options="FBX_SCALE_UNITS")
with open(report, "w") as f:
    f.write(print_fix + " | " + ", ".join(o.type for o in bpy.context.scene.objects))
