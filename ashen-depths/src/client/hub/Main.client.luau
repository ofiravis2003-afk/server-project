--!strict
-- Client entry point for Emberhold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Common = script.Parent.Parent.Common
local DamageNumbers = require(Common.DamageNumbers)
local Hud = require(Common.Hud)
local Inventory = require(Common.Inventory)
local ItemPopup = require(Common.ItemPopup)
local Shop = require(script.Parent.Shop)
local TownFolk = require(script.Parent.TownFolk)
local Upgrade = require(script.Parent.Upgrade)
local Dialogue = require(script.Parent.Dialogue)
local QuestBoard = require(script.Parent.QuestBoard)

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Ashen Depths", Text = message, Duration = 6 })
end)

Hud.Start()
DamageNumbers.Start()
ItemPopup.Start()
Inventory.Start()
Shop.Start()
Upgrade.Start()
Dialogue.Start()
QuestBoard.Start()
task.spawn(TownFolk.Start)

print(`[Ashen Depths] Emberhold client v{Config.Version} ready`)
