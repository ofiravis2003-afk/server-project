--!strict
-- Ember Crystals: the first way to earn Embers. Click (or tap) a crystal to collect.
-- For now the crystals are placed in a ring around the spawn point; Ember Isle replaces this in phase 6.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CurrencyService = require(script.Parent.CurrencyService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local CRYSTAL_SIZE = Vector3.new(3, 6, 3)
local CRYSTAL_COLOR = Color3.fromRGB(255, 120, 40)

local CrystalService = {}

local clickLimiter = RateLimiter.new(Config.Crystal.Cooldown)

local function pulse(crystal: BasePart)
	local grow = TweenService:Create(crystal, TweenInfo.new(0.08), { Size = CRYSTAL_SIZE * 1.15 })
	local shrink = TweenService:Create(crystal, TweenInfo.new(0.12), { Size = CRYSTAL_SIZE })
	grow.Completed:Once(function()
		shrink:Play()
	end)
	grow:Play()
end

local function createCrystal(position: Vector3, parent: Instance): BasePart
	local crystal = Instance.new("Part")
	crystal.Name = "EmberCrystal"
	crystal.Anchored = true
	crystal.Size = CRYSTAL_SIZE
	crystal.Material = Enum.Material.Neon
	crystal.Color = CRYSTAL_COLOR
	-- Tilt it a little so it looks like a crystal growing from the ground.
	crystal.CFrame = CFrame.new(position + Vector3.new(0, CRYSTAL_SIZE.Y / 2, 0))
		* CFrame.Angles(0, math.rad(45), math.rad(10))

	local light = Instance.new("PointLight")
	light.Color = CRYSTAL_COLOR
	light.Range = 10
	light.Brightness = 2
	light.Parent = crystal

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Config.Crystal.MaxClickDistance
	clickDetector.Parent = crystal

	clickDetector.MouseClick:Connect(function(player)
		if not clickLimiter:Check(player) then
			return
		end
		CurrencyService.Add(player, Config.Crystal.Reward)
		pulse(crystal)
	end)

	crystal.Parent = parent
	return crystal
end

function CrystalService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "EmberCrystals"
	folder.Parent = workspace

	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local center = if spawnLocation then spawnLocation.Position * Vector3.new(1, 0, 1) else Vector3.zero
	local groundY = if spawnLocation then spawnLocation.Position.Y - spawnLocation.Size.Y / 2 else 0

	for i = 1, Config.Crystal.Count do
		local angle = (i / Config.Crystal.Count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Crystal.Radius
		createCrystal(center + offset + Vector3.new(0, groundY, 0), folder)
	end
end

return CrystalService
