--!strict
-- Long weapons held in both hands (the Gravekeeper's shovel): every frame, on players' screens, the weapon is
-- turned in the main hand so its shaft runs on through the other hand, whatever the animation does with them.
-- The prop (tagged "TwoHanded", attribute OtherHand = the other hand's bone) carries on its Grip attachment:
--   Axis:  the mesh's long axis, toward the end the other hand holds   Width: the blade's width direction
--   At:    where the main hand grips, in the mesh                     Palm:  the main palm, in its hand bone's space

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TwoHandGrip = {}

type Held = {
	Model: Model,
	Grip: Attachment,
	MainBone: Bone,
	OtherBone: Bone,
	MeshFrame: CFrame,
	At: Vector3,
	Palm: Vector3,
}

local held: { [Model]: Held } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	task.defer(function()
		local handle = instance:FindFirstChild("Handle") :: BasePart?
		local grip = handle and handle:FindFirstChild("Grip") :: Attachment?
		local constraint = handle and handle:FindFirstChildWhichIsA("RigidConstraint")
		local mainBone = constraint and constraint.Attachment0
		local owner = instance.Parent
		local otherName = instance:GetAttribute("OtherHand")
		local otherBone = owner and type(otherName) == "string" and owner:FindFirstChild(otherName, true)
		if not (grip and mainBone and mainBone:IsA("Bone") and otherBone and otherBone:IsA("Bone")) then
			return
		end
		local axis = (grip:GetAttribute("Axis") :: Vector3).Unit
		local width = grip:GetAttribute("Width") :: Vector3
		-- The weapon's own frame: X toward the blade end (away from the other hand), Y across the blade.
		local toBlade = -axis
		width = (width - toBlade * width:Dot(toBlade)).Unit
		held[instance] = {
			Model = instance,
			Grip = grip,
			MainBone = mainBone,
			OtherBone = otherBone,
			MeshFrame = CFrame.fromMatrix(Vector3.zero, toBlade, width, toBlade:Cross(width)),
			At = grip:GetAttribute("At") :: Vector3,
			Palm = grip:GetAttribute("Palm") :: Vector3,
		}
	end)
end

function TwoHandGrip.Start()
	for _, model in CollectionService:GetTagged("TwoHanded") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("TwoHanded"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("TwoHanded"):Connect(function(model)
		held[model :: Model] = nil
	end)

	RunService.PreRender:Connect(function()
		for model, h in held do
			if not model.Parent then
				held[model] = nil
				continue
			end
			local main = h.MainBone.TransformedWorldCFrame
			-- The other hand's grip point: a little along its fingers from the wrist.
			local other = (h.OtherBone.TransformedWorldCFrame * CFrame.new(h.Palm)).Position
			local toOther = main:PointToObjectSpace(other) - h.Palm
			if toOther.Magnitude < 0.2 then
				continue
			end
			local toBlade = -toOther.Unit
			local up = Vector3.yAxis
			local across = up - toBlade * up:Dot(toBlade)
			across = if across.Magnitude > 0.05 then across.Unit else Vector3.xAxis
			local handFrame = CFrame.fromMatrix(Vector3.zero, toBlade, across, toBlade:Cross(across))
			local turn = handFrame * h.MeshFrame:Inverse()
			h.Grip.CFrame = CFrame.new(h.At) * turn:Inverse() * CFrame.new(-h.Palm)
		end
	end)
end

return TwoHandGrip
