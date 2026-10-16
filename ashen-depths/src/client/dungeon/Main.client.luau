--!strict
-- Client entry point for Depths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Common = script.Parent.Parent.Common
local DamageNumbers = require(Common.DamageNumbers)
local Hud = require(Common.Hud)
local Inventory = require(Common.Inventory)
local ItemPopup = require(Common.ItemPopup)
local BossBar = require(script.Parent.BossBar)
local BossIntro = require(script.Parent.BossIntro)
local Combat = require(script.Parent.Combat)
local Effects = require(script.Parent.Effects)
local FloorPicker = require(script.Parent.FloorPicker)
local RunHud = require(script.Parent.RunHud)
local Scurry = require(script.Parent.Scurry)
local Squish = require(script.Parent.Squish)
local TwoHandGrip = require(script.Parent.TwoHandGrip)

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Ashen Depths", Text = message, Duration = 6 })
end)

Hud.Start()
DamageNumbers.Start()
ItemPopup.Start()
Inventory.Start()
Combat.Start()
Effects.Start()
FloorPicker.Start()
RunHud.Start()
Squish.Start()
Scurry.Start()
BossBar.Start()
BossIntro.Start()
TwoHandGrip.Start()

print(`[Ashen Depths] Depths client v{Config.Version} ready`)
