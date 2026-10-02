--!strict
-- STUDIO ONLY testing tool: a row of random dragons with name tags and a "reroll" button,
-- so we can see how varied the dragons look. It never runs in the live game.
-- Turn it off with Config.Dev.DragonGallery = false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Ground = require(script.Parent.Parent.Util.Ground)

local COLUMNS = 5
local ROWS = 4
local SPACING = 16
local DISTANCE = 45 -- studs in front of the spawn point where the gallery starts

local DevGalleryService = {}

local rng = Random.new()
local folder: Folder
local origin: Vector3

local function spawnGallery()
	folder:ClearAllChildren()
	for row = 0, ROWS - 1 do
		for column = 0, COLUMNS - 1 do
			local genes = Genes.Roll(rng)
			local dragon = DragonBuilder.Build(genes)
			DragonBuilder.AddNameTag(dragon, genes)
			local x = (column - (COLUMNS - 1) / 2) * SPACING
			local z = -(DISTANCE + row * SPACING)
			-- Turn them around to face the spawn point.
			dragon:PivotTo(CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, math.pi, 0))
			dragon.Parent = folder
		end
	end
end

local function createRerollButton()
	local button = Instance.new("Part")
	button.Name = "RerollDragons"
	button.Anchored = true
	button.Size = Vector3.new(8, 1, 4)
	button.Material = Enum.Material.Neon
	button.Color = Color3.fromRGB(80, 220, 120)
	button.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, -(DISTANCE - 12)))

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(220, 40)
	label.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	label.Parent = button
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Text = "Click: new dragons"
	text.Parent = label

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 40
	clickDetector.Parent = button

	local busy = false
	clickDetector.MouseClick:Connect(function()
		if busy then
			return
		end
		busy = true
		spawnGallery()
		task.wait(0.5)
		busy = false
	end)

	button.Parent = folder.Parent
end

-- Rolls many dragons and prints how often each overall rarity comes up.
local function printOdds()
	local rolls = 20000
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local tier = Genes.GetRarity(Genes.Roll(rng)).Name
		counts[tier] = (counts[tier] or 0) + 1
	end
	local lines = {}
	for _, tier in Rarity.Tiers do
		table.insert(lines, string.format("%s %.2f%%", tier.Name, (counts[tier.Name] or 0) / rolls * 100))
	end
	print(`[DevGallery] Overall rarity odds (default weights): {table.concat(lines, " | ")}`)
end

function DevGalleryService.Start()
	if not RunService:IsStudio() or not Config.Dev.DragonGallery then
		return
	end

	origin = Ground.GetSpawnCenter()
	local root = Instance.new("Folder")
	root.Name = "DevGallery"
	root.Parent = workspace
	folder = Instance.new("Folder")
	folder.Name = "Dragons"
	folder.Parent = root

	spawnGallery()
	createRerollButton()
	printOdds()
end

return DevGalleryService
