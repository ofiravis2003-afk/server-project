# Takes a Mixamo "With Skin" FBX that also carries an animation and writes the clip on its own:
# the skeleton with its keys, no mesh (so Studio imports it as just an animation).
# Run: blender -b --factory-startup --python split_clip.py -- <in.fbx> <out_clip.fbx> <report.txt>
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, report = argv[0], argv[1], argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
action = bpy.data.actions[0] if bpy.data.actions else None
if action:
    bpy.context.scene.frame_start = int(action.frame_range[0])
    bpy.context.scene.frame_end = int(action.frame_range[1])
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, add_leaf_bones=False, bake_anim=True,
                         bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                         apply_scale_options="FBX_SCALE_UNITS")
with open(report, "w") as f:
    f.write(f"ok frames {bpy.context.scene.frame_start}-{bpy.context.scene.frame_end}")
