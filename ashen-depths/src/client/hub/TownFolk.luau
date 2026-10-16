--!strict
-- Puts the townsfolk's held things in their hands on each player's screen: a prop marked with the attributes
-- HeldBy (the townsperson's name), Bone (the hand bone) and Grip (how far up the shaft the hand closes, 0-1)
-- follows that hand every frame. (The server doesn't move a standing figure's bones, so this is done here.)

local RunService = game:GetService("RunService")

local TownFolk = {}

type Held = { Prop: Model, Hand: Bone, Offset: CFrame, Fingers: { Bone }, Upright: CFrame, GripInHand: Vector3, GripToMiddle: Vector3 }

-- The hand closes round the shaft: each finger joint bent this far (the idle clips keep the hand open).
local FINGER_CURL = CFrame.Angles(0, 0, math.rad(70))

local function attach(prop: Model, town: Instance): Held?
	local owner = town:FindFirstChild(prop:GetAttribute("HeldBy") :: string, true)
	local hand = owner and owner:FindFirstChild(prop:GetAttribute("Bone") :: string, true)
	if not hand or not hand:IsA("Bone") then
		return nil
	end
	local _, size = prop:GetBoundingBox()
	local length = (prop:GetAttribute("Length") :: number?) or size.Y
	local grip = (prop:GetAttribute("Grip") :: number?) or 0.4
	-- Upright, with the hand closed round the shaft at `grip` of its length from the bottom, in the palm
	-- (a little way along the fingers from the wrist), and facing the way its owner faces.
	local handNow = hand.TransformedWorldCFrame
	local palm = (handNow * CFrame.new(0, 0.08 * (owner :: Model):GetScale(), 0)).Position
	local facing = (owner :: Model):GetPivot().Rotation
	local upright = CFrame.new(palm) * facing * CFrame.new(0, (0.5 - grip) * length, 0)
	local fingers = {}
	for _, joint in { "Index1", "Index2", "Index3" } do
		local bone = (owner :: Model):FindFirstChild(`{hand.Name}{joint}`, true)
		if bone and bone:IsA("Bone") then
			table.insert(fingers, bone)
		end
	end
	return {
		Prop = prop,
		Hand = hand,
		Offset = handNow:Inverse() * upright,
		Fingers = fingers,
		Upright = facing,
		GripInHand = handNow:PointToObjectSpace(palm),
		GripToMiddle = Vector3.new(0, (0.5 - grip) * length, 0),
	}
end

function TownFolk.Start()
	local town = workspace:WaitForChild("Town", 120)
	if not town then
		return
	end
	-- The town streams in a bit at a time, so a held prop is attached once its owner's hand has arrived
	-- (and its owner has started breathing, so the grip is measured in a standing pose).
	local held: { Held } = {}
	local attached: { [Model]: boolean } = {}
	task.spawn(function()
		while town.Parent do
			for _, prop in town:GetDescendants() do
				if prop:IsA("Model") and prop:GetAttribute("HeldBy") and not attached[prop] then
					local owner = town:FindFirstChild(prop:GetAttribute("HeldBy") :: string, true)
					local controller = owner and owner:FindFirstChildOfClass("AnimationController")
					local animator = controller and controller:FindFirstChildOfClass("Animator")
					if animator and #animator:GetPlayingAnimationTracks() > 0 then
						local h = attach(prop, town)
						if h then
							attached[prop] = true
							table.insert(held, h)
						end
					end
				end
			end
			task.wait(1)
		end
	end)
	RunService.RenderStepped:Connect(function()
		for _, h in held do
			if h.Prop.Parent then
				for _, finger in h.Fingers do
					finger.Transform = FINGER_CURL
				end
				-- the shaft runs through the middle of the closed fingers (most of the way from the wrist to
				-- the curled fingertips), and only leans a little as the hand turns
				local follow = h.Hand.TransformedWorldCFrame * h.Offset
				local grip = h.Hand.TransformedWorldCFrame.Position * 0.25
				for _, finger in h.Fingers do
					grip += finger.TransformedWorldCFrame.Position * (0.75 / #h.Fingers)
				end
				local lean = h.Upright:Lerp(follow.Rotation, 0.15)
				h.Prop:PivotTo(CFrame.new(grip) * lean * CFrame.new(h.GripToMiddle))
			end
		end
	end)
end

return TownFolk
