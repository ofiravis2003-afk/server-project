--!strict
-- 🏆 World First: the first player in the whole world to get an Epic-or-better dragon
-- with a given name (e.g. "Huge Frozen Violet Wyvern") is recorded as its discoverer forever.
--
-- The record lives in one shared DataStore. UpdateAsync makes claiming safe: if two players
-- on different servers get the same dragon at the same moment, only one of them wins.
-- Legendary+ World Firsts are announced on every server through MessagingService;
-- Epic ones only to the player who found them.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "WorldFirsts_v1"
local TOPIC = "WorldFirst"

local WorldFirstService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local notifyRemote = Remotes.Event("Notify")
-- Names we already know are taken, so we don't ask the DataStore again.
local knownClaimed: { [string]: boolean } = {}

local function notifyEveryoneHere(text: string)
	for _, player in Players:GetPlayers() do
		notifyRemote:FireClient(player, text)
	end
end

function WorldFirstService.Qualifies(genes: Genes.DragonGenes): boolean
	return Genes.GetRarity(genes).Order >= Rarity.Get(Config.WorldFirst.MinRarity).Order
end

-- Tries to record `player` as the first in the world to get this dragon.
-- Returns true if they were first. Waits for the DataStore, so call it where yielding is fine.
function WorldFirstService.TryClaim(player: Player, genes: Genes.DragonGenes): boolean
	if not WorldFirstService.Qualifies(genes) then
		return false
	end
	local name = Genes.GetName(genes)
	if knownClaimed[name] then
		return false
	end

	local claimed = false
	local ok, err = pcall(function()
		store:UpdateAsync(name, function(old: any): any
			claimed = false
			if old ~= nil then
				return nil -- someone got here first; change nothing
			end
			claimed = true
			return { UserId = player.UserId, Name = player.DisplayName, Time = os.time() }
		end)
	end)
	if not ok then
		warn(`[WorldFirst] Could not check "{name}": {err}`)
		return false
	end
	knownClaimed[name] = true
	return claimed
end

-- Epic World Firsts are told only to the player (early on almost every Epic is one, and
-- announcing them all would be spam). Legendary+ ones go to this server and every other server.
function WorldFirstService.Announce(player: Player, genes: Genes.DragonGenes)
	local rarity = Genes.GetRarity(genes)
	local text = `🏆 WORLD FIRST! {player.DisplayName} discovered the {rarity.Name} {Genes.GetName(genes)}!`
	if rarity.Order < Rarity.Get(Config.WorldFirst.AnnounceEverywhereFrom).Order then
		notifyRemote:FireClient(
			player,
			`🏆 WORLD FIRST! You're the first in the world to find the {Genes.GetName(genes)}!`
		)
		return
	end

	notifyEveryoneHere(text)
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, { Text = text, JobId = game.JobId })
	end)
	if not ok then
		warn(`[WorldFirst] Could not announce to other servers: {err}`)
	end
end

function WorldFirstService.Start()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local payload = message.Data
			-- This server already showed its own announcement.
			if type(payload) == "table" and payload.JobId ~= game.JobId and type(payload.Text) == "string" then
				notifyEveryoneHere(payload.Text)
			end
		end)
	end)
	if not ok then
		warn(`[WorldFirst] Cross-server announcements are off: {err}`)
	end
end

return WorldFirstService
