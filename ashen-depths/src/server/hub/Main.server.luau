--!strict
-- Server entry point for Emberhold. Starts every service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients find them as soon as they join.
require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)

local Common = script.Parent.Parent.Common
local ArmorService = require(Common.ArmorService)
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local MonetizationService = require(Common.MonetizationService)
local PartyService = require(Common.PartyService)
local DailyService = require(Common.DailyService)
local Travel = require(Common.Travel)
local ProgressService = require(Common.ProgressService)
local QuestService = require(Common.QuestService)
local TitleService = require(Common.TitleService)
local CombatService = require(Common.CombatService)
local FounderService = require(script.Parent.FounderService)
local ReferralService = require(script.Parent.ReferralService)
local ShopService = require(script.Parent.ShopService)
local TrainingService = require(script.Parent.TrainingService)

ArmorService.Start()
InventoryService.Start()
MonetizationService.Start()
PartyService.Start()
DailyService.Start()
Travel.Start()
ProgressService.Start()
QuestService.Start()
TitleService.Start()
ShopService.Start()
CombatService.Start(TrainingService)
ReferralService.Start()
FounderService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print(`[Emberwell] Emberhold server v{Config.Version} started`)
