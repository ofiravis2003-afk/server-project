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
local PartyService = require(Common.PartyService)
local ProgressService = require(Common.ProgressService)
local QuestService = require(Common.QuestService)
local FounderService = require(script.Parent.FounderService)
local ReferralService = require(script.Parent.ReferralService)
local ShopService = require(script.Parent.ShopService)

ArmorService.Start()
InventoryService.Start()
PartyService.Start()
ProgressService.Start()
QuestService.Start()
ShopService.Start()
ReferralService.Start()
FounderService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print(`[Emberwell] Emberhold server v{Config.Version} started`)
