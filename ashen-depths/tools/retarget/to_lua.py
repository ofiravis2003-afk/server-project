# Turns retarget.py's JSON into a Luau snippet that builds a KeyframeSequence named <name> in ServerStorage.R15Clips.
# Usage: python to_lua.py <in.json> <name> <out.luau> [step] [loop|once] [start end] [upper]
#   step:  keep every n-th frame;  start/end: cut the clip to this window (seconds, re-timed from 0)
#   upper: arms, head and torso only (the legs keep walking); the torso keeps the hips' turn
import json, sys
src, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
step = int(sys.argv[4]) if len(sys.argv) > 4 else 2
loop = len(sys.argv) > 5 and sys.argv[5] == "loop"
cut = (float(sys.argv[6]), float(sys.argv[7])) if len(sys.argv) > 7 else None
upper = len(sys.argv) > 8 and sys.argv[8] == "upper"
j = json.load(open(src))
allf = j["frames"]
if cut:
    allf = [f for f in allf if cut[0] - 1e-6 <= f["t"] <= cut[1] + 1e-6]
    t0 = allf[0]["t"]
    allf = [{"t": f["t"] - t0, "poses": f["poses"]} for f in allf]

def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx, aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]

if upper:
    LEGS = {"LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
    for f in allf:
        p = f["poses"]
        p["UpperTorso"] = [0, 0, 0] + qmul(p["LowerTorso"][3:], p["UpperTorso"][3:])
        for k in LEGS:
            p.pop(k, None)
frames = allf[::step]
if allf[-1] is not frames[-1]:
    frames.append(allf[-1])
TREE = {
    "HumanoidRootPart": ["LowerTorso"],
    "LowerTorso": ["UpperTorso", "LeftUpperLeg", "RightUpperLeg"],
    "UpperTorso": ["Head", "LeftUpperArm", "RightUpperArm"],
    "LeftUpperArm": ["LeftLowerArm"], "LeftLowerArm": ["LeftHand"],
    "RightUpperArm": ["RightLowerArm"], "RightLowerArm": ["RightHand"],
    "LeftUpperLeg": ["LeftLowerLeg"], "LeftLowerLeg": ["LeftFoot"],
    "RightUpperLeg": ["RightLowerLeg"], "RightLowerLeg": ["RightFoot"],
}
rows = []
for f in frames:
    p = f["poses"]
    rows.append("{%.4f,{%s}}" % (f["t"], ",".join("%s={%s}" % (k, ",".join("%.4f" % x for x in v)) for k, v in p.items())))
lua = f'''local NAME = "{name}"
local LOOP = {"true" if loop else "false"}
local TREE = {{{",".join('%s={%s}' % (k, ",".join('"%s"' % c for c in v)) for k, v in TREE.items())}}}
local FRAMES = {{{",".join(rows)}}}
local folder = game.ServerStorage:FindFirstChild("R15Clips") or Instance.new("Folder")
folder.Name = "R15Clips"
folder.Parent = game.ServerStorage
local old = folder:FindFirstChild(NAME) if old then old:Destroy() end
local ks = Instance.new("KeyframeSequence")
ks.Name = NAME
ks.Loop = LOOP
ks.Priority = Enum.AnimationPriority.Action
for _, fr in FRAMES do
	local kf = Instance.new("Keyframe")
	kf.Time = fr[1]
	-- Parts this clip leaves alone (an upper-body clip's legs) get no pose at all, so the walk keeps moving them;
	-- their children hang on the nearest pose above.
	local function add(parentPose, partName)
		local v = fr[2][partName]
		local holder = parentPose
		if v or partName == "HumanoidRootPart" then
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.CFrame = if v then CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7]) else CFrame.identity
			pose.Parent = parentPose
			holder = pose
		end
		for _, child in TREE[partName] or {{}} do
			add(holder, child)
		end
	end
	add(kf, "HumanoidRootPart")
	kf.Parent = ks
end
ks.Parent = folder
return NAME .. ": " .. #FRAMES .. " keyframes, " .. FRAMES[#FRAMES][1] .. "s"
'''
open(out, "w").write(lua)
print(len(lua), "chars")
