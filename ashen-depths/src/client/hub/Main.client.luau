--!strict
-- Client entry point for Emberhold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Common = script.Parent.Parent.Common
local DamageNumbers = require(Common.DamageNumbers)
local Hud = require(Common.Hud)
local ItemPopup = require(Common.ItemPopup)

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Ashen Depths", Text = message, Duration = 6 })
end)

Hud.Start()
DamageNumbers.Start()
ItemPopup.Start()

print(`[Ashen Depths] Emberhold client v{Config.Version} ready`)
