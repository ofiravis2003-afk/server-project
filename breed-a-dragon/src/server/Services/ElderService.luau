--!strict
-- Elder Ember: the old dragon on his rock in Ember Isle. Talking to him (hold E / tap) tells
-- the story and explains the current quest (see QuestService.TalkToElder).
-- He is built like any other dragon, from fixed genes; every client makes him breathe and
-- slowly beat his wings (see client/Effects/ElderEffects).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Genes = require(ReplicatedStorage.Shared.Genes)
local QuestService = require(script.Parent.QuestService)
local Ground = require(script.Parent.Parent.Util.Ground)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local ELDER_GENES: Genes.DragonGenes = {
	Body = "Ember",
	Accent = "Gold",
	Wings = "Flame",
	Horns = "Crown",
	Tail = "Flame",
	Size = "Titan",
	Aura = "Ember",
	Pattern = "Veins",
}
local PERCH_HEIGHT = 3 -- matches the rock IslandService builds for him
local ORANGE = Color3.fromRGB(255, 160, 60)

local ElderService = {}

local talkLimiter = RateLimiter.new(1)

local function addTitle(model: Model, chest: BasePart)
	local _, size = model:GetBoundingBox()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Title"
	billboard.Size = UDim2.fromOffset(240, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.75, 0)
	billboard.MaxDistance = 120
	billboard.Adornee = chest
	billboard.Parent = chest
	for row, text in { "Elder Ember", "Keeper of Skyreach" } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (row - 1) * 0.6)
		label.Size = UDim2.fromScale(1, if row == 1 then 0.6 else 0.4)
		label.FontFace = if row == 1 then Fonts.Title else Fonts.Body
		label.TextScaled = true
		label.TextColor3 = if row == 1 then ORANGE else Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = billboard
	end
end

function ElderService.Start()
	local center = Ground.GetSpawnCenter()
	local stand = center + Config.Island.ElderOffset + Vector3.new(0, PERCH_HEIGHT, 0)
	local lookAt = Vector3.new(center.X, stand.Y, center.Z)

	local elder = DragonBuilder.Build(ELDER_GENES)
	elder.Name = "ElderEmber"
	-- With streaming on, send all of him at once so the client animation finds every part.
	elder.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	elder:PivotTo(CFrame.lookAt(stand, lookAt))
	-- Where the client animation keeps him (the pivot moves while he breathes).
	elder:SetAttribute("Home", elder:GetPivot())

	local chest = elder.PrimaryPart or elder:FindFirstChildWhichIsA("BasePart", true)
	if chest then
		addTitle(elder, chest)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Elder Ember"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 22
		prompt.RequiresLineOfSight = false
		prompt.Parent = chest
		prompt.Triggered:Connect(function(player)
			if talkLimiter:Check(player) then
				QuestService.TalkToElder(player)
			end
		end)
	end

	local island = workspace:FindFirstChild("EmberIsle") or workspace
	elder.Parent = island
end

return ElderService
