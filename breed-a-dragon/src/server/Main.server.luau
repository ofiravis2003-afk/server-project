--!strict
-- Server entry point: starts every service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients find them as soon as they join.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local CurrencyService = require(Services.CurrencyService)
local CrystalService = require(Services.CrystalService)
local DevGalleryService = require(Services.DevGalleryService)
local BreedingService = require(Services.BreedingService)
local DragonService = require(Services.DragonService)
local EggService = require(Services.EggService)
local EggShopService = require(Services.EggShopService)
local IncomeService = require(Services.IncomeService)
local WorldFirstService = require(Services.WorldFirstService)

CurrencyService.Start()
CrystalService.Start()
DevGalleryService.Start()
EggService.Start()
EggShopService.Start()
DragonService.Start()
IncomeService.Start()
BreedingService.Start()
WorldFirstService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print("[Breed a Dragon] Server started")
