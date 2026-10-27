--!strict
-- Server entry point for Depths. Starts every service in order.

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
local BlightService = require(Common.BlightService)
local DailyService = require(Common.DailyService)
local Travel = require(Common.Travel)
local ProgressService = require(Common.ProgressService)
local QuestService = require(Common.QuestService)
local CombatService = require(Common.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local FloorService = require(script.Parent.FloorService)

ArmorService.Start()
InventoryService.Start()
MonetizationService.Start()
PartyService.Start()
BlightService.Start()
DailyService.Start()
Travel.Start()
ProgressService.Start()
QuestService.Start()
EnemyService.Start()
CombatService.Start(EnemyService)
FloorService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print(`[Emberwell] Depths server v{Config.Version} started`)
