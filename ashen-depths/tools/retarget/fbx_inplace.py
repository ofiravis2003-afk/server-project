# Takes a Mixamo clip's walk off the ground plane by editing the binary FBX itself: the forward drift is removed
# from the Hips translation curves and nothing else in the file changes. (Going through Blender instead rewrites
# the bones' axes, and the clip then folds the legs up on a rig imported from Mixamo's own file.)
# Run: python fbx_inplace.py <in.fbx> <out.fbx>
import struct
import sys
import zlib

src, out = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
assert data[:21] == b"Kaydara FBX Binary  \x00"
version = struct.unpack("<I", data[23:27])[0]
WIDE = version >= 7500
HEAD = struct.Struct("<QQQB") if WIDE else struct.Struct("<IIIB")
NULL = HEAD.size


class Node:
    def __init__(self, name):
        self.name, self.props, self.kids, self.has_null = name, [], [], False


def read_prop(pos):
    t = chr(data[pos])
    pos += 1
    if t in "YCILFD":
        fmt = {"Y": "<h", "C": "<B", "I": "<i", "L": "<q", "F": "<f", "D": "<d"}[t]
        size = struct.calcsize(fmt)
        return (t, struct.unpack(fmt, data[pos : pos + size])[0]), pos + size
    if t in "fdlib":
        n, enc, clen = struct.unpack("<III", data[pos : pos + 12])
        pos += 12
        raw = data[pos : pos + clen]
        pos += clen
        if enc == 1:
            raw = zlib.decompress(raw)
        code = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "B"}[t]
        return (t, list(struct.unpack(f"<{n}{code}", raw))), pos
    if t in "SR":
        n = struct.unpack("<I", data[pos : pos + 4])[0]
        return (t, data[pos + 4 : pos + 4 + n]), pos + 4 + n
    raise ValueError(t)


def read_node(pos):
    end, nprops, _, nlen = HEAD.unpack(data[pos : pos + HEAD.size])
    pos += HEAD.size
    if end == 0:
        return None, pos
    node = Node(data[pos : pos + nlen])
    pos += nlen
    for _ in range(nprops):
        prop, pos = read_prop(pos)
        node.props.append(prop)
    while pos < end:
        kid, pos = read_node(pos)
        if kid is None:
            node.has_null = True
            break
        node.kids.append(kid)
    return node, end


def write_prop(prop):
    t, v = prop
    if t in "YCILFD":
        return t.encode() + struct.pack({"Y": "<h", "C": "<B", "I": "<i", "L": "<q", "F": "<f", "D": "<d"}[t], v)
    if t in "fdlib":
        code = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "B"}[t]
        raw = struct.pack(f"<{len(v)}{code}", *v)
        packed = zlib.compress(raw)
        return t.encode() + struct.pack("<III", len(v), 1, len(packed)) + packed
    return t.encode() + struct.pack("<I", len(v)) + v


def write_node(node, offset):
    props = b"".join(write_prop(p) for p in node.props)
    body_at = offset + HEAD.size + len(node.name) + len(props)
    body = b""
    for kid in node.kids:
        body += write_node(kid, body_at + len(body))
    if node.has_null:
        body += b"\x00" * NULL
    end = body_at + len(body)
    return HEAD.pack(end, len(node.props), len(props), len(node.name)) + node.name + props + body


top, pos = [], 27
while True:
    node, pos = read_node(pos)
    if node is None:
        break
    top.append(node)
footer = data[pos:]


def child(node, name):
    return next(k for k in node.kids if k.name == name)


objects = next(n for n in top if n.name == b"Objects")
connections = next(n for n in top if n.name == b"Connections")
hips = next(k for k in objects.kids if k.name == b"Model" and k.props[1][1].startswith(b"mixamorig:Hips"))
hips_id = hips.props[0][1]
links = [(c.props[1][1], c.props[2][1], c.props[3][1] if len(c.props) > 3 else b"") for c in connections.kids]
t_node = next(a for a, b, p in links if b == hips_id and p == b"Lcl Translation")
curves = {p: a for a, b, p in links if b == t_node}
by_id = {k.props[0][1]: k for k in objects.kids if k.name == b"AnimationCurve"}

drift = {}
for axis, cid in curves.items():
    values = child(by_id[cid], b"KeyValueFloat").props[0][1]
    drift[axis] = values[-1] - values[0]
axis = max(drift, key=lambda a: abs(drift[a]))
curve = by_id[curves[axis]]
values = child(curve, b"KeyValueFloat")
times = child(curve, b"KeyTime").props[0][1]
span = times[-1] - times[0]
values.props[0] = ("f", [v - drift[axis] * (t - times[0]) / span for v, t in zip(values.props[0][1], times)])

result = data[:27]
for node in top:
    result += write_node(node, len(result))
open(out, "wb").write(result + data[pos - NULL :])  # the closing null record and the file's footer, as they were
print({k.decode(): round(v, 2) for k, v in drift.items()}, "removed from", axis.decode(), "keys", len(times))
