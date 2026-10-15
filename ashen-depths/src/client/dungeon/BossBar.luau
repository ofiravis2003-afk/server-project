--!strict
-- The big bar at the top of the screen during a boss fight: the boss's name and health.
-- Shows while a living boss (tagged "Boss" by the server) is near the player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)

local SHOW_WITHIN = 80

local BossBar = {}

function BossBar.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = true

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 58)
	frame.Size = UDim2.new(0.5, 0, 0, 46)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 46)
	limit.MinSize = Vector2.new(260, 46)
	limit.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.FontFace = Fonts.Title
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(235, 205, 160)
	title.TextStrokeTransparency = 0.4
	title.Parent = frame

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 28)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(25, 12, 12)
	back.BorderSizePixel = 0
	back.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 90, 60)
	stroke.Thickness = 2
	stroke.Parent = back
	-- A pale trail behind the red catches up a moment later, so each blow shows.
	local trail = Instance.new("Frame")
	trail.Size = UDim2.fromScale(1, 1)
	trail.BackgroundColor3 = Color3.fromRGB(230, 200, 120)
	trail.BorderSizePixel = 0
	trail.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(170, 25, 25)
	fill.BorderSizePixel = 0
	fill.Parent = back

	gui.Parent = player:WaitForChild("PlayerGui")

	local shown: Model? = nil
	local lastRatio = 1
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best: Model? = nil
		if root then
			for _, boss in CollectionService:GetTagged("Boss") do
				local humanoid = boss:FindFirstChildOfClass("Humanoid")
				local bossRoot = boss:FindFirstChild("HumanoidRootPart") :: BasePart?
				if humanoid and bossRoot and humanoid.Health > 0 and (bossRoot.Position - root.Position).Magnitude <= SHOW_WITHIN then
					best = boss :: Model
				end
			end
		end
		frame.Visible = best ~= nil
		if not best then
			shown = nil
			return
		end
		local humanoid = best:FindFirstChildOfClass("Humanoid") :: Humanoid
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		if best ~= shown then
			shown = best
			title.Text = (best:GetAttribute("BossTitle") :: string?) or best.Name
			lastRatio = ratio
			trail.Size = UDim2.fromScale(ratio, 1)
		end
		fill.Size = UDim2.fromScale(ratio, 1)
		if ratio < lastRatio then
			lastRatio = ratio
			TweenService:Create(trail, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3), {
				Size = UDim2.fromScale(ratio, 1),
			}):Play()
		end
	end)
end

return BossBar
