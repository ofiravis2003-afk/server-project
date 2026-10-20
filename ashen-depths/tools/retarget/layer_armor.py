# Turns a Tripo armor piece into layered clothing for Roblox, on Roblox's official Combined-Template.blend
# (create.roblox.com, layered accessories project files). The piece is placed on the template body; the
# template's full-body clothing cages come with it: the inner cage as it is (the body), the outer cage pushed
# out wherever the piece stands off the body. In Studio the piece becomes an Accessory whose WrapLayer uses
# the two cages, so Roblox stretches and bends it with any avatar (AutoSkin gives it the body's skinning).
#   torso: the piece centred on the chest, `width` wide, its bottom at `bottom`, `depth` times as deep
#   arms:  a glove (as prep_armor.py leaves it: along +Z, hand at the bottom) laid along the right forearm
#          from the fingertips to the elbow, and a mirror copy on the left one, as one mesh
#   legs:  a boot (upright, toe -Y) on the right lower leg from the sole up `height`, and a mirror copy
# Exports <out>.glb with three meshes: <Name>, <Name>CageIn and <Name>CageOut (Studio's importer drops meshes
# named _InnerCage / _OuterCage outside its own layered-clothing import), all in place, and <out>.glb.txt
# with their centres.
# Run: blender -b --factory-startup --python layer_armor.py -- <template.blend> <piece.glb> <out.glb> <Name>
#        <mode> <size> [bottom z] [depth]   (torso: size = width; legs: size = height; arms: size = extra length)
import bpy, sys, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
template, piece_path, out, name, mode = argv[0], argv[1], argv[2], argv[3], argv[4]
size = float(argv[5])
bottom = float(argv[6]) if len(argv) > 6 else 0.0
depth = float(argv[7]) if len(argv) > 7 else 1.0
log = open(out + ".txt", "w")
def say(*a): log.write(" ".join(str(x) for x in a) + chr(10)); log.flush()

bpy.ops.wm.open_mainfile(filepath=template, load_ui=False, use_scripts=False)
inner = bpy.data.objects["YourClothingName_InnerCage"]
outer = bpy.data.objects["YourClothingName_OuterCage"]
for cage in (inner, outer):
    world = cage.matrix_world.copy()
    cage.parent = None
    cage.matrix_world = world

def centroid(obj_name):
    o = bpy.data.objects[obj_name]
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    return sum(pts, Vector()) / len(pts), pts

def bounds(pts):
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))

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
bpy.ops.object.select_all(action="DESELECT")
armor.select_set(True)
bpy.context.view_layer.objects.active = armor
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = armor.data
lo, hi = bounds([v.co for v in me.vertices])

def mirrored_copy():
    # the left one: the right one mirrored across x (faces turned so they still face out)
    bpy.ops.object.select_all(action="DESELECT")
    armor.select_set(True)
    bpy.context.view_layer.objects.active = armor
    bpy.ops.object.duplicate()
    left = bpy.context.view_layer.objects.active
    left.data.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
    left.data.flip_normals()
    bpy.ops.object.select_all(action="DESELECT")
    armor.select_set(True)
    left.select_set(True)
    bpy.context.view_layer.objects.active = armor
    bpy.ops.object.join()

if mode == "torso":
    s = size / (hi.x - lo.x)
    tc, tp = centroid("UpperTorso_OuterCage")
    tlo, thi = bounds(tp)
    ty = (tlo.y + thi.y) / 2
    me.transform(Matrix.Translation(Vector((0, ty, bottom))) @ Matrix.Scale(depth, 4, Vector((0, 1, 0))) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    say("torso: width", size, "height", round((hi.z - lo.z) * s, 3), "from z", bottom)
elif mode == "arms":
    hand_c, hand_p = centroid("RightHand_OuterCage")
    arm_c, arm_p = centroid("RightLowerArm_OuterCage")
    axis = (arm_c - hand_c).normalized()           # up the forearm, toward the elbow
    tip = min(hand_p, key=lambda p: (p - hand_c).dot(axis))   # the fingertips
    elbow = max(arm_p, key=lambda p: (p - hand_c).dot(axis))
    length = (elbow - tip).dot(axis) + size
    s = length / (hi.z - lo.z)
    # glove frame: +Z along the forearm; its palm (-X as prepared) turned to face the body (+X here)
    to_body = Vector((1, 0, 0))
    palm = (to_body - axis * to_body.dot(axis)).normalized()
    x_axis = -palm
    y_axis = axis.cross(x_axis).normalized()
    x_axis = y_axis.cross(axis).normalized()
    rot = Matrix((x_axis, y_axis, axis)).transposed().to_4x4()
    centre = Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
    me.transform(Matrix.Translation(tip) @ rot @ Matrix.Scale(s, 4) @ centre)
    mirrored_copy()
    say("arms: length", round(length, 3), "scale", round(s, 3), "axis", [round(v, 3) for v in axis])
elif mode == "legs":
    leg_c, leg_p = centroid("RightLowerLeg_OuterCage")
    foot_c, foot_p = centroid("RightFoot_OuterCage")
    flo, fhi = bounds(foot_p)
    llo, lhi = bounds(leg_p)
    s = size / (hi.z - lo.z)
    # the heel at the back of the leg, the sole on the foot's bottom
    me.transform(Matrix.Translation(Vector((leg_c.x, lhi.y, flo.z + bottom))) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -hi.y, -lo.z))))
    mirrored_copy()
    say("legs: height", size, "scale", round(s, 3))
armor = bpy.context.view_layer.objects.active
armor.data.update()

# the outer cage: each vertex pushed out along its normal past the piece, where the piece is close
bvh = BVHTree.FromObject(armor, bpy.context.evaluated_depsgraph_get())
iw, ow_inv = inner.matrix_world, outer.matrix_world.inverted()
moved = 0
MARGIN, REACH = 0.04, 0.9
for i, v in enumerate(inner.data.vertices):
    p = iw @ v.co
    n = (iw.to_3x3() @ v.normal).normalized()
    far = None
    origin = p - n * 0.02
    travelled = 0.0
    while travelled < REACH:
        hit = bvh.ray_cast(origin, n, REACH - travelled)
        if hit[0] is None:
            break
        d = (hit[0] - p).dot(n)
        far = d if far is None else max(far, d)
        travelled += (hit[0] - origin).length + 0.001
        origin = hit[0] + n * 0.001
    target = p
    if far is not None and far > -0.05:
        target = p + n * (max(far, 0) + MARGIN)
        moved += 1
    outer.data.vertices[i].co = ow_inv @ target
outer.data.update()
say("outer cage vertices pushed out:", moved, "of", len(inner.data.vertices))

for o in list(bpy.data.objects):
    if o not in (armor, inner, outer):
        bpy.data.objects.remove(o)
armor.name = name
inner.name = name + "CageIn"
outer.name = name + "CageOut"
cage_mat = bpy.data.materials.new("CageMat")
for o in (inner, outer):
    o.data.name = o.name
    o.data.materials.clear()
    o.data.materials.append(cage_mat)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_apply=True)
for o in (armor, inner, outer):
    c = [o.matrix_world @ v.co for v in o.data.vertices]
    lo, hi = bounds(c)
    say(o.name, "centre", [round((lo[k] + hi[k]) / 2, 4) for k in range(3)], "size", [round(hi[k] - lo[k], 4) for k in range(3)])
