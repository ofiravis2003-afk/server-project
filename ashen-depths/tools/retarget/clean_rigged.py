# Re-exports a Mixamo "With Skin" FBX so Roblox Studio can import it: skeleton and skin kept,
# embedded textures dropped (Studio's importer can fail on them; the colors come back from the Tripo GLB).
# Run: blender -b --factory-startup --python clean_rigged.py -- <in.fbx> <out.fbx> <report.txt>
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, report = argv[0], argv[1], argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
for mat in list(bpy.data.materials):
    mat.use_nodes = False
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, path_mode="STRIP", embed_textures=False,
                         add_leaf_bones=False, bake_anim=False, apply_scale_options="FBX_SCALE_UNITS")
with open(report, "w") as f:
    f.write("ok " + ", ".join(o.type for o in bpy.context.scene.objects))
