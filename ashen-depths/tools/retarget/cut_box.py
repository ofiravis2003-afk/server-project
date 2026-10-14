# Deletes the faces of a GLB model that lie inside a box (model units, Blender axes), saves a new GLB.
# Run: blender -b --python cut_box.py -- <in.glb> <out.glb> xmin xmax ymin ymax zmin zmax
import bpy, bmesh, sys
argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
x0, x1, y0, y1, z0, z1 = map(float, argv[2:8])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
removed = 0
for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    doomed = []
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        if x0 <= c.x <= x1 and y0 <= c.y <= y1 and z0 <= c.z <= z1:
            doomed.append(f)
    removed += len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
with open(out + ".txt", "w") as fh:
    fh.write(f"removed {removed} faces")
