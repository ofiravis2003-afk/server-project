--!strict
-- The screen shown while a player travels between Emberhold and the Depths: the server says "Traveling" with
-- where to, this builds a dark title card and hands it to TeleportService, so it stays up through Roblox's
-- loading and the next place takes it over (first/Arrival.client.luau fades it out once that place is ready).

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Logo = require(ReplicatedFirst:WaitForChild("Logo"))
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TravelScreen = {}

local LINES = {
	Depths = { Title = "The Descent", Sub = "The chains groan. The dark below breathes ash..." },
	Emberhold = { Title = "Emberhold", Sub = "You climb toward the light of the Guild's fires..." },
}

-- The card itself (also built by the arriving place if the teleport didn't carry one).
function TravelScreen.Build(where: string): ScreenGui
	local text = LINES[where] or LINES.Emberhold
	local gui = Instance.new("ScreenGui")
	gui.Name = "TravelScreen"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	back.BorderSizePixel = 0
	back.Parent = gui
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromRGB(60, 24, 10), Color3.fromRGB(8, 6, 6))
	glow.Rotation = 90
	glow.Parent = back
	-- the logo above the place's name
	local camera = workspace.CurrentCamera
	local logo = Logo.Build(back, if camera then math.min(camera.ViewportSize.X * 0.55, camera.ViewportSize.Y * 0.85, 560) else 460)
	logo.Position = UDim2.fromScale(0.5, 0.33)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.65)
	title.Size = UDim2.new(0.8, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.FontFace = Fonts.Title
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 190, 90)
	title.Text = text.Title
	title.Parent = back
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0.65, 30)
	sub.Size = UDim2.new(0.8, 0, 0, 28)
	sub.BackgroundTransparency = 1
	sub.FontFace = Fonts.Body
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(200, 185, 165)
	sub.Text = text.Sub
	sub.Parent = back
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = sub
	return gui
end

function TravelScreen.Start()
	local player = Players.LocalPlayer
	-- the card comes down if the trip fails (the server says "Cancel", or Roblox reports it here), and in any
	-- case after a while: never stuck on a loading screen
	local function takeDown()
		for _, old in player:WaitForChild("PlayerGui"):GetChildren() do
			if old.Name == "TravelScreen" then
				old:Destroy()
			end
		end
	end
	TeleportService.TeleportInitFailed:Connect(function(who: Player)
		if who == player then
			takeDown()
		end
	end)
	Remotes.Event("Traveling").OnClientEvent:Connect(function(where: any)
		if where == "Cancel" then
			takeDown()
			return
		end
		task.delay(45, function()
			takeDown()
		end)
		local gui = TravelScreen.Build(if type(where) == "string" then where else "Emberhold")
		local back = gui:FindFirstChild("Back") :: Frame
		back.BackgroundTransparency = 1
		local logo = back:FindFirstChild("Logo") :: Frame
		local copy = gui:Clone() -- (for the next place, before the fade-in below touches it)
		Logo.Hide(logo)
		gui.Parent = player:WaitForChild("PlayerGui")
		TweenService:Create(back, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
		Logo.Fade(logo, true, 0.6)
		Logo.Embers(logo)
		pcall(function()
			TeleportService:SetTeleportGui(copy)
		end)
	end)
end

return TravelScreen
