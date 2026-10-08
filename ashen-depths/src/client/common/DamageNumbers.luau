--!strict
-- Floating numbers above whoever got hit: white hits, orange crits, green poison,
-- red when the player is hurt, light green heals, and gold rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STYLES = {
	Hit = { Color = Color3.fromRGB(255, 255, 255), Size = 26, Font = Fonts.Number },
	Crit = { Color = Color3.fromRGB(255, 150, 40), Size = 36, Font = Fonts.Number },
	Poison = { Color = Color3.fromRGB(120, 220, 90), Size = 20, Font = Fonts.Number },
	Hurt = { Color = Color3.fromRGB(255, 70, 60), Size = 26, Font = Fonts.Number },
	Heal = { Color = Color3.fromRGB(150, 255, 140), Size = 24, Font = Fonts.Number },
	Reward = { Color = Color3.fromRGB(240, 200, 90), Size = 22, Font = Fonts.Body },
}

local DamageNumbers = {}

local function show(position: Vector3, value: number | string, kind: string)
	local style = STYLES[kind] or STYLES.Hit
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position + Vector3.new((math.random() - 0.5) * 1.5, 0, (math.random() - 0.5) * 1.5)
	anchor.Parent = workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.FontFace = style.Font
	text.TextSize = style.Size
	text.TextColor3 = style.Color
	text.TextStrokeTransparency = 0.2
	text.Text = if kind == "Crit" then `{value}!` elseif kind == "Heal" then `+{value}` else tostring(value)
	text.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local rise = if kind == "Reward" then 3 else 2
	local duration = if kind == "Reward" then 1.6 else 0.9
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, rise, 0),
	}):Play()
	TweenService:Create(text, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, duration * 0.5), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(duration + 0.1, function()
		gui:Destroy()
		anchor:Destroy()
	end)
end

function DamageNumbers.Start()
	Remotes.Event("DamageNumber").OnClientEvent:Connect(show)
end

return DamageNumbers
