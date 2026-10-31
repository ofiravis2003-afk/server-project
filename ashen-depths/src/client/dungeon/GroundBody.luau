--!strict
-- Keeps a body's feet on the floor through clips that lift them (Mixamo's Mutant clips were made to hop and sway
-- above the ground they land on): every frame the lower foot is found, and the whole body is lowered through its
-- "BodyMotor" until that foot touches the floor. Drawn on players' screens only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FOOT_HEIGHT = 0.1 -- how far above the floor the toe bone sits
local SPEED = 18 -- how fast the body follows (higher = stiffer)

local GroundBody = {}

type Body = { Root: BasePart, Humanoid: Humanoid, Motor: Motor6D, Left: Bone, Right: Bone, Drop: number }

local bodies: { [Model]: Body } = {}

local add: (Instance) -> ()
function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local motor = model:FindFirstChild("BodyMotor", true) :: Motor6D?
	local left = model:FindFirstChild("mixamorig:LeftToeBase", true) :: Bone?
	local right = model:FindFirstChild("mixamorig:RightToeBase", true) :: Bone?
	if root and humanoid and motor and left and right then
		bodies[model] = { Root = root, Humanoid = humanoid, Motor = motor, Left = left, Right = right, Drop = 0 }
	elseif model.Parent then
		task.delay(0.5, add, model) -- (its bones are still arriving)
	end
end

function GroundBody.Start()
	for _, model in CollectionService:GetTagged("Grounded") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("Grounded"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Grounded"):Connect(function(model)
		bodies[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		for model, body in bodies do
			if not model.Parent then
				bodies[model] = nil
				continue
			end
			local wanted = 0
			if body.Humanoid.Health > 0 then
				local floorY = body.Root.Position.Y - body.Humanoid.HipHeight - body.Root.Size.Y / 2
				local foot = math.min(body.Left.TransformedWorldCFrame.Position.Y, body.Right.TransformedWorldCFrame.Position.Y)
				-- (a bone's world position doesn't count the motor's Transform, so this is the height before the drop)
				wanted = math.max(foot - floorY - FOOT_HEIGHT, 0)
			end
			body.Drop += (wanted - body.Drop) * math.min(dt * SPEED, 1)
			body.Motor.Transform = CFrame.new(0, -body.Drop, 0)
		end
	end)
end

return GroundBody
