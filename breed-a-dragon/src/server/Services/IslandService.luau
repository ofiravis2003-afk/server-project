--!strict
-- Ember Isle: the floating island every player starts on, built from code around the spawn point.
-- Also builds the four locked islands floating in the distance ("Coming Soon"), sets a warm
-- sky, and catches players who fall off the edge.
--
-- Layout, seen from above (the spawn point is the middle):
--   crystals in a ring around the spawn, Egg Shop to the south (+Z), Elder Ember to the west (-X),
--   and (Studio only) the dragon gallery to the north (-Z).
-- Everything here is decoration made of simple parts. Nicer trees and rocks from the Toolbox
-- can be added later by hand in Studio (put them in a folder that isn't called "EmberIsle").

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(script.Parent.Parent.Util.Ground)

local GRASS = Color3.fromRGB(110, 160, 75)
local PATH = Color3.fromRGB(205, 170, 120)
local ROCK = Color3.fromRGB(105, 95, 100)
local DARK_ROCK = Color3.fromRGB(70, 62, 70)
local TRUNK = Color3.fromRGB(105, 70, 45)
-- Ember Isle's trees are a mix of green and autumn colours.
local LEAVES = {
	Color3.fromRGB(95, 150, 65),
	Color3.fromRGB(120, 165, 70),
	Color3.fromRGB(225, 130, 50),
	Color3.fromRGB(205, 85, 50),
	Color3.fromRGB(240, 180, 70),
}

type IslandStyle = {
	Top: Color3,
	TopMaterial: Enum.Material,
	Leaves: { Color3 },
	Trees: number,
	Rocks: number,
}

type LockedIsland = {
	Name: string,
	Offset: Vector3, -- from the spawn point
	Radius: number,
	Barrier: Color3,
	Style: IslandStyle,
}

-- Islands 2-5: seen from Ember Isle, not reachable yet.
local LOCKED_ISLANDS: { LockedIsland } = {
	{
		Name = "Frostpeak Isle",
		Offset = Vector3.new(300, 45, -170),
		Radius = 55,
		Barrier = Color3.fromRGB(170, 220, 255),
		Style = {
			Top = Color3.fromRGB(235, 245, 255),
			TopMaterial = Enum.Material.Snow,
			Leaves = { Color3.fromRGB(200, 230, 245), Color3.fromRGB(150, 200, 230) },
			Trees = 10,
			Rocks = 6,
		},
	},
	{
		Name = "Verdant Hollow",
		Offset = Vector3.new(-310, 10, -150),
		Radius = 60,
		Barrier = Color3.fromRGB(120, 255, 150),
		Style = {
			Top = Color3.fromRGB(60, 140, 60),
			TopMaterial = Enum.Material.Grass,
			Leaves = { Color3.fromRGB(40, 120, 50), Color3.fromRGB(70, 160, 60) },
			Trees = 16,
			Rocks = 4,
		},
	},
	{
		Name = "Storm Spire",
		Offset = Vector3.new(-250, 80, 260),
		Radius = 45,
		Barrier = Color3.fromRGB(150, 120, 255),
		Style = {
			Top = Color3.fromRGB(80, 75, 100),
			TopMaterial = Enum.Material.Slate,
			Leaves = { Color3.fromRGB(110, 90, 160) },
			Trees = 4,
			Rocks = 10,
		},
	},
	{
		Name = "Starfall Reach",
		Offset = Vector3.new(270, 120, 260),
		Radius = 50,
		Barrier = Color3.fromRGB(255, 120, 220),
		Style = {
			Top = Color3.fromRGB(70, 50, 120),
			TopMaterial = Enum.Material.Sand,
			Leaves = { Color3.fromRGB(255, 150, 230), Color3.fromRGB(150, 200, 255) },
			Trees = 8,
			Rocks = 6,
		},
	},
}

local IslandService = {}

local spawnCenter = Vector3.zero

local function newPart(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- An upright disc: `top` is the Y of its top face.
local function disc(parent: Instance, name: string, at: Vector3, radius: number, height: number, top: number): Part
	-- Cylinders run along X; turn it upright.
	return newPart(
		parent,
		name,
		Enum.PartType.Cylinder,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(at.X, top - height / 2, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	)
end

local function tree(parent: Instance, base: Vector3, rng: Random, leaves: { Color3 })
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(8, 13)
	local trunk = newPart(
		model,
		"Trunk",
		Enum.PartType.Cylinder,
		Vector3.new(height, 1.6, 1.6),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	)
	trunk.Material = Enum.Material.Wood
	trunk.Color = TRUNK
	local color = leaves[rng:NextInteger(1, #leaves)]
	for i = 1, 3 do
		local size = rng:NextNumber(6, 9) * (if i == 1 then 1.2 else 0.9)
		local offset = if i == 1
			then Vector3.new(0, height, 0)
			else Vector3.new(rng:NextNumber(-2.5, 2.5), height - rng:NextNumber(0.5, 2), rng:NextNumber(-2.5, 2.5))
		local leaf = newPart(model, "Leaves", Enum.PartType.Ball, Vector3.one * size, CFrame.new(base + offset))
		leaf.Material = Enum.Material.Grass
		leaf.Color = color
		leaf.CanCollide = false
	end
	model.Parent = parent
end

local function rock(parent: Instance, base: Vector3, rng: Random)
	local size = rng:NextNumber(3, 7)
	local part = newPart(
		parent,
		"Rock",
		Enum.PartType.Block,
		Vector3.new(size * rng:NextNumber(1, 1.6), size * rng:NextNumber(0.6, 1), size),
		CFrame.new(base + Vector3.new(0, size * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
	)
	part.Material = Enum.Material.Slate
	part.Color = ROCK
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = part
end

-- The floating island itself: a flat top on a rocky cone that hangs into the sky.
-- `keepOut(point)` says where no trees or rocks may go (paths, the shop...).
local function island(
	parent: Instance,
	center: Vector3,
	radius: number,
	style: IslandStyle,
	seed: number,
	keepOut: ((Vector3) -> boolean)?
)
	local top = disc(parent, "Top", center, radius, 4, center.Y)
	top.Material = style.TopMaterial
	top.Color = style.Top

	-- Layers of rock, each narrower, so the underside narrows to a point.
	local layers = { { 1.03, 7 }, { 0.85, 12 }, { 0.62, 14 }, { 0.4, 14 }, { 0.2, 12 }, { 0.07, 10 } }
	local y = center.Y - 3
	for i, layer in layers do
		local part = disc(parent, "Cliff", center, radius * layer[1], layer[2], y)
		part.Material = Enum.Material.Rock
		part.Color = if i % 2 == 0 then DARK_ROCK else ROCK
		y -= layer[2] * 0.8
	end

	local rng = Random.new(seed)
	local function spot(minRadius: number): Vector3?
		for _ = 1, 20 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(minRadius, radius - 6)
			local point = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			if not keepOut or not keepOut(point) then
				return point
			end
		end
		return nil
	end
	for _ = 1, style.Trees do
		local point = spot(radius * 0.25)
		if point then
			tree(parent, point, rng, style.Leaves)
		end
	end
	for _ = 1, style.Rocks do
		local point = spot(radius * 0.2)
		if point then
			rock(parent, point, rng)
		end
	end

	-- A few small rocks floating around the edge.
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local distance = radius + rng:NextNumber(10, 25)
		local size = rng:NextNumber(4, 9)
		local chunk = newPart(
			parent,
			"FloatingRock",
			Enum.PartType.Block,
			Vector3.new(size, size * 0.8, size),
			CFrame.new(
				center + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-25, 5), math.sin(angle) * distance)
			) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1))
		)
		chunk.Material = Enum.Material.Rock
		chunk.Color = ROCK
	end
end

-- Distance from a point to the line between `a` and `b`, ignoring height.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local flat = Vector3.new(1, 0, 1)
	local ab, ap = (b - a) * flat, (point - a) * flat
	local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
	return (ap - ab * t).Magnitude
end

local function path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flatTo = Vector3.new(to.X, from.Y, to.Z)
	local length = (flatTo - from).Magnitude
	local part = newPart(
		parent,
		"Path",
		Enum.PartType.Block,
		Vector3.new(width, 0.2, length),
		CFrame.lookAt((from + flatTo) / 2, flatTo) + Vector3.new(0, 0.1, 0)
	)
	part.Material = Enum.Material.Ground
	part.Color = PATH
	part.CanCollide = false
end

local function buildEmberIsle(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "EmberIsle"

	local center = spawnCenter
	local shop = center + Vector3.new(0, 0, 40)
	local elder = center + Config.Island.ElderOffset
	local galleryOn = Config.Dev.DragonGallery and RunService:IsStudio()

	local plaza = disc(folder, "Plaza", center, 32, 0.2, center.Y + 0.1)
	plaza.Material = Enum.Material.Ground
	plaza.Color = PATH
	plaza.CanCollide = false
	path(folder, center, shop, 10)
	path(folder, center, elder, 10)

	-- The rock Elder Ember stands on.
	local perch = disc(folder, "ElderPerch", elder, 12, 3, center.Y + 3)
	perch.Material = Enum.Material.Slate
	perch.Color = ROCK

	island(
		folder,
		center,
		Config.Island.Radius,
		{
			Top = GRASS,
			TopMaterial = Enum.Material.Grass,
			Leaves = LEAVES,
			Trees = 34,
			Rocks = 14,
		},
		7,
		function(point)
			local offset = point - center
			return (offset * Vector3.new(1, 0, 1)).Magnitude < 38 -- plaza and crystals
				or (point - shop).Magnitude < 28
				or (point - elder).Magnitude < 22
				or distanceToSegment(point, center, shop) < 8
				or distanceToSegment(point, center, elder) < 8
				or (galleryOn and offset.Z < -36 and math.abs(offset.X) < 60)
		end
	)

	folder.Parent = workspace
	return folder
end

local function buildLockedIslands()
	local folder = Instance.new("Folder")
	folder.Name = "LockedIslands"
	for i, info in LOCKED_ISLANDS do
		local center = spawnCenter + info.Offset
		local model = Instance.new("Model")
		model.Name = info.Name
		island(model, center, info.Radius, info.Style, 100 + i, nil)

		-- A shimmering dome shows it is sealed.
		local dome = newPart(
			model,
			"Barrier",
			Enum.PartType.Ball,
			Vector3.one * info.Radius * 2.3,
			CFrame.new(center + Vector3.new(0, 5, 0))
		)
		dome.Material = Enum.Material.ForceField
		dome.Color = info.Barrier
		dome.CanCollide = false
		dome.CastShadow = false

		local sign = newPart(
			model,
			"Sign",
			Enum.PartType.Block,
			Vector3.one,
			CFrame.new(center + Vector3.new(0, info.Radius * 1.2 + 10, 0))
		)
		sign.Transparency = 1
		sign.CanCollide = false
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(280, 80)
		billboard.LightInfluence = 0
		billboard.MaxDistance = 3000
		billboard.Parent = sign
		for row, text in { `🔒 {info.Name}`, "Coming Soon" } do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0, (row - 1) * 0.55)
			label.Size = UDim2.fromScale(1, if row == 1 then 0.55 else 0.45)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = if row == 1 then Color3.new(1, 1, 1) else info.Barrier
			label.TextStrokeTransparency = 0.2
			label.Text = text
			label.Parent = billboard
		end

		model.Parent = folder
	end
	folder.Parent = workspace
end

-- A warm late-afternoon sky with a light haze, so the far islands fade into the distance.
local function setSky()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 130, 125)
	if not Lighting:FindFirstChildWhichIsA("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromRGB(255, 210, 180)
		atmosphere.Decay = Color3.fromRGB(190, 130, 110)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
end

-- Players who fall off the island are put back on the spawn point.
local function rescueFallers()
	local limit = spawnCenter.Y - Config.Island.FallRescueDepth
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") and root.Position.Y < limit then
				character:PivotTo(CFrame.new(spawnCenter + Vector3.new(0, 5, 0)))
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

function IslandService.Start()
	spawnCenter = Ground.GetSpawnCenter()
	if Config.Island.RemoveBaseplate then
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
	end
	buildEmberIsle()
	buildLockedIslands()
	setSky()
	task.spawn(rescueFallers)
end

return IslandService
