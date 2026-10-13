# Turns retarget.py's JSON into a Luau snippet that builds a KeyframeSequence named <name> in ServerStorage.R15Clips.
# Usage: python to_lua.py <in.json> <name> <out.luau> [keep_every_n_frames] [loop]
import json, sys
src, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
step = int(sys.argv[4]) if len(sys.argv) > 4 else 2
loop = len(sys.argv) > 5 and sys.argv[5] == "loop"
j = json.load(open(src))
frames = j["frames"][::step]
if j["frames"][-1] is not frames[-1]:
    frames.append(j["frames"][-1])
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
	local function add(parentPose, partName)
		local pose = Instance.new("Pose")
		pose.Name = partName
		local v = fr[2][partName]
		pose.CFrame = if v then CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7]) else CFrame.identity
		pose.Weight = if partName == "HumanoidRootPart" then 0 else 1
		pose.Parent = parentPose
		for _, child in TREE[partName] or {{}} do
			add(pose, child)
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
