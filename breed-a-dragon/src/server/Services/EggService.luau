--!strict
-- Buying eggs, keeping them warm in nests, and hatching them into dragons.
--
-- An egg in a nest only stores the time it is ready (HatchAt), so it keeps
-- incubating while the player is offline. The server decides everything:
-- the client can only ask to hatch, and gets told no if the egg isn't ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.Eggs)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DragonService = require(script.Parent.DragonService)
local QuestService = require(script.Parent.QuestService)
local WorldFirstService = require(script.Parent.WorldFirstService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

-- Clocks on different machines can be a moment apart; don't refuse an egg that is ready "now".
local CLOCK_TOLERANCE = 1

-- Genes/Generation/Mutated are only set on Bred Eggs: the baby is decided when the egg is laid.
export type NestEgg = {
	Nest: number,
	Egg: string,
	HatchAt: number,
	Genes: Genes.DragonGenes?,
	Generation: number?,
	Mutated: { string }?,
}
export type HatchResult = {
	Ok: boolean,
	Message: string?,
	DragonId: string?,
	Genes: Genes.DragonGenes?,
	Egg: string?,
	NewGenes: { string }?, -- genes that were new to the player's Dragon Index
	Mutated: { string }?, -- traits that mutated while breeding
	WorldFirst: boolean?,
}

local EggService = {}

local rng = Random.new()
local hatchLimiter = RateLimiter.new(0.5)
local notifyRemote = Remotes.Event("Notify")
local nestsRemote = Remotes.Event("NestsUpdated")
local hatchRemote = Remotes.Function("HatchEgg")

function EggService.GetNestCount(_player: Player): number
	return Config.Nests.Base
end

local function sendNests(player: Player)
	local data = DataService.GetData(player)
	if data then
		-- Only what the nests bar needs: a Bred Egg's genes stay a surprise until it hatches.
		local eggs = {}
		for _, entry in data.Nests do
			table.insert(eggs, { Nest = entry.Nest, Egg = entry.Egg, HatchAt = entry.HatchAt })
		end
		nestsRemote:FireClient(player, { NestCount = EggService.GetNestCount(player), Eggs = eggs })
	end
end

local function findFreeNest(player: Player, nests: { NestEgg }): number?
	local taken: { [number]: boolean } = {}
	for _, entry in nests do
		taken[entry.Nest] = true
	end
	for nest = 1, EggService.GetNestCount(player) do
		if not taken[nest] then
			return nest
		end
	end
	return nil
end

function EggService.HasFreeNest(player: Player): boolean
	local data = DataService.GetData(player)
	return data ~= nil and findFreeNest(player, data.Nests) ~= nil
end

-- Puts an egg in the first free nest, hatching in `hatchTime` seconds. Returns the nest, or nil if all are full.
function EggService.PlaceEgg(
	player: Player,
	eggId: string,
	hatchTime: number,
	bred: { Genes: Genes.DragonGenes, Generation: number, Mutated: { string } }?
): number?
	local data = DataService.GetData(player)
	local nest = data and findFreeNest(player, data.Nests)
	if not data or not nest then
		return nil
	end
	local entry: NestEgg = { Nest = nest, Egg = eggId, HatchAt = os.time() + hatchTime }
	if bred then
		entry.Genes = bred.Genes
		entry.Generation = bred.Generation
		entry.Mutated = bred.Mutated
	end
	table.insert(data.Nests, entry)
	sendNests(player)
	return nest
end

-- Buys an egg and puts it in the first free nest. Returns whether it worked and a message for the player.
function EggService.Buy(player: Player, eggId: string): (boolean, string)
	local egg = Eggs.Get(eggId)
	local data = DataService.GetData(player)
	if not egg or egg.Hidden or not data then
		return false, "Please wait a moment and try again."
	end

	local nest = findFreeNest(player, data.Nests)
	if not nest then
		return false, "All your nests are full! Hatch an egg first."
	end
	if not CurrencyService.Spend(player, egg.Price) then
		local missing = egg.Price - CurrencyService.Get(player)
		return false, `You need {missing} more {Config.Currency.Name} for a {egg.Name}.`
	end

	EggService.PlaceEgg(player, egg.Id, egg.HatchTime)
	QuestService.Record(player, "BuyEgg")
	return true, `{egg.Name} placed in nest {nest}!`
end

local function announce(player: Player, genes: Genes.DragonGenes)
	local rarity = Genes.GetRarity(genes)
	if rarity.Order < Rarity.Get(Config.Dragons.AnnounceFrom).Order then
		return
	end
	local text = `{player.DisplayName} just hatched a {rarity.Name} {Genes.GetName(genes)}!`
	for _, other in Players:GetPlayers() do
		notifyRemote:FireClient(other, text)
	end
end

function EggService.Hatch(player: Player, nest: any): HatchResult
	local data = DataService.GetData(player)
	if not data then
		return { Ok = false, Message = "Please wait a moment and try again." }
	end
	if type(nest) ~= "number" or nest ~= math.floor(nest) then
		return { Ok = false }
	end

	local index: number?
	for i, entry in data.Nests do
		if entry.Nest == nest then
			index = i
			break
		end
	end
	if not index then
		return { Ok = false, Message = "There's no egg in that nest." }
	end

	local entry: NestEgg = data.Nests[index]
	if os.time() + CLOCK_TOLERANCE < entry.HatchAt then
		return { Ok = false, Message = "This egg isn't ready yet!" }
	end
	if not DragonService.HasRoom(player) then
		return { Ok = false, Message = `You have the most dragons you can keep ({Config.Dragons.MaxOwned}).` }
	end
	local egg = Eggs.Get(entry.Egg)
	if not egg then
		return { Ok = false }
	end

	-- A Bred Egg already knows its baby; shop eggs roll one now.
	local genes = if entry.Genes and Genes.IsValid(entry.Genes) then entry.Genes else Genes.Roll(rng, egg.Weights)
	local dragonId, newGenes = DragonService.Add(player, genes, "Egg:" .. egg.Id, entry.Generation)
	if not dragonId then
		return { Ok = false, Message = "Something went wrong, please try again." }
	end
	table.remove(data.Nests, index)
	sendNests(player)
	QuestService.Record(player, "Hatch")
	if egg.Id == "Bred" then
		QuestService.Record(player, "HatchBred")
	end

	-- Waits for the shared World First record, so do it after the egg is safely hatched.
	local worldFirst = WorldFirstService.TryClaim(player, genes)
	local dragon = data.Dragons[dragonId]
	if worldFirst and dragon then
		dragon.WorldFirst = true
		data.WorldFirsts = data.WorldFirsts or {}
		table.insert(data.WorldFirsts, Genes.GetName(genes))
		DragonService.Publish(player)
		WorldFirstService.Announce(player, genes)
	else
		announce(player, genes)
	end

	return {
		Ok = true,
		DragonId = dragonId,
		Genes = genes,
		Egg = egg.Id,
		NewGenes = newGenes,
		Mutated = entry.Mutated,
		WorldFirst = worldFirst,
	}
end

function EggService.Start()
	DataService.OnLoaded(function(player)
		sendNests(player)
	end)

	hatchRemote.OnServerInvoke = function(player, nest)
		if not hatchLimiter:Check(player) then
			return { Ok = false }
		end
		return EggService.Hatch(player, nest)
	end
end

return EggService
