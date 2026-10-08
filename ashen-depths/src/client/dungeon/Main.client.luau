--!strict
-- Client entry point for Depths.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local StarterGui = game:GetService("StarterGui")

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Ashen Depths", Text = message, Duration = 6 })
end)

print(`[Ashen Depths] Depths client v{Config.Version} ready`)
