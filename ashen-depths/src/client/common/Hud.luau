--!strict
-- Top-left panel: level, XP bar and gold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GOLD = Color3.fromRGB(240, 190, 90)
local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)

local Hud = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end

function Hud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(12, 12)
	panel.Size = UDim2.fromOffset(250, 64)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	corner(panel, 8)
	stroke(panel, EDGE, 1.5)

	local badge = Instance.new("Frame")
	badge.Position = UDim2.fromOffset(8, 8)
	badge.Size = UDim2.fromOffset(48, 48)
	badge.BackgroundColor3 = Color3.fromRGB(45, 30, 22)
	badge.Parent = panel
	corner(badge, 24)
	stroke(badge, GOLD, 2)
	local levelText = label(badge, Fonts.Number, 22, GOLD)
	levelText.Size = UDim2.fromScale(1, 1)
	levelText.Text = "1"

	local levelCaption = label(panel, Fonts.Title, 15, Color3.fromRGB(230, 220, 200))
	levelCaption.Position = UDim2.fromOffset(66, 6)
	levelCaption.Size = UDim2.fromOffset(100, 18)
	levelCaption.TextXAlignment = Enum.TextXAlignment.Left
	levelCaption.Text = "Adventurer"

	local goldText = label(panel, Fonts.Body, 15, GOLD)
	goldText.Position = UDim2.fromOffset(150, 6)
	goldText.Size = UDim2.fromOffset(90, 18)
	goldText.TextXAlignment = Enum.TextXAlignment.Right
	goldText.Text = "0 Gold"

	local xpBack = Instance.new("Frame")
	xpBack.Position = UDim2.fromOffset(66, 30)
	xpBack.Size = UDim2.fromOffset(174, 14)
	xpBack.BackgroundColor3 = Color3.fromRGB(40, 34, 36)
	xpBack.Parent = panel
	corner(xpBack, 4)
	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Color3.fromRGB(110, 170, 255)
	xpFill.Parent = xpBack
	corner(xpFill, 4)
	local xpText = label(xpBack, Fonts.Body, 11, Color3.new(1, 1, 1))
	xpText.Size = UDim2.fromScale(1, 1)
	xpText.ZIndex = 2
	xpText.Text = "XP 0 / 40"

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("StatsUpdated").OnClientEvent:Connect(function(stats)
		levelText.Text = tostring(stats.Level)
		goldText.Text = `{stats.Gold} Gold`
		local ratio = if stats.Level >= stats.MaxLevel then 1 else math.clamp(stats.XP / stats.XPToNext, 0, 1)
		xpText.Text = if stats.Level >= stats.MaxLevel then "MAX" else `XP {stats.XP} / {stats.XPToNext}`
		TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
	end)
end

return Hud
