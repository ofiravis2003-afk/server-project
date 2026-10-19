# Gets a Tripo armor piece ready for Studio: one mesh, upright, centred, facing -Y (Roblox -Z), textures kept.
#   head / chest: as they come (Tripo faces -Y), only centred.
#   hand: turned so its long axis (the forearm) runs up Z with the hand at the bottom, then `flip` (turn it
#         end over end) and `roll` (degrees round its axis) as needed after a look at the renders.
#   boot: turned round Z so the toe points -Y.
# `cut` drops faces below that height (model units, after centring), e.g. a display stand under a vest.
# Run: blender -b --factory-startup --python prep_armor.py -- <in.glb> <out.glb> <kind> [flip 0|1] [roll deg] [cut z]
import bpy, sys, math, bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out, kind = argv[0], argv[1], argv[2]
flip = len(argv) > 3 and argv[3] == "1"
roll = float(argv[4]) if len(argv) > 4 else 0.0
cut = float(argv[5]) if len(argv) > 5 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
# free it from any parent empties, with its transform applied
world = obj.matrix_world.copy()
obj.parent = None
obj.matrix_world = world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o)

me = obj.data
pts = [v.co.copy() for v in me.vertices]

def principal_axis(points):
    n = len(points)
    c = sum(points, Vector()) / n
    cov = [[0.0] * 3 for _ in range(3)]
    for p in points:
        d = p - c
        for i in range(3):
            for j in range(3):
                cov[i][j] += d[i] * d[j]
    v = Vector((1, 1, 1)).normalized()
    for _ in range(60):  # power iteration
        w = Vector((sum(cov[0][j] * v[j] for j in range(3)), sum(cov[1][j] * v[j] for j in range(3)), sum(cov[2][j] * v[j] for j in range(3))))
        v = w.normalized()
    return c, v

rot = Matrix.Identity(4)
if kind == "hand":
    c, axis = principal_axis(pts)
    # the hand end: the end whose last fifth spreads widest round the axis
    proj = [(p - c).dot(axis) for p in pts]
    lo, hi = min(proj), max(proj)
    def spread(sel):
        q = [pts[i] - c - axis * proj[i] for i in sel]
        return sum(v.length for v in q) / max(len(q), 1)
    top = [i for i, t in enumerate(proj) if t > hi - (hi - lo) * 0.2]
    bottom = [i for i, t in enumerate(proj) if t < lo + (hi - lo) * 0.2]
    # make +axis point from the hand to the cuff (the cuff is the open, rounder end)
    if spread(top) > spread(bottom):
        axis = -axis
    rot = axis.rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
    if flip:
        rot = Matrix.Rotation(math.pi, 4, "X") @ rot
    rot = Matrix.Rotation(math.radians(roll), 4, "Z") @ rot
elif kind == "boot":
    zs = [p.z for p in pts]
    z0, z1 = min(zs), max(zs)
    foot = [p for p in pts if p.z < z0 + (z1 - z0) * 0.15]
    shaft = [p for p in pts if p.z > z0 + (z1 - z0) * 0.5]
    fc = sum(foot, Vector()) / len(foot)
    sc = sum(shaft, Vector()) / len(shaft)
    toe = Vector((fc.x - sc.x, fc.y - sc.y, 0))
    angle = math.atan2(toe.y, toe.x) - math.atan2(-1, 0)  # turn the toe to -Y
    rot = Matrix.Rotation(-angle, 4, "Z")
    rot = Matrix.Rotation(math.radians(roll), 4, "Z") @ rot
me.transform(rot)

# centre: x/y on the bounding box middle, z from 0
co = [v.co for v in me.vertices]
lo = Vector((min(v.x for v in co), min(v.y for v in co), min(v.z for v in co)))
hi = Vector((max(v.x for v in co), max(v.y for v in co), max(v.z for v in co)))
me.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))

if cut is not None:
    bm = bmesh.new()
    bm.from_mesh(me)
    doomed = [f for f in bm.faces if f.calc_center_median().z < cut]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    co = [v.co for v in me.vertices]
    lo = Vector((min(v.x for v in co), min(v.y for v in co), min(v.z for v in co)))
    hi = Vector((max(v.x for v in co), max(v.y for v in co), max(v.z for v in co)))
    me.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
me.update()

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False)
co = [v.co for v in me.vertices]
with open(out + ".txt", "w") as f:
    f.write(f"size {max(v.x for v in co) - min(v.x for v in co):.3f} {max(v.y for v in co) - min(v.y for v in co):.3f} {max(v.z for v in co):.3f}")
