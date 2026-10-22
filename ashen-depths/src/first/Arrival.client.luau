--!strict
-- Runs first, in both places, and covers Roblox's grey loading screen until this place has loaded and the
-- player's character stands in it, then fades away:
--   arriving by teleport: the travel card they left with (with the logo on it, from TravelScreen)
--   joining the game: the opening screen, the Ashen Depths logo on black with embers rising

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Logo = require(script.Parent:WaitForChild("Logo"))

local player = Players.LocalPlayer
local card = TeleportService:GetArrivingTeleportGui()
local opening = card == nil
if not card then
	local gui = Instance.new("ScreenGui")
	gui.Name = "OpeningScreen"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(8, 6, 6)
	back.BorderSizePixel = 0
	back.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(8, 6, 6), Color3.fromRGB(46, 18, 8))
	shade.Rotation = 90
	shade.Parent = back
	card = gui
end
local screen = card :: ScreenGui
screen.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local back = screen:FindFirstChild("Back") :: Frame?
local logo = back and back:FindFirstChild("Logo") :: Frame?
if back and not logo then
	-- the opening: the logo grows in out of the dark
	local camera = workspace.CurrentCamera
	local width = if camera then math.min(camera.ViewportSize.X * 0.7, 620) else 520
	local l = Logo.Build(back, width)
	l.Position = UDim2.fromScale(0.5, 0.46)
	Logo.Hide(l)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = l
	Logo.Fade(l, true, 1.6)
	TweenService:Create(scale, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	logo = l
end
if logo then
	Logo.Embers(logo)
end
local started = os.clock()

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 15)
task.wait(1.5) -- the town or the floor builds itself around them
if opening then
	task.wait(math.max(0, 3.5 - (os.clock() - started))) -- the logo is up long enough to be seen
end

if back then
	local fade = TweenInfo.new(0.8)
	TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
	if logo then
		Logo.Fade(logo, false, 0.8)
	end
	for _, label in back:GetChildren() do
		if label:IsA("TextLabel") then
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		end
	end
	task.wait(0.9)
end
screen:Destroy()
