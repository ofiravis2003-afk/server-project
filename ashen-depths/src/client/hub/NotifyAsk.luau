--!strict
-- When the server says so (NotifyService, once per adventurer): Roblox's own prompt asking whether they want
-- notifications from Emberwell. Roblox decides whether this player may be asked at all.

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyAsk = {}

local function ask()
	local ok, can = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
	if ok and can then
		pcall(ExperienceNotificationService.PromptOptIn, ExperienceNotificationService)
	end
end

function NotifyAsk.Start()
	Remotes.Event("AskNotify").OnClientEvent:Connect(ask)
end

return NotifyAsk
