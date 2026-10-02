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

CurrencyService.Start()
CrystalService.Start()
DevGalleryService.Start()

-- Last: everything that reacts to a player's data loading has registered by now.
DataService.Start()

print("[Breed a Dragon] Server started")
