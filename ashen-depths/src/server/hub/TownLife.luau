--!strict
-- Small signs of life over Emberhold: smoke from the hearths and the forge, autumn leaves drifting down from the
-- oaks, motes of dust in the late sun over the square, and a few birds circling high above. (The birdsong and
-- the odd caw are the client's: Audio.)
-- The birds are a Studio-generated model, ServerStorage.TownProps.Crow; without it the sky stays empty.

local ServerStorage = game:GetService("ServerStorage")

local LEAF = "rbxassetid://91366758896375" -- a plain leaf, tinted by the emitter's colors
local HEARTHS = { GuildHall = true, Tavern = true, HouseA = true, HouseB = true, MagicShop = true }

local TownLife = {}

local function anchorPart(name: string, cframe: CFrame, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function smoke(parent: Instance, at: Vector3, dark: boolean)
	local p = anchorPart("HearthSmoke", CFrame.new(at), Vector3.new(1, 1, 1), parent)
	local e = Instance.new("ParticleEmitter")
	local tone = if dark then Color3.fromRGB(70, 66, 62) else Color3.fromRGB(190, 186, 180)
	e.Color = ColorSequence.new(tone)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = if dark then 3 else 1.6
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(0.8, 0.3, 0.4) -- a light breeze
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.Parent = p
end

local function leaves(parent: Instance, tree: Model)
	local box, size = tree:GetBoundingBox()
	local canopy = math.max(size.X, size.Z) * 0.7
	local p = anchorPart("FallingLeaves", box * CFrame.new(0, size.Y * 0.2, 0), Vector3.new(canopy, 1, canopy), parent)
	local e = Instance.new("ParticleEmitter")
	e.Texture = LEAF
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(214, 120, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(196, 150, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 70, 30)),
	})
	e.Size = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(6, 10)
	e.Rate = 1.5
	e.Speed = NumberRange.new(0.5, 1.2)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(0.6, -0.9, 0.3)
	e.Drag = 1.2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = p
end

local function dust(parent: Instance, center: Vector3, radius: number)
	local p = anchorPart("SunMotes", CFrame.new(center + Vector3.new(0, 6, 0)), Vector3.new(radius * 2, 8, radius * 2), parent)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 226, 170))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.09), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.3)
	e.Lifetime = NumberRange.new(5, 9)
	e.Rate = 25
	e.Speed = NumberRange.new(0.1, 0.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
end

-- A few birds wheeling on wide circles over the town, each at its own height and pace.
local function birds(parent: Instance, center: Vector3)
	local folder = ServerStorage:FindFirstChild("TownProps")
	local source = folder and folder:FindFirstChild("Crow")
	if not source or not source:IsA("Model") then
		return
	end
	local rng = Random.new()
	local flock = {}
	for i = 1, 5 do
		local bird = source:Clone()
		bird.Parent = parent
		table.insert(flock, {
			Model = bird,
			Radius = rng:NextNumber(45, 90),
			Height = rng:NextNumber(55, 80),
			Speed = rng:NextNumber(0.06, 0.11) * (if i % 2 == 0 then -1 else 1),
			Phase = rng:NextNumber(0, math.pi * 2),
		})
	end
	task.spawn(function()
		local t = 0
		while true do
			t += task.wait(1 / 20)
			for _, b in flock do
				local a = b.Phase + t * b.Speed
				local pos = center + Vector3.new(math.cos(a) * b.Radius, b.Height + math.sin(t * 0.3 + b.Phase) * 4, math.sin(a) * b.Radius)
				local ahead = a + 0.05 * math.sign(b.Speed)
				local next = center + Vector3.new(math.cos(ahead) * b.Radius, b.Height, math.sin(ahead) * b.Radius)
				-- (the model's beak points along -X) and banked into the turn
				b.Model:PivotTo(CFrame.lookAt(pos, next) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(18) * math.sign(b.Speed), 0, 0))
			end
		end
	end)
end

function TownLife.Start(town: Model)
	local folder = Instance.new("Folder")
	folder.Name = "TownLife"
	folder.Parent = workspace
	for _, piece in town:GetDescendants() do
		if piece:IsA("Model") then
			if HEARTHS[piece.Name] then
				local box, size = piece:GetBoundingBox()
				smoke(folder, (box * CFrame.new(size.X * 0.2, size.Y / 2 - 1, 0)).Position, false)
			elseif piece.Name == "ForgeBuilding" then
				local box, size = piece:GetBoundingBox()
				smoke(folder, (box * CFrame.new(0, size.Y / 2 - 1, 0)).Position, true)
			elseif piece.Name == "OakTree" then
				leaves(folder, piece)
			end
		end
	end
	local well = town:FindFirstChild("GreatWell", true)
	local center = if well and well:IsA("Model") then well:GetPivot().Position else Vector3.zero
	dust(folder, center, 30)
	birds(folder, center)
end

return TownLife
