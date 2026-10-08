--!strict
-- Server entry point for Emberhold. Starts every service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients find them as soon as they join.
require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)

local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local ProgressService = require(Common.ProgressService)

InventoryService.Start()
ProgressService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print(`[Ashen Depths] Emberhold server v{Config.Version} started`)
