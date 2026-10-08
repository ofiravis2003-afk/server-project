--!strict
-- Client entry point for Depths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Common = script.Parent.Parent.Common
local DamageNumbers = require(Common.DamageNumbers)
local Hud = require(Common.Hud)
local Combat = require(script.Parent.Combat)
local Effects = require(script.Parent.Effects)
local RunHud = require(script.Parent.RunHud)

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Ashen Depths", Text = message, Duration = 6 })
end)

Hud.Start()
DamageNumbers.Start()
Combat.Start()
Effects.Start()
RunHud.Start()

print(`[Ashen Depths] Depths client v{Config.Version} ready`)
