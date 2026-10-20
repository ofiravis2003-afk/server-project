# Turns a Tripo armor piece into layered clothing for Roblox, on Roblox's official Combined-Template.blend
# (create.roblox.com, layered accessories project files): the piece is placed on the template body, and the
# template's full-body clothing cages come with it: the inner cage as it is (the body), the outer cage pushed
# out wherever the piece stands off the body, so Roblox stretches and bends the piece with any avatar.
# Exports one GLB with three meshes, <Name>, <Name>_InnerCage and <Name>_OuterCage, in place.
# Run: blender -b --factory-startup --python layer_armor.py -- <template.blend> <piece.glb> <out.glb> <Name>
#        <width> <bottom z> <top z> [centre y]    (template units: the body is ~5.5 tall, front is -Y)
import bpy, sys, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
template, piece_path, out, name = argv[0], argv[1], argv[2], argv[3]
width, bottom, top = float(argv[4]), float(argv[5]), float(argv[6])
centre_y = float(argv[7]) if len(argv) > 7 else None
log = open(out + ".txt", "w")
def say(*a): log.write(" ".join(str(x) for x in a) + chr(10)); log.flush()

bpy.ops.wm.open_mainfile(filepath=template, load_ui=False, use_scripts=False)
inner = bpy.data.objects["YourClothingName_InnerCage"]
outer = bpy.data.objects["YourClothingName_OuterCage"]
for cage in (inner, outer):
    world = cage.matrix_world.copy()
    cage.parent = None
    cage.matrix_world = world
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=piece_path)
new = [o for o in bpy.data.objects if o not in before]
meshes = [o for o in new if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
armor = bpy.context.view_layer.objects.active
world = armor.matrix_world.copy()
armor.parent = None
armor.matrix_world = world
for o in new:
    if o != armor and o.name in bpy.data.objects:
        bpy.data.objects.remove(o)

# place it: scaled to `width`, its bottom at `bottom` (a top above that is only reported), centred on the
# torso in x and (unless given) in y
bpy.context.view_layer.objects.active = armor
bpy.ops.object.select_all(action="DESELECT")
armor.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = [v.co for v in armor.data.vertices]
lo = Vector((min(v.x for v in co), min(v.y for v in co), min(v.z for v in co)))
hi = Vector((max(v.x for v in co), max(v.y for v in co), max(v.z for v in co)))
s = width / (hi.x - lo.x)
height = (hi.z - lo.z) * s
if top > bottom:
    s_h = (top - bottom) / (hi.z - lo.z)
    say("width scale", round(s, 3), "height scale", round(s_h, 3))
torso = bpy.data.objects.get("UpperTorso_OuterCage")
ty = centre_y
if ty is None and torso:
    tco = [torso.matrix_world @ v.co for v in torso.data.vertices]
    ty = (min(p.y for p in tco) + max(p.y for p in tco)) / 2
ty = ty or 0.0
m = Matrix.Translation(Vector((0, ty, bottom))) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
armor.data.transform(m)
armor.data.update()
say("armor placed: width", width, "height", round(height, 3), "depth", round((hi.y - lo.y) * s, 3), "from z", bottom, "to", round(bottom + height, 3))

# the outer cage: each vertex pushed out along its normal past the piece, where the piece is close
bvh = BVHTree.FromObject(armor, bpy.context.evaluated_depsgraph_get())
inner_me, outer_me = inner.data, outer.data
iw, ow = inner.matrix_world, outer.matrix_world
iw_inv = ow.inverted()
moved = 0
MARGIN, REACH = 0.04, 0.9
for i, v in enumerate(inner_me.vertices):
    p = iw @ v.co
    n = (iw.to_3x3() @ v.normal).normalized()
    far = None
    # every surface of the piece out along the normal, the farthest one counts
    origin = p - n * 0.02
    travelled = 0.0
    while travelled < REACH:
        hit = bvh.ray_cast(origin, n, REACH - travelled)
        if hit[0] is None:
            break
        d = (hit[0] - p).dot(n)
        far = d if far is None else max(far, d)
        step = (hit[0] - origin).length + 0.001
        origin = hit[0] + n * 0.001
        travelled += step
    target = p
    if far is not None and far > -0.05:
        target = p + n * (max(far, 0) + MARGIN)
        moved += 1
    outer_me.vertices[i].co = iw_inv @ target
outer_me.update()
say("outer cage vertices pushed out:", moved, "of", len(inner_me.vertices))

# keep just the three meshes, named for Roblox
for o in list(bpy.data.objects):
    if o not in (armor, inner, outer):
        bpy.data.objects.remove(o)
armor.name = name
inner.name = name + "_InnerCage"
outer.name = name + "_OuterCage"
for o in (inner, outer):
    o.data.materials.clear()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_apply=True)
for o in (armor, inner, outer):
    c = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = [min(p[k] for p in c) for k in range(3)]
    hi = [max(p[k] for p in c) for k in range(3)]
    say(o.name, "centre", [round((lo[k] + hi[k]) / 2, 4) for k in range(3)], "size", [round(hi[k] - lo[k], 4) for k in range(3)])
