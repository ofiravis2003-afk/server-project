# exec'd inside the Blender scripts with `mesh` in scope. Two weight fixes for the Bone Warden:
#  1. The skull (an ellipsoid round the head, chin included) goes with the Head bone, fading out at its edge.
#  2. The cape (everything behind the legs) mostly goes with the Hips instead of the legs, so it hangs free
#     instead of stretching with each step.
import math
SKULL_C = (0.0, -0.09, 1.60)
SKULL_R = (0.12, 0.14, 0.20)
LEG_KEEP = 0.2
CAPE_Y0, CAPE_Y1 = 0.04, 0.09
LEGS = ["mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:RightUpLeg", "mixamorig:RightLeg"]

def _smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)

def _set(v, weights):
    total = sum(weights.values()) or 1
    for gi in [g.group for g in v.groups]:
        if gi not in weights:
            mesh.vertex_groups[gi].remove([v.index])
    for gi, w in weights.items():
        mesh.vertex_groups[gi].add([v.index], w / total, "REPLACE")

_head = mesh.vertex_groups["mixamorig:Head"].index
_hips = mesh.vertex_groups["mixamorig:Hips"].index
_legs = {mesh.vertex_groups[n].index for n in LEGS if n in mesh.vertex_groups}
_mw = mesh.matrix_world
skull_n = cape_n = 0
for v in mesh.data.vertices:
    p = _mw @ v.co
    old = {g.group: g.weight for g in v.groups}
    total = sum(old.values()) or 1
    old = {k: w / total for k, w in old.items()}
    d = math.sqrt(sum(((p[i] - SKULL_C[i]) / SKULL_R[i]) ** 2 for i in range(3)))
    t = 1 - _smooth(0.8, 1.0, d)
    if t > 0:
        new = {k: w * (1 - t) for k, w in old.items()}
        new[_head] = new.get(_head, 0) + t
        _set(v, new)
        skull_n += 1
        continue
    c = _smooth(CAPE_Y0, CAPE_Y1, p.y) * (1 - _smooth(0.85, 0.97, p.z))
    leg = sum(w for k, w in old.items() if k in _legs)
    if c > 0 and leg > 0:
        moved = leg * (1 - LEG_KEEP) * c
        new = {k: (w * (1 - (1 - LEG_KEEP) * c) if k in _legs else w) for k, w in old.items()}
        new[_hips] = new.get(_hips, 0) + moved
        _set(v, new)
        cape_n += 1
print_fix = f"skull {skull_n} cape {cape_n}"
