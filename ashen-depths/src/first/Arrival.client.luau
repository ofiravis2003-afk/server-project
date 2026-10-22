--!strict
-- Runs first, in both places: if the player arrived by teleport, the travel card they left with stays up
-- (instead of Roblox's grey loading screen) until this place has loaded and their character stands in it,
-- then fades away.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local card = TeleportService:GetArrivingTeleportGui()
if not card then
	return
end
card.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 15)
task.wait(1.5) -- the town or the floor builds itself around them

local back = card:FindFirstChild("Back") :: Frame?
if back then
	local fade = TweenInfo.new(0.8)
	TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
	for _, label in back:GetChildren() do
		if label:IsA("TextLabel") then
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		end
	end
	task.wait(0.9)
end
card:Destroy()
