--!strict
-- Ember Crystals: the first way to earn Embers. Click (or tap) a crystal to collect.
-- In the story, Embers are the leftover magic of Skyreach that dragons feed on.
-- They stand in a ring around the spawn point, in the middle of Ember Isle.
--
-- Each crystal is a cluster of glass shards with a glowing core, growing out of a rock.
-- The click effects (burst + bounce) run on the clicking player's screen: see client/Effects/CrystalEffects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CurrencyService = require(script.Parent.CurrencyService)
local QuestService = require(script.Parent.QuestService)
local Ground = require(script.Parent.Parent.Util.Ground)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local SHELL_COLOR = Color3.fromRGB(255, 120, 40)
local CORE_COLOR = Color3.fromRGB(255, 190, 80)
local ROCK_COLOR = Color3.fromRGB(85, 80, 90)

-- Turns a cube so one corner points straight up: a natural three-faced crystal tip.
local CORNER_UP = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))

local CrystalService = {}

local clickLimiter = RateLimiter.new(Config.Crystal.Cooldown)

local function newPart(model: Model, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- One shard: a diamond-shaped glass prism with a glowing core and a pointed tip.
-- `yaw` is the direction it leans towards, `tilt` how far it leans from straight up.
local function addShard(model: Model, base: Vector3, height: number, width: number, yaw: number, tilt: number)
	local up = Vector3.new(math.cos(yaw) * math.sin(tilt), math.cos(tilt), math.sin(yaw) * math.sin(tilt))
	local side = Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
	local frame = CFrame.fromMatrix(base, side, up) * CFrame.Angles(0, math.rad(45), 0)

	local shell = newPart(model, "Shard", Vector3.new(width, height, width), frame * CFrame.new(0, height / 2, 0))
	shell.Material = Enum.Material.Glass
	shell.Color = SHELL_COLOR
	shell.Transparency = 0.35

	local tipSize = width * 0.85
	local tip =
		newPart(model, "Tip", Vector3.one * tipSize, frame * CFrame.new(0, height - tipSize * 0.15, 0) * CORNER_UP)
	tip.Material = Enum.Material.Glass
	tip.Color = SHELL_COLOR
	tip.Transparency = 0.35

	local core = newPart(
		model,
		"Core",
		Vector3.new(width * 0.45, height * 0.85, width * 0.45),
		frame * CFrame.new(0, height * 0.45, 0)
	)
	core.Material = Enum.Material.Neon
	core.Color = CORE_COLOR
	return core
end

local function createCrystal(position: Vector3, rng: Random, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "EmberCrystal"

	local rock = newPart(model, "Rock", Vector3.new(5.5, 1.4, 5.5), CFrame.new(position + Vector3.new(0, 0.3, 0)))
	rock.Material = Enum.Material.Slate
	rock.Color = ROCK_COLOR
	local rockShape = Instance.new("SpecialMesh")
	rockShape.MeshType = Enum.MeshType.Sphere
	rockShape.Parent = rock

	-- The tall centre shard, then a ring of smaller ones leaning outwards.
	local heart = addShard(model, position, 6.5, 1.6, 0, math.rad(rng:NextNumber(0, 6)))
	heart.Name = "Heart"
	local sideShards = rng:NextInteger(4, 6)
	local startAngle = rng:NextNumber(0, math.pi * 2)
	for i = 1, sideShards do
		local yaw = startAngle + i / sideShards * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local offset = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * rng:NextNumber(0.8, 1.3)
		addShard(
			model,
			position + offset,
			rng:NextNumber(2.8, 4.8),
			rng:NextNumber(0.9, 1.25),
			yaw,
			math.rad(rng:NextNumber(22, 38))
		)
	end

	local light = Instance.new("PointLight")
	light.Color = SHELL_COLOR
	light.Range = 12
	light.Brightness = 2
	light.Parent = heart

	model.PrimaryPart = rock
	rock.PivotOffset = CFrame.new(0, -0.3, 0)

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Config.Crystal.MaxClickDistance
	clickDetector.Parent = model

	clickDetector.MouseClick:Connect(function(player)
		if not clickLimiter:Check(player) then
			return
		end
		CurrencyService.Add(player, Config.Crystal.Reward)
		QuestService.Record(player, "Collect", Config.Crystal.Reward)
	end)

	model.Parent = parent
	return model
end

function CrystalService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "EmberCrystals"
	folder.Parent = workspace

	local center = Ground.GetSpawnCenter()

	for i = 1, Config.Crystal.Count do
		local angle = (i / Config.Crystal.Count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Crystal.Radius
		-- A fixed seed per crystal: each one looks different, but the same every time.
		createCrystal(center + offset, Random.new(i), folder)
	end
end

return CrystalService
