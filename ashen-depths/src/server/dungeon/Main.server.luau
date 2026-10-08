--!strict
-- Server entry point for Depths. Starts every service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients find them as soon as they join.
require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)

local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local ProgressService = require(Common.ProgressService)
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)

InventoryService.Start()
ProgressService.Start()
EnemyService.Start()
CombatService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print(`[Ashen Depths] Depths server v{Config.Version} started`)
