--!strict
-- Owns the player's dragon collection (data.Dragons) and which dragons are active (data.Active).
-- Active dragons earn Embers (see IncomeService) and follow their owner around
-- (drawn by every client, see client/Effects/DragonPets).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type Dragon = {
	Genes: Genes.DragonGenes,
	Born: number,
	Source: string,
	Generation: number?, -- 1 for dragons from shop eggs, +1 for every bred generation
	Locked: boolean?,
	RestUntil: number?, -- can't breed again until this time
	WorldFirst: boolean?, -- this player was the first in the world to get a dragon with this name
}

export type ActionResult = { Ok: boolean, Message: string? }

local DragonService = {}

local dragonsRemote = Remotes.Event("DragonsUpdated")
local actionRemote = Remotes.Function("DragonAction")
local actionLimiter = RateLimiter.new(0.15)

-- Keeps data.Active honest: only dragons that still exist, no repeats, no more than the slots.
local function cleanActive(data: { [string]: any })
	local seen: { [string]: boolean } = {}
	local cleaned = {}
	for _, id in data.Active or {} do
		if type(id) == "string" and data.Dragons[id] and not seen[id] and #cleaned < Config.Dragons.ActiveSlots then
			seen[id] = true
			table.insert(cleaned, id)
		end
	end
	data.Active = cleaned
end

local function isActive(data: { [string]: any }, id: string): number?
	return table.find(data.Active, id)
end

function DragonService.Count(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local count = 0
	for _ in data.Dragons do
		count += 1
	end
	return count
end

function DragonService.HasRoom(player: Player): boolean
	return DragonService.Count(player) < Config.Dragons.MaxOwned
end

-- Total Embers per second from the player's active dragons.
function DragonService.GetIncome(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, id in data.Active do
		local dragon = data.Dragons[id]
		if dragon then
			total += DragonStats.Income(dragon.Genes)
		end
	end
	return total
end

-- Sends the collection to the player's UI, and tells everyone which dragons follow them.
function DragonService.Publish(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	cleanActive(data)

	dragonsRemote:FireClient(player, {
		Dragons = data.Dragons,
		Active = data.Active,
		Slots = Config.Dragons.ActiveSlots,
		Max = Config.Dragons.MaxOwned,
		Index = data.Index,
		WorldFirsts = data.WorldFirsts,
		Now = os.time(),
	})

	local following = {}
	for _, id in data.Active do
		table.insert(following, data.Dragons[id].Genes)
	end
	player:SetAttribute("ActiveDragons", HttpService:JSONEncode(following))
	player:SetAttribute("Income", DragonService.GetIncome(player))
end

-- Marks a dragon's genes in the player's Dragon Index. Returns the ones that were new.
local function discover(data: { [string]: any }, genes: Genes.DragonGenes): { string }
	data.Index = data.Index or {}
	local found = {}
	for _, key in Genes.GetIndexKeys(genes) do
		if not data.Index[key] then
			data.Index[key] = true
			table.insert(found, key)
		end
	end
	return found
end

-- Adds a dragon to the collection (and makes it active if there's a free slot).
-- Returns its new id (nil if it couldn't) and the genes it added to the Dragon Index.
function DragonService.Add(
	player: Player,
	genes: Genes.DragonGenes,
	source: string,
	generation: number?
): (string?, { string })
	local data = DataService.GetData(player)
	if not data or not Genes.IsValid(genes) or not DragonService.HasRoom(player) then
		return nil, {}
	end
	local id = HttpService:GenerateGUID(false)
	local dragon: Dragon = { Genes = genes, Born = os.time(), Source = source, Generation = generation or 1 }
	data.Dragons[id] = dragon
	local newGenes = discover(data, genes)
	cleanActive(data)
	if #data.Active < Config.Dragons.ActiveSlots then
		table.insert(data.Active, id)
	end
	DragonService.Publish(player)
	return id, newGenes
end

function DragonService.Activate(player: Player, id: string): ActionResult
	local data = DataService.GetData(player)
	if not data or not data.Dragons[id] then
		return { Ok = false }
	end
	cleanActive(data)
	if isActive(data, id) then
		return { Ok = true }
	end
	if #data.Active >= Config.Dragons.ActiveSlots then
		return { Ok = false, Message = `You can have {Config.Dragons.ActiveSlots} active dragons. Put one away first.` }
	end
	table.insert(data.Active, id)
	return { Ok = true }
end

function DragonService.Deactivate(player: Player, id: string): ActionResult
	local data = DataService.GetData(player)
	if not data then
		return { Ok = false }
	end
	local index = isActive(data, id)
	if index then
		table.remove(data.Active, index)
	end
	return { Ok = true }
end

function DragonService.SetLocked(player: Player, id: string, locked: boolean): ActionResult
	local data = DataService.GetData(player)
	local dragon = data and data.Dragons[id]
	if not dragon then
		return { Ok = false }
	end
	dragon.Locked = if locked then true else nil
	return { Ok = true }
end

function DragonService.Sell(player: Player, id: string): ActionResult
	local data = DataService.GetData(player)
	local dragon = data and data.Dragons[id]
	if not data or not dragon then
		return { Ok = false }
	end
	if dragon.Locked then
		return { Ok = false, Message = "This dragon is locked. Unlock it first to sell it." }
	end
	local price = DragonStats.SellPrice(dragon.Genes)
	local name = Genes.GetName(dragon.Genes)
	DragonService.Deactivate(player, id)
	data.Dragons[id] = nil
	CurrencyService.Add(player, price)
	return { Ok = true, Message = `Sold {name} for {price} {Config.Currency.Name}.` }
end

local ACTIONS: { [string]: (Player, string) -> ActionResult } = {
	Activate = DragonService.Activate,
	Deactivate = DragonService.Deactivate,
	Lock = function(player, id)
		return DragonService.SetLocked(player, id, true)
	end,
	Unlock = function(player, id)
		return DragonService.SetLocked(player, id, false)
	end,
	Sell = DragonService.Sell,
}

function DragonService.Start()
	DataService.OnLoaded(function(player, data)
		-- Dragons from before the Index existed still count as discovered.
		for _, dragon in data.Dragons do
			if Genes.IsValid(dragon.Genes) then
				discover(data, dragon.Genes)
			end
		end
		DragonService.Publish(player)
	end)

	actionRemote.OnServerInvoke = function(player, action, id)
		if not actionLimiter:Check(player) then
			return { Ok = false }
		end
		local handler = if type(action) == "string" then ACTIONS[action] else nil
		if not handler or type(id) ~= "string" then
			return { Ok = false }
		end
		local result = handler(player, id)
		if result.Ok then
			DragonService.Publish(player)
		end
		return result
	end
end

return DragonService
