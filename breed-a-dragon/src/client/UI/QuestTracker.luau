--!strict
-- The quest card on the left of the screen (current tutorial quest, progress bar, reward),
-- and a glowing guide line from the player to where the quest happens, with a bouncing arrow there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ORANGE = Color3.fromRGB(255, 160, 60)
local GREEN = Color3.fromRGB(80, 220, 120)
local DARK = Color3.fromRGB(25, 20, 30)
local GUIDE_COLOR = Color3.fromRGB(255, 200, 90)
local GUIDE_HIDE_DISTANCE = 14 -- studs: close enough, stop pointing

local QuestTracker = {}

local card: Frame
local titleLabel: TextLabel
local progressFill: Frame
local progressLabel: TextLabel
local rewardLabel: TextLabel
local currentTarget: string? = nil

-- Guide line pieces (client-only).
local marker: Part
local markerAttachment: Attachment
local beam: Beam
local arrow: BillboardGui

local function label(parent: Instance, position: UDim2, size: UDim2, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.FontFace = Fonts.Body
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.5
	text.Parent = parent
	return text
end

local function buildCard()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Quests"
	screenGui.ResetOnSpawn = false

	card = Instance.new("Frame")
	card.Name = "QuestCard"
	card.Position = UDim2.new(0, 12, 0.5, -160)
	card.Size = UDim2.fromOffset(250, 104)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.15
	card.Visible = false
	card.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = ORANGE
	stroke.Thickness = 2
	stroke.Parent = card

	local header = label(card, UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 20), ORANGE)
	header.FontFace = Fonts.Title
	header.Text = "📜 Quest"
	titleLabel = label(card, UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 24), Color3.new(1, 1, 1))

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(12, 56)
	bar.Size = UDim2.new(1, -24, 0, 18)
	bar.BackgroundColor3 = Color3.fromRGB(60, 50, 65)
	bar.Parent = card
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 9)
	barCorner.Parent = bar
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = GREEN
	progressFill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = progressFill
	progressLabel = label(bar, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1))
	progressLabel.TextXAlignment = Enum.TextXAlignment.Center
	progressLabel.ZIndex = 2

	rewardLabel = label(card, UDim2.fromOffset(12, 78), UDim2.new(1, -24, 0, 18), ORANGE)

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function buildGuide()
	marker = Instance.new("Part")
	marker.Name = "QuestMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	markerAttachment = Instance.new("Attachment")
	markerAttachment.Parent = marker

	beam = Instance.new("Beam")
	beam.Attachment1 = markerAttachment
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.15, 0.35),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	beam.Enabled = false
	beam.Parent = marker

	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	arrow.Enabled = false
	arrow.Parent = marker
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = Fonts.Body
	text.TextScaled = true
	text.TextColor3 = GUIDE_COLOR
	text.TextStrokeTransparency = 0
	text.Text = "⬇"
	text.Parent = arrow

	marker.Parent = workspace
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "QuestGuide"
		attachment.Parent = root
		beam.Attachment0 = attachment
	end
end

-- Where the current quest's target is right now (nil = nothing to point at).
local function findTarget(from: Vector3): Vector3?
	if currentTarget == "Elder" then
		local island = workspace:FindFirstChild("EmberIsle")
		local elder = island and island:FindFirstChild("ElderEmber")
		local home = elder and elder:GetAttribute("Home")
		if typeof(home) == "CFrame" then
			return home.Position + Vector3.new(0, 4, 0)
		end
	elseif currentTarget == "Crystal" then
		local crystals = workspace:FindFirstChild("EmberCrystals")
		local best: Vector3?, bestDistance = nil, math.huge
		for _, crystal in if crystals then crystals:GetChildren() else {} do
			if crystal:IsA("Model") then
				local position = crystal:GetPivot().Position
				local distance = (position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = position, distance
				end
			end
		end
		return if best then best + Vector3.new(0, 3, 0) else nil
	elseif currentTarget == "EggShop" then
		local shop = workspace:FindFirstChild("EggShop")
		local pedestal = shop and shop:FindFirstChild("CommonPedestal")
		if pedestal and pedestal:IsA("BasePart") then
			return pedestal.Position + Vector3.new(0, 2, 0)
		end
	end
	return nil
end

local function updateGuide()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = if root and root:IsA("BasePart") then findTarget(root.Position) else nil
	local show = target ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and (target - root.Position).Magnitude > GUIDE_HIDE_DISTANCE
	beam.Enabled = show
	arrow.Enabled = target ~= nil
	if target then
		local bounce = math.sin(os.clock() * 4) * 0.8
		marker.CFrame = CFrame.new(target)
		arrow.StudsOffsetWorldSpace = Vector3.new(0, 4 + bounce, 0)
	end
end

local function show(state: { Step: number, Progress: number })
	local quest = Quests.Get(state.Step)
	if not quest then
		card.Visible = false
		currentTarget = nil
		return
	end
	card.Visible = true
	titleLabel.Text = quest.Text
	local progress = math.clamp(state.Progress / quest.Count, 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressFill.Visible = progress > 0
	progressLabel.Text = `{state.Progress} / {quest.Count}`
	rewardLabel.Text = `Reward: {Config.Currency.Icon} {quest.Reward}`
	currentTarget = quest.Target
end

function QuestTracker.Start()
	buildCard()
	buildGuide()

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	Remotes.Event("QuestUpdated").OnClientEvent:Connect(show)
	RunService.Heartbeat:Connect(updateGuide)
end

return QuestTracker
