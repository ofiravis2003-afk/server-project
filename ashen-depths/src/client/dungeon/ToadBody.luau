--!strict
-- Moves the Rotgut Toad, which has no rig, by hand on players' screens: it heaves as it breathes, hops as it
-- walks, and squashes and stretches through its moves. The server names each move in attributes (BodyMove, how long
-- in BodyMoveTime, counted up in BodyMoveCount), and counts bites and hits (LungeCount / FlinchCount) as for the rats.
-- The body turns through the model's "BodyMotor"; the mesh's Size does the squashing, with the feet kept on the floor.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LUNGE_TIME = 0.95 -- (a bite lands 0.7 seconds in: the server's Windup)
local FLINCH_TIME = 0.2
local LEAP_HEIGHT = 15
local LAND_TIME = 0.4 -- how long a leap's landing squashes it

local ToadBody = {}

type Toad = {
	Root: BasePart,
	Humanoid: Humanoid?,
	Motor: Motor6D,
	Mesh: BasePart,
	Size: Vector3,
	Phase: number,
	Hop: number,
	Moves: number,
	Move: string?,
	MoveAt: number,
	MoveTime: number,
	Lunges: number,
	LungeAt: number,
	Flinches: number,
	FlinchAt: number,
}

local toads: { [Model]: Toad } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local motor = model:FindFirstChild("BodyMotor", true) :: Motor6D?
	local mesh = motor and motor.Part1
	if not root or not motor or not mesh then
		return
	end
	toads[model] = {
		Root = root,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Motor = motor,
		Mesh = mesh,
		Size = mesh.Size,
		Phase = math.random() * 10,
		Hop = 0,
		Moves = model:GetAttribute("BodyMoveCount") or 0,
		Move = nil,
		MoveAt = -100,
		MoveTime = 1,
		Lunges = model:GetAttribute("LungeCount") or 0,
		LungeAt = -100,
		Flinches = model:GetAttribute("FlinchCount") or 0,
		FlinchAt = -100,
	}
end

local function step(model: Model, toad: Toad, dt: number, now: number)
	local moves = model:GetAttribute("BodyMoveCount") or 0
	if moves ~= toad.Moves then
		toad.Moves = moves
		toad.Move = model:GetAttribute("BodyMove")
		toad.MoveTime = model:GetAttribute("BodyMoveTime") or 1
		toad.MoveAt = now
	end
	local lunges = model:GetAttribute("LungeCount") or 0
	if lunges ~= toad.Lunges then
		toad.Lunges = lunges
		toad.LungeAt = now
	end
	local flinches = model:GetAttribute("FlinchCount") or 0
	if flinches ~= toad.Flinches then
		toad.Flinches = flinches
		toad.FlinchAt = now
	end

	local alive = not toad.Humanoid or toad.Humanoid.Health > 0
	local velocity = toad.Root.AssemblyLinearVelocity
	local moving = alive and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1

	-- Walking: heavy hops, one every 0.7 seconds; each landing finishes before it stops. Still: slow breaths.
	toad.Phase += dt
	if moving or toad.Hop > 0 then
		toad.Hop += dt / 0.7
		if toad.Hop >= 1 then
			toad.Hop = if moving then toad.Hop % 1 else 0
		end
	end
	local air = math.sin(toad.Hop * math.pi)
	local lift = air * 2.2
	local pitch = air * 0.1
	local push, roll = 0, 0
	local tall = 1 + air * 0.08 - (1 - math.min(toad.Hop * 8, 1)) * (if toad.Hop > 0 then 0.1 else 0)
	local wide = 1 - air * 0.04
	if alive then
		local breath = math.sin(toad.Phase * 2.2)
		tall += breath * 0.015
		wide += breath * 0.025
	end

	local since = now - toad.MoveAt
	local s = since / toad.MoveTime
	local move = toad.Move
	if move == "Leap" then
		if s < 0.35 then
			local k = s / 0.35
			tall -= 0.3 * k
			wide += 0.18 * k
			pitch += 0.15 * k
		elseif s < 1 then
			local k = (s - 0.35) / 0.65
			local arc = math.sin(k * math.pi)
			lift += arc * LEAP_HEIGHT
			tall += 0.2 * arc
			wide -= 0.1 * arc
			pitch += 0.3 * (1 - k * 2)
		elseif since < toad.MoveTime + LAND_TIME then
			local k = 1 - (since - toad.MoveTime) / LAND_TIME
			tall -= 0.28 * k
			wide += 0.2 * k
		end
	elseif move == "Shove" and s < 1 then
		-- rears back, then throws its belly forward
		if s < 0.6 then
			local k = s / 0.6
			pitch += 0.28 * k
			push += 1.2 * k
		else
			local k = math.sin((s - 0.6) / 0.4 * math.pi)
			pitch += 0.28 * (1 - (s - 0.6) / 0.4) - 0.25 * k
			push += 1.2 * (1 - (s - 0.6) / 0.4) - 3.5 * k
			wide += 0.1 * k
		end
	elseif move == "Croak" and s < 1 then
		-- head up, throat swelling and shaking
		local k = math.min(s * 5, 1) * math.min((1 - s) * 5, 1)
		pitch += 0.3 * k
		wide += (0.14 + math.sin(since * 24) * 0.05) * k
		tall += 0.06 * k
		roll += math.sin(since * 31) * 0.02 * k
	elseif move == "Tongue" and s < 1 then
		-- settles low, aiming, shaking with the effort
		pitch -= 0.14 * s
		tall -= 0.14 * s
		wide += 0.08 * s
		roll += math.sin(since * 40) * 0.015 * s
	elseif move == "Gulp" and s < 1 then
		-- something is fighting in its belly
		wide += 0.14 + math.sin(since * 13) * 0.06
		tall -= 0.05
		roll += math.sin(since * 9) * 0.06
		push += math.sin(since * 11) * 0.3
	end

	local sinceLunge = now - toad.LungeAt
	if sinceLunge < LUNGE_TIME then
		local t = sinceLunge / LUNGE_TIME
		if t < 0.6 then
			local k = t / 0.6
			pitch += 0.25 * k
			push += 1.5 * k
			tall -= 0.08 * k
		else
			local k = (t - 0.6) / 0.4
			local out = math.sin(k * math.pi)
			pitch += 0.25 * (1 - k) - 0.4 * out
			push += 1.5 * (1 - k) - 4.5 * out
		end
	end
	local sinceFlinch = now - toad.FlinchAt
	if sinceFlinch < FLINCH_TIME then
		local out = math.sin((sinceFlinch / FLINCH_TIME) * math.pi)
		push += 0.35 * out
		tall -= 0.04 * out
		wide += 0.04 * out
	end

	toad.Mesh.Size = Vector3.new(toad.Size.X * wide, toad.Size.Y * tall, toad.Size.Z * wide)
	-- the mesh shrinks toward its middle: back down to keep the feet on the floor
	lift -= (1 - tall) * toad.Size.Y / 2
	toad.Motor.Transform = CFrame.new(0, lift, push) * CFrame.Angles(pitch, 0, roll)
end

function ToadBody.Start()
	for _, model in CollectionService:GetTagged("Toad") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("Toad"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Toad"):Connect(function(model)
		toads[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for model, toad in toads do
			if not model.Parent then
				toads[model] = nil
				continue
			end
			step(model, toad, dt, now)
		end
	end)
end

return ToadBody
