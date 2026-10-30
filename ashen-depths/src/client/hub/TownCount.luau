--!strict
-- A small line at the top of the screen in Emberhold saying how many adventurers are in town, so a server with others
-- in it feels alive. Alone, it says nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)

local MIN_TO_SHOW = 2

local TownCount = {}

function TownCount.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "TownCount"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, if Device.Touch() then 8 else 58)
	line.Size = UDim2.fromOffset(280, 22)
	line.BackgroundColor3 = Color3.fromRGB(20, 16, 16)
	line.BackgroundTransparency = 0.4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = line
	line.FontFace = Fonts.Title
	line.TextSize = if Device.Touch() then 15 else 18
	line.TextColor3 = Color3.fromRGB(235, 215, 170)
	line.TextStrokeTransparency = 0.4
	line.Parent = gui
	local function refresh()
		local count = #Players:GetPlayers()
		line.Visible = count >= MIN_TO_SHOW
		line.Text = `{count} adventurers in Emberhold`
	end
	refresh()
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
end

return TownCount
