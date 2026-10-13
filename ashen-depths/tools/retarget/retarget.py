# Retargets a Mixamo (X Bot, "Without Skin") FBX animation onto a Roblox R15 rig.
# Run: blender -b --factory-startup --python retarget.py -- <in.fbx> <out.json> [inplace]
# Output: {"fps", "length", "frames": [{"t", "poses": {PartName: [x,y,z, qx,qy,qz,qw]}}]}
# where each pose is the Motor6D.Transform of the joint that moves that part (all R15 rest rotations are identity).
import bpy, sys, json
from mathutils import Matrix, Vector, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
inplace = len(argv) > 2 and argv[2] == "inplace"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src, automatic_bone_orientation=False)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
scene = bpy.context.scene
action = arm.animation_data.action
f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
fps = scene.render.fps

# Blender (Z up, character facing -Y, its left +X) -> Roblox (Y up, facing -Z, its left -X)
C = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
CT = C.transposed()

def B(name):
    return "mixamorig:" + name

# R15 part -> (source bone, bone it points toward, R15 part's own rest direction, parent part)
MAP = {
    "LowerTorso": ("Hips", "Spine", (0, 1, 0), None),
    "UpperTorso": ("Spine2", "Neck", (0, 1, 0), "LowerTorso"),
    "Head": ("Head", "HeadTop_End", (0, 1, 0), "UpperTorso"),
    "LeftUpperArm": ("LeftArm", "LeftForeArm", (0, -1, 0), "UpperTorso"),
    "LeftLowerArm": ("LeftForeArm", "LeftHand", (0, -1, 0), "LeftUpperArm"),
    "LeftHand": ("LeftHand", "LeftHandMiddle1", (0, -1, 0), "LeftLowerArm"),
    "RightUpperArm": ("RightArm", "RightForeArm", (0, -1, 0), "UpperTorso"),
    "RightLowerArm": ("RightForeArm", "RightHand", (0, -1, 0), "RightUpperArm"),
    "RightHand": ("RightHand", "RightHandMiddle1", (0, -1, 0), "RightLowerArm"),
    "LeftUpperLeg": ("LeftUpLeg", "LeftLeg", (0, -1, 0), "LowerTorso"),
    "LeftLowerLeg": ("LeftLeg", "LeftFoot", (0, -1, 0), "LeftUpperLeg"),
    "LeftFoot": ("LeftFoot", "LeftToeBase", (0, 0, -1), "LeftLowerLeg"),
    "RightUpperLeg": ("RightUpLeg", "RightLeg", (0, -1, 0), "LowerTorso"),
    "RightLowerLeg": ("RightLeg", "RightFoot", (0, -1, 0), "RightUpperLeg"),
    "RightFoot": ("RightFoot", "RightToeBase", (0, 0, -1), "RightLowerLeg"),
}

mw = arm.matrix_world

def rot_r(m4):
    """World rotation of a bone matrix, in Roblox axes."""
    r = m4.to_3x3().normalized()
    return (C @ r @ CT).to_quaternion()

def pos_r(v):
    return C @ v

# Rest (bind) pose
rest_rot, rest_head = {}, {}
for b in arm.data.bones:
    rest_rot[b.name] = rot_r(mw @ b.matrix_local)
    rest_head[b.name] = pos_r(mw @ b.head_local)

hip_height = (rest_head[B("LeftUpLeg")].y + rest_head[B("RightUpLeg")].y) / 2
SCALE = 2.19 / hip_height  # R15: hips 2.19 studs above the floor

# S: turns the R15 part from its rest (arms down) to the source's rest direction (T-pose)
S = {}
for part, (bone, child, rdir, _) in MAP.items():
    d_src = (rest_head[B(child)] - rest_head[B(bone)]).normalized()
    S[part] = Vector(rdir).rotation_difference(d_src)

frames = []
first_hips = None
hand_track = {"R": [], "L": []}
for f in range(f0, f1 + 1):
    scene.frame_set(f)
    world = {}
    for part, (bone, child, rdir, parent) in MAP.items():
        pb = arm.pose.bones[B(bone)]
        q = rot_r(mw @ pb.matrix)
        delta = q @ rest_rot[B(bone)].inverted()
        world[part] = delta @ S[part]
    poses = {}
    for part, (bone, child, rdir, parent) in MAP.items():
        parent_q = world[parent] if parent else Quaternion()
        local = parent_q.inverted() @ world[part]
        poses[part] = [0, 0, 0, local.x, local.y, local.z, local.w]
    hips = pos_r(mw @ arm.pose.bones[B("Hips")].head)
    if first_hips is None:
        first_hips = hips.copy()
    offset = Vector((hips.x - first_hips.x, hips.y - rest_head[B("Hips")].y, hips.z - first_hips.z)) * SCALE
    if inplace:
        offset.x = 0
        offset.z = 0
    poses["LowerTorso"][0:3] = [offset.x, offset.y, offset.z]
    frames.append({"t": (f - f0) / fps, "poses": poses})
    for side, bone in (("R", "RightHand"), ("L", "LeftHand")):
        hand_track[side].append(pos_r(mw @ arm.pose.bones[B(bone)].head))

# When each hand moves fastest (the moment a blow lands or a spell is thrown), in seconds.
peaks = {}
for side, track in hand_track.items():
    best, best_t = 0, 0
    for i in range(1, len(track)):
        speed = (track[i] - track[i - 1]).length * fps
        if speed > best:
            best, best_t = speed, i / fps
    peaks[side] = {"t": best_t, "speed": best * SCALE}

with open(out, "w") as fh:
    json.dump({"fps": fps, "length": (f1 - f0) / fps, "peaks": peaks, "frames": frames}, fh)
