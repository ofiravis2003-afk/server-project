--!strict
-- Moves animals that have no animation clips (the giant rats) by hand, on players' screens:
-- a fast bouncing scurry while they run, a crouch-and-lunge when they bite, and a jolt when hit.
-- The server tells us about bites and hits by counting them up in attributes (LungeCount / FlinchCount);
-- the body is turned through the model's "BodyMotor" (root part to body), in the root's directions.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LUNGE_TIME = 0.32
local FLINCH_TIME = 0.22

local Scurry = {}

type Runner = {
	Root: BasePart,
	Motor: Motor6D,
	Phase: number,
	LungeAt: number,
	FlinchAt: number,
	Lunges: number,
	Flinches: number,
}

local runners: { [Model]: Runner } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local motor = model:FindFirstChild("BodyMotor", true) :: Motor6D?
	if not root or not motor then
		return
	end
	runners[model] = {
		Root = root,
		Motor = motor,
		Phase = math.random() * 10,
		LungeAt = -1,
		FlinchAt = -1,
		Lunges = model:GetAttribute("LungeCount") or 0,
		Flinches = model:GetAttribute("FlinchCount") or 0,
	}
end

function Scurry.Start()
	for _, model in CollectionService:GetTagged("Scurry") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("Scurry"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Scurry"):Connect(function(model)
		runners[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for model, runner in runners do
			if not model.Parent then
				runners[model] = nil
				continue
			end
			local lunges = model:GetAttribute("LungeCount") or 0
			if lunges ~= runner.Lunges then
				runner.Lunges = lunges
				runner.LungeAt = now
			end
			local flinches = model:GetAttribute("FlinchCount") or 0
			if flinches ~= runner.Flinches then
				runner.Flinches = flinches
				runner.FlinchAt = now
			end

			local velocity = runner.Root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local moving = speed > 1
			runner.Phase += dt * (if moving then 16 + speed * 0.8 else 2.5)

			-- Running: a low, quick skitter: small fast bobs, the body swishing side to side.
			-- Standing: sniffing (a little nose bob) and a slow breath.
			local lift, pitch, swish
			if moving then
				lift = math.abs(math.sin(runner.Phase)) * 0.12 - 0.08
				pitch = math.sin(runner.Phase * 2) * 0.04
				swish = math.sin(runner.Phase) * 0.12
			else
				lift = math.sin(runner.Phase) * 0.03
				pitch = math.max(0, math.sin(runner.Phase * 3.1)) * 0.06
				swish = math.sin(runner.Phase * 0.7) * 0.05
			end
			local push = 0

			local sinceLunge = now - runner.LungeAt
			if sinceLunge < LUNGE_TIME then
				local t = sinceLunge / LUNGE_TIME
				if t < 0.35 then
					-- crouch back, nose up
					local k = t / 0.35
					push += 0.7 * k
					pitch += 0.25 * k
				else
					-- spring forward, nose down, then settle
					local k = (t - 0.35) / 0.65
					local out = math.sin(k * math.pi)
					push += 0.7 * (1 - k) - 1.8 * out
					pitch += 0.25 * (1 - k) - 0.3 * out
					lift += 0.4 * out
				end
			end
			local sinceFlinch = now - runner.FlinchAt
			if sinceFlinch < FLINCH_TIME then
				local out = math.sin((sinceFlinch / FLINCH_TIME) * math.pi)
				push += 0.8 * out
				pitch += 0.3 * out
			end

			runner.Motor.Transform = CFrame.new(0, lift, push) * CFrame.Angles(pitch, swish, 0)
		end
	end)
end

return Scurry
