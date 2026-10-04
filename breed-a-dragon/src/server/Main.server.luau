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
local ElderService = require(Services.ElderService)
local EggService = require(Services.EggService)
local EggShopService = require(Services.EggShopService)
local IncomeService = require(Services.IncomeService)
local IslandService = require(Services.IslandService)
local QuestService = require(Services.QuestService)
local StarterEggService = require(Services.StarterEggService)
local WorldFirstService = require(Services.WorldFirstService)

IslandService.Start() -- first: the rest of the world stands on it
CurrencyService.Start()
CrystalService.Start()
DevGalleryService.Start()
EggService.Start()
EggShopService.Start()
DragonService.Start()
IncomeService.Start()
BreedingService.Start()
WorldFirstService.Start()
QuestService.Start()
StarterEggService.Start()
ElderService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print("[Breed a Dragon] Server started")
