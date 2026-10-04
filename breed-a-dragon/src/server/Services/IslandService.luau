--!strict
-- Ember Isle: the floating island every player starts on, built from code around the spawn point.
-- Also builds the four locked islands floating in the distance ("Coming Soon"), sets a warm
-- realistic sky, and catches players who fall off the edge.
--
-- The ground, cliffs, rocks and tree tops are Roblox Terrain (real grass, dirt and rock
-- textures, with grass blades), not plastic parts.
--
-- Your own trees and rocks: put models from the Toolbox in a Folder called "IslandAssets"
-- in ServerStorage. Models with "Tree" in the name replace the terrain trees, "Rock" the
-- rocks and "Bush" the bushes; the island scatters copies of them (random turn and size).
--
-- Layout, seen from above (the spawn point is the middle):
--   crystals in a ring around the spawn, Egg Shop to the south (+Z), Elder Ember to the west (-X).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(script.Parent.Parent.Util.Ground)

local TRUNK = Color3.fromRGB(80, 60, 45)

type IslandStyle = {
	Top: Enum.Material, -- the ground
	Edge: Enum.Material, -- the band just under the ground
	Cliff: Enum.Material, -- the rock underneath
	Rock: Enum.Material, -- boulders
	Leaves: Enum.Material?, -- tree tops (nil = no trees)
	Trees: number,
	Rocks: number,
	Bushes: number,
}

type LockedIsland = {
	Name: string,
	Offset: Vector3, -- from the spawn point
	Radius: number,
	Barrier: Color3,
	Style: IslandStyle,
}

type Assets = { Tree: { Instance }, Rock: { Instance }, Bush: { Instance } }

local EMBER_ISLE: IslandStyle = {
	Top = Enum.Material.Grass,
	Edge = Enum.Material.Ground,
	Cliff = Enum.Material.Rock,
	Rock = Enum.Material.Rock,
	Leaves = Enum.Material.LeafyGrass,
	Trees = 30,
	Rocks = 16,
	Bushes = 26,
}

-- Islands 2-5: seen from Ember Isle, not reachable yet.
local LOCKED_ISLANDS: { LockedIsland } = {
	{
		Name = "Frostpeak Isle",
		Offset = Vector3.new(300, 45, -170),
		Radius = 55,
		Barrier = Color3.fromRGB(170, 220, 255),
		Style = {
			Top = Enum.Material.Snow,
			Edge = Enum.Material.Glacier,
			Cliff = Enum.Material.Rock,
			Rock = Enum.Material.Glacier,
			Leaves = Enum.Material.Snow,
			Trees = 10,
			Rocks = 6,
			Bushes = 0,
		},
	},
	{
		Name = "Verdant Hollow",
		Offset = Vector3.new(-310, 10, -150),
		Radius = 60,
		Barrier = Color3.fromRGB(120, 255, 150),
		Style = {
			Top = Enum.Material.LeafyGrass,
			Edge = Enum.Material.Mud,
			Cliff = Enum.Material.Rock,
			Rock = Enum.Material.Rock,
			Leaves = Enum.Material.Grass,
			Trees = 18,
			Rocks = 4,
			Bushes = 12,
		},
	},
	{
		Name = "Storm Spire",
		Offset = Vector3.new(-250, 80, 260),
		Radius = 45,
		Barrier = Color3.fromRGB(150, 120, 255),
		Style = {
			Top = Enum.Material.Basalt,
			Edge = Enum.Material.Slate,
			Cliff = Enum.Material.Slate,
			Rock = Enum.Material.Basalt,
			Leaves = nil,
			Trees = 0,
			Rocks = 14,
			Bushes = 0,
		},
	},
	{
		Name = "Starfall Reach",
		Offset = Vector3.new(270, 120, 260),
		Radius = 50,
		Barrier = Color3.fromRGB(255, 120, 220),
		Style = {
			Top = Enum.Material.Salt,
			Edge = Enum.Material.Limestone,
			Cliff = Enum.Material.Limestone,
			Rock = Enum.Material.Pavement,
			Leaves = Enum.Material.Glacier,
			Trees = 6,
			Rocks = 8,
			Bushes = 0,
		},
	},
}

-- Natural colours for the terrain materials (they apply to the whole map).
local TERRAIN_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(96, 128, 58),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(78, 104, 48),
	[Enum.Material.Ground] = Color3.fromRGB(110, 90, 66),
	[Enum.Material.Rock] = Color3.fromRGB(105, 100, 96),
	[Enum.Material.Cobblestone] = Color3.fromRGB(130, 120, 110),
}

local IslandService = {}

local spawnCenter = Vector3.zero

local function terrain(): Terrain
	return workspace:FindFirstChildOfClass("Terrain") :: Terrain
end

-- A cylinder of terrain whose top face is at height `top`.
local function fillDisc(at: Vector3, radius: number, height: number, top: number, material: Enum.Material)
	terrain():FillCylinder(CFrame.new(at.X, top - height / 2, at.Z), height, radius, material)
end

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

-- Toolbox models the developer put in ServerStorage/IslandAssets, sorted by kind.
local function findAssets(): Assets
	local assets: Assets = { Tree = {}, Rock = {}, Bush = {} }
	local folder = ServerStorage:FindFirstChild("IslandAssets")
	if not folder then
		return assets
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			for kind, list in assets :: any do
				if child.Name:lower():find(kind:lower()) then
					table.insert(list, child)
					break
				end
			end
		end
	end
	return assets
end

-- Puts a copy of a Toolbox model on the ground at `base`, turned and sized at random.
local function placeAsset(parent: Instance, template: Instance, base: Vector3, rng: Random)
	local copy = template:Clone()
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if copy:IsA("Model") then
		copy:ScaleTo(copy:GetScale() * rng:NextNumber(0.85, 1.25))
		copy:PivotTo(CFrame.new(base) * turn)
		-- Stand it on the ground, whatever its pivot is.
		local box, size = copy:GetBoundingBox()
		copy:PivotTo(copy:GetPivot() + Vector3.new(0, base.Y - (box.Position.Y - size.Y / 2) - 0.3, 0))
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	elseif copy:IsA("BasePart") then
		copy.CFrame = CFrame.new(base + Vector3.new(0, copy.Size.Y / 2 - 0.3, 0)) * turn
		copy.Anchored = true
	end
	copy.Parent = parent
end

-- A tree: a slightly leaning wooden trunk with a few branches, under a clump of leaves.
local function tree(parent: Instance, base: Vector3, rng: Random, leaves: Enum.Material)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(13, 20)
	local width = rng:NextNumber(1.4, 2.1)
	local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.08, 0.08))
	local foot = CFrame.new(base - Vector3.new(0, 1, 0)) * lean
	local trunk = newPart(
		model,
		"Trunk",
		Enum.PartType.Cylinder,
		Vector3.new(height, width, width),
		foot * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	trunk.Material = Enum.Material.Wood
	trunk.Color = TRUNK

	local crown = (foot * CFrame.new(0, height, 0)).Position
	local branches = rng:NextInteger(2, 3)
	for i = 1, branches do
		local yaw = i / branches * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local start = (foot * CFrame.new(0, height * rng:NextNumber(0.55, 0.75), 0)).Position
		local tip = crown + Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * rng:NextNumber(3.5, 5) - Vector3.new(0, 1, 0)
		local branch = newPart(
			model,
			"Branch",
			Enum.PartType.Cylinder,
			Vector3.new((tip - start).Magnitude, width * 0.45, width * 0.45),
			CFrame.lookAt((start + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0)
		)
		branch.Material = Enum.Material.Wood
		branch.Color = TRUNK
		-- Leaves around the end of each branch, and a big clump on top.
		terrain():FillBall(tip + Vector3.new(0, 1, 0), rng:NextNumber(3.5, 5), leaves)
	end
	terrain():FillBall(crown + Vector3.new(0, 1.5, 0), rng:NextNumber(5, 6.5), leaves)
	model.Parent = parent
end

-- A boulder: two or three overlapping lumps of rock, half sunk into the ground.
local function boulder(base: Vector3, rng: Random, material: Enum.Material)
	local size = rng:NextNumber(2.5, 5)
	terrain():FillBall(base + Vector3.new(0, size * 0.2, 0), size, material)
	for _ = 1, rng:NextInteger(1, 2) do
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size
		terrain():FillBall(base + offset, size * rng:NextNumber(0.5, 0.8), material)
	end
end

-- The floating island: grass on a band of dirt, with rocky cliffs narrowing to a point below.
-- `keepOut(point)` says where no trees or rocks may go (paths, the shop...).
local function island(
	parent: Instance,
	center: Vector3,
	radius: number,
	style: IslandStyle,
	seed: number,
	assets: Assets,
	keepOut: ((Vector3) -> boolean)?
)
	local rng = Random.new(seed)
	local y = center.Y

	-- Rock underneath first; each layer narrower, with lumps so the cliffs aren't a perfect cone.
	local layers = { { 0.98, 10 }, { 0.82, 14 }, { 0.6, 16 }, { 0.38, 16 }, { 0.18, 14 }, { 0.06, 10 } }
	local top = y - 4
	for _, layer in layers do
		local layerRadius = radius * layer[1]
		fillDisc(center, layerRadius, layer[2], top, style.Cliff)
		local lumps = math.max(4, math.floor(layerRadius / 6))
		for i = 1, lumps do
			local angle = i / lumps * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local lump = center
				+ Vector3.new(
					math.cos(angle) * layerRadius,
					top - layer[2] * rng:NextNumber(0.3, 0.8) - y,
					math.sin(angle) * layerRadius
				)
			terrain():FillBall(lump, rng:NextNumber(4, 9), style.Cliff)
		end
		top -= layer[2] * 0.75
	end

	-- Dirt band, then the grass top with a bumpy edge.
	fillDisc(center, radius + 1, 6, y - 2, style.Edge)
	fillDisc(center, radius, 4, y, style.Top)
	for i = 1, math.floor(radius / 3) do
		local angle = i / math.floor(radius / 3) * math.pi * 2
		local edge = center + Vector3.new(math.cos(angle) * (radius - 2), -3, math.sin(angle) * (radius - 2))
		terrain():FillBall(edge, rng:NextNumber(3, 6), style.Top)
	end

	local function spot(minRadius: number): Vector3?
		for _ = 1, 20 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(minRadius, radius - 7)
			local point = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			if not keepOut or not keepOut(point) then
				return point
			end
		end
		return nil
	end

	local function scatter(count: number, minRadius: number, own: { Instance }, make: (Vector3) -> ())
		for _ = 1, count do
			local point = spot(minRadius)
			if point then
				if #own > 0 then
					placeAsset(parent, own[rng:NextInteger(1, #own)], point, rng)
				else
					make(point)
				end
			end
		end
	end
	local leaves = style.Leaves
	local codeTrees = Config.Island.CodeTrees
	if leaves and (codeTrees or #assets.Tree > 0) then
		scatter(style.Trees, radius * 0.25, assets.Tree, function(point)
			tree(parent, point, rng, leaves)
		end)
	end
	scatter(style.Rocks, radius * 0.2, assets.Rock, function(point)
		boulder(point, rng, style.Rock)
	end)
	scatter(if codeTrees or #assets.Bush > 0 then style.Bushes else 0, radius * 0.3, assets.Bush, function(point)
		terrain():FillBall(point + Vector3.new(0, 0.5, 0), rng:NextNumber(1.8, 3), Enum.Material.LeafyGrass)
	end)

	-- A few small rocks floating around the edge.
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local distance = radius + rng:NextNumber(12, 28)
		local at = center + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-30, 0), math.sin(angle) * distance)
		terrain():FillBall(at, rng:NextNumber(3, 6), style.Cliff)
		terrain():FillBall(at - Vector3.new(0, 3, 0), rng:NextNumber(2, 3.5), style.Cliff)
	end
end

-- Distance from a point to the line between `a` and `b`, ignoring height.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local flat = Vector3.new(1, 0, 1)
	local ab, ap = (b - a) * flat, (point - a) * flat
	local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
	return (ap - ab * t).Magnitude
end

-- A dirt path on top of the grass (replaces the grass, so it stays level).
local function path(from: Vector3, to: Vector3, width: number)
	local flatTo = Vector3.new(to.X, from.Y, to.Z)
	local length = (flatTo - from).Magnitude
	local middle = (from + flatTo) / 2 - Vector3.new(0, 2, 0)
	terrain():FillBlock(
		CFrame.lookAt(middle, middle + (flatTo - from)),
		Vector3.new(width, 4, length),
		Enum.Material.Ground
	)
end

local function buildEmberIsle(assets: Assets): Folder
	local folder = Instance.new("Folder")
	folder.Name = "EmberIsle"

	local center = spawnCenter
	local shop = center + Vector3.new(0, 0, 40)
	local elder = center + Config.Island.ElderOffset

	island(folder, center, Config.Island.Radius, EMBER_ISLE, 7, assets, function(point)
		local offset = point - center
		return (offset * Vector3.new(1, 0, 1)).Magnitude < 38 -- plaza and crystals
			or (point - shop).Magnitude < 28
			or (point - elder).Magnitude < 22
			or distanceToSegment(point, center, shop) < 8
			or distanceToSegment(point, center, elder) < 8
	end)

	-- Stone plaza around the spawn and crystals, and dirt paths to the shop and to Elder Ember.
	fillDisc(center, 30, 4, center.Y, Enum.Material.Cobblestone)
	path(center, shop, 9)
	path(center, elder, 9)

	-- The rock Elder Ember stands on (its top is 3 studs up, see ElderService).
	fillDisc(elder, 11, 6, center.Y + 3, Enum.Material.Rock)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		terrain():FillBall(
			elder + Vector3.new(math.cos(angle) * 10, 0.5, math.sin(angle) * 10),
			3.5,
			Enum.Material.Rock
		)
	end

	folder.Parent = workspace
	return folder
end

local function buildLockedIslands(assets: Assets)
	local folder = Instance.new("Folder")
	folder.Name = "LockedIslands"
	for i, info in LOCKED_ISLANDS do
		local center = spawnCenter + info.Offset
		local model = Instance.new("Model")
		model.Name = info.Name
		island(model, center, info.Radius, info.Style, 100 + i, assets, nil)

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
		-- Sized in studs, so it looks like a sign far away instead of text stuck on the screen.
		billboard.Size = UDim2.fromScale(info.Radius * 1.6, info.Radius * 0.45)
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

local function addEffect(className: string, properties: { [string]: any })
	if Lighting:FindFirstChildWhichIsA(className) then
		return -- the developer set their own
	end
	local effect = Instance.new(className)
	for key, value in properties do
		(effect :: any)[key] = value
	end
	effect.Parent = Lighting
end

-- A warm late-afternoon sky with soft haze (the far islands fade into it), gentle sun rays
-- and slightly richer colours.
local function setSky()
	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 120, 118)
	addEffect("Atmosphere", {
		Density = 0.3,
		Offset = 0.2,
		Color = Color3.fromRGB(230, 205, 185),
		Decay = Color3.fromRGB(150, 120, 110),
		Glare = 0.3,
		Haze = 1.4,
	})
	addEffect("ColorCorrectionEffect", {
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.05,
		TintColor = Color3.fromRGB(255, 246, 236),
	})
	addEffect("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
	addEffect("BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 1.6 })

	local ground = terrain()
	for material, color in TERRAIN_COLORS do
		ground:SetMaterialColor(material, color)
	end
	-- Grass blades on the grass (only shows on graphics level 4 and up).
	pcall(function()
		(ground :: any).Decoration = true
	end)
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
	local assets = findAssets()
	buildEmberIsle(assets)
	buildLockedIslands(assets)
	setSky()
	task.spawn(rescueFallers)
end

return IslandService
