--!strict
-- The first 60 seconds: every new player finds a free egg already warming in their first nest,
-- so they have a dragon within a minute of joining (the first quest is to hatch it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.Eggs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)

local StarterEggService = {}

local notifyRemote = Remotes.Event("Notify")

function StarterEggService.Give(player: Player, data: { [string]: any })
	if data.StarterEgg then
		return
	end
	local egg = Eggs.Get(Config.Tutorial.StarterEgg)
	if not egg then
		return
	end
	if EggService.PlaceEgg(player, egg.Id, Config.Tutorial.StarterHatchTime) then
		data.StarterEgg = true
		notifyRemote:FireClient(player, `🎁 Elder Ember gave you a {egg.Name}! It hatches in a few seconds.`)
	end
end

function StarterEggService.Start()
	DataService.OnLoaded(StarterEggService.Give)
end

return StarterEggService
