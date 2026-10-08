--!strict
-- Server entry point for Depths. Starts every service in order.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local DataService = require(script.Parent.Parent.Common.DataService)

DataService.Start()

print(`[Ashen Depths] Depths server v{Config.Version} started`)
