--!strict
-- Client entry point for Emberhold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Common = script.Parent.Parent.Common
local Audio = require(Common.Audio)
local DamageNumbers = require(Common.DamageNumbers)
local Hud = require(Common.Hud)
local Inventory = require(Common.Inventory)
local ItemPopup = require(Common.ItemPopup)
local LorePage = require(Common.LorePage)
local Party = require(Common.Party)
local TravelScreen = require(Common.TravelScreen)
local Shop = require(script.Parent.Shop)
local TownFolk = require(script.Parent.TownFolk)
local Upgrade = require(script.Parent.Upgrade)
local Dialogue = require(script.Parent.Dialogue)
local Intro = require(script.Parent.Intro)
local QuestBoard = require(script.Parent.QuestBoard)

Remotes.Event("Notify").OnClientEvent:Connect(function(message: string)
	StarterGui:SetCore("SendNotification", { Title = "Emberwell", Text = message, Duration = 6 })
end)

Audio.Start("Town")
Hud.Start()
DamageNumbers.Start()
ItemPopup.Start()
LorePage.Start()
TravelScreen.Start()
Inventory.Start()
Party.Start(true)
Shop.Start()
Upgrade.Start()
Dialogue.Start()
Intro.Start()
QuestBoard.Start()
task.spawn(TownFolk.Start)

print(`[Emberwell] Emberhold client v{Config.Version} ready`)
