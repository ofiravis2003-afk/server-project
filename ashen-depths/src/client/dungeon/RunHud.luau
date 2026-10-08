--!strict
-- Dungeon-only HUD: the floor you're on and the keys you carry (under the main panel),
-- and a big title in the middle of the screen when a new floor begins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local KEY_COLORS = {
	Bronze = Color3.fromRGB(196, 128, 72),
	Silver = Color3.fromRGB(205, 210, 220),
	Gold = Color3.fromRGB(245, 200, 80),
}

local RunHud = {}

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	return l
end

function RunHud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RunHud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(12, 82)
	panel.Size = UDim2.fromOffset(250, 50)
	panel.BackgroundColor3 = Color3.fromRGB(22, 18, 20)
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local floorText = label(panel, Fonts.Title, 15, Color3.fromRGB(230, 220, 200))
	floorText.Position = UDim2.fromOffset(10, 4)
	floorText.Size = UDim2.new(1, -20, 0, 18)
	floorText.TextXAlignment = Enum.TextXAlignment.Left
	floorText.Text = "Floor 1"

	local keyTexts: { [string]: TextLabel } = {}
	for i, tier in { "Bronze", "Silver", "Gold" } do
		local icon = Instance.new("Frame")
		icon.Position = UDim2.fromOffset(10 + (i - 1) * 78, 28)
		icon.Size = UDim2.fromOffset(12, 12)
		icon.Rotation = 45
		icon.BackgroundColor3 = KEY_COLORS[tier]
		icon.Parent = panel
		local text = label(panel, Fonts.Body, 13, KEY_COLORS[tier])
		text.Position = UDim2.fromOffset(28 + (i - 1) * 78, 24)
		text.Size = UDim2.fromOffset(56, 20)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = `{tier} 0`
		keyTexts[tier] = text
	end

	local banner = label(gui, Fonts.Title, 54, Color3.fromRGB(240, 225, 200))
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(700, 60)
	banner.TextTransparency = 1
	banner.TextStrokeTransparency = 1
	local subtitle = label(gui, Fonts.Title, 24, Color3.fromRGB(200, 170, 120))
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.new(0.5, 0, 0.3, 46)
	subtitle.Size = UDim2.fromOffset(700, 30)
	subtitle.TextTransparency = 1
	subtitle.TextStrokeTransparency = 1

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("RunUpdated").OnClientEvent:Connect(function(run)
		floorText.Text = `Floor {run.Floor}  ·  {run.Chapter}`
		for tier, text in keyTexts do
			text.Text = `{tier} {run.Keys[tier] or 0}`
		end
	end)

	Remotes.Event("FloorStarted").OnClientEvent:Connect(function(floor: number, chapter: string)
		banner.Text = `Floor {floor}`
		subtitle.Text = chapter
		local fadeIn = TweenInfo.new(0.8)
		local fadeOut = TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 2.5)
		for _, l in { banner, subtitle } do
			TweenService:Create(l, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
		end
		task.delay(0.8, function()
			for _, l in { banner, subtitle } do
				TweenService:Create(l, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end)
end

return RunHud
