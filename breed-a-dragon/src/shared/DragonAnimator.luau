--!strict
-- Makes a dragon from DragonBuilder fly: wings flap at the shoulders, the body bobs
-- with each wingbeat, and the tail sways at its base.
--
--   local rig = DragonAnimator.Rig(model)              -- once, right after building
--   local parts, frames = DragonAnimator.Pose(rig, where, phase, effort)
--   workspace:BulkMoveTo(parts, frames)                -- fast, for dragons in the world
--   DragonAnimator.Apply(rig, where, phase, effort)    -- simple, for dragons in a ViewportFrame
--
-- `where` is the CFrame the dragon's pivot should be at, `phase` is the wingbeat angle
-- (keep adding dt * DragonAnimator.FlapSpeed(effort) to it), and `effort` goes from
-- 0 (hovering) to 1 (flying fast).

local FLAP_SPEED_IDLE = 5.5 -- radians per second
local FLAP_SPEED_FAST = 10
local FLAP_ANGLE_IDLE = math.rad(30)
local FLAP_ANGLE_FAST = math.rad(44)
local FLAP_REST = math.rad(2) -- centre of the wingbeat, on top of the wings' built-in lift
local TAIL_SWAY = math.rad(9)
local BOB_HEIGHT = 0.12 -- per stud of dragon height, so big dragons bob more

type Joint = string -- "Body", "LeftWing", "RightWing" or "Tail"

export type Rig = {
	Parts: { BasePart },
	Joints: { Joint },
	Offsets: { CFrame }, -- each part relative to its joint
	JointFrames: { [Joint]: CFrame }, -- each joint relative to the pivot
	Frames: { CFrame }, -- reused output buffer
	Height: number,
}

local DragonAnimator = {}

function DragonAnimator.FlapSpeed(effort: number): number
	return FLAP_SPEED_IDLE + (FLAP_SPEED_FAST - FLAP_SPEED_IDLE) * effort
end

function DragonAnimator.Rig(model: Model): Rig
	local pivot = model:GetPivot()
	local jointFrames: { [Joint]: CFrame } = { Body = CFrame.identity }
	for _, name in { "LeftWing", "RightWing", "Tail" } do
		local jointPart = model:FindFirstChild(name .. "Joint")
		if jointPart and jointPart:IsA("BasePart") then
			jointFrames[name] = pivot:ToObjectSpace(jointPart.CFrame)
		end
	end

	local parts, joints, offsets, frames = {}, {}, {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local tag = part:GetAttribute("Rig")
			local joint: Joint = if type(tag) == "string" and jointFrames[tag] then tag else "Body"
			table.insert(parts, part)
			table.insert(joints, joint)
			table.insert(offsets, (pivot * jointFrames[joint]):ToObjectSpace(part.CFrame))
			table.insert(frames, part.CFrame)
		end
	end

	local _, size = model:GetBoundingBox()
	return {
		Parts = parts,
		Joints = joints,
		Offsets = offsets,
		JointFrames = jointFrames,
		Frames = frames,
		Height = size.Y,
	}
end

-- Where every part should be for this moment of the wingbeat.
function DragonAnimator.Pose(rig: Rig, where: CFrame, phase: number, effort: number): ({ BasePart }, { CFrame })
	local wave = math.sin(phase)
	local flap = FLAP_REST + wave * (FLAP_ANGLE_IDLE + (FLAP_ANGLE_FAST - FLAP_ANGLE_IDLE) * effort)
	-- The downstroke lifts the body: it is highest when the wings are at the bottom
	-- and lowest when they are at the top.
	local body = where * CFrame.new(0, -wave * BOB_HEIGHT * rig.Height * 0.5, 0)

	local jointWorld: { [Joint]: CFrame } = { Body = body }
	local jointFrames = rig.JointFrames
	-- Rotating around the joint's Z axis (front-to-back) lifts the wing: +angle on the right, -angle on the left.
	local rightWing, leftWing, tail = jointFrames["RightWing"], jointFrames["LeftWing"], jointFrames["Tail"]
	if rightWing then
		jointWorld["RightWing"] = body * rightWing * CFrame.Angles(0, 0, flap)
	end
	if leftWing then
		jointWorld["LeftWing"] = body * leftWing * CFrame.Angles(0, 0, -flap)
	end
	if tail then
		jointWorld["Tail"] = body * tail * CFrame.Angles(0, math.sin(phase * 0.45) * TAIL_SWAY, 0)
	end

	local frames = rig.Frames
	for i, joint in rig.Joints do
		frames[i] = jointWorld[joint] * rig.Offsets[i]
	end
	return rig.Parts, frames
end

-- Same as Pose, but moves the parts directly. Fine for one dragon (e.g. in a ViewportFrame).
function DragonAnimator.Apply(rig: Rig, where: CFrame, phase: number, effort: number)
	local parts, frames = DragonAnimator.Pose(rig, where, phase, effort)
	for i, part in parts do
		part.CFrame = frames[i]
	end
end

return DragonAnimator
