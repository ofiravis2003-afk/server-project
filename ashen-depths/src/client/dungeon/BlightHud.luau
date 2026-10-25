--!strict
-- Blight on screen: a green line at the top while the player carries spores ("Blighted 3/5 · healing -30%").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)

local MAX = 5

local BlightHud = {}

function BlightHud.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlightHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 52)
	line.Size = UDim2.fromOffset(360, 26)
	line.BackgroundColor3 = Color3.fromRGB(20, 34, 22)
	line.BackgroundTransparency = 0.25
	line.FontFace = Fonts.Body
	line.TextSize = 16
	line.TextColor3 = Color3.fromRGB(150, 240, 140)
	line.Visible = false
	line.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = line

	local function refresh()
		local n = (player:GetAttribute("Blight") :: number?) or 0
		line.Visible = n > 0
		line.Text = `Blighted {n}/{MAX}  ·  healing -{n * 10}%` -- (plain text: the font has no dot glyphs)
	end
	player:GetAttributeChangedSignal("Blight"):Connect(refresh)
	refresh()
end

return BlightHud
