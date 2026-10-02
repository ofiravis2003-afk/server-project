--!strict
-- Owns the player's dragon collection (saved in data.Dragons).
-- Phase 4 adds placing dragons on the island, income and selling on top of this.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Genes = require(ReplicatedStorage.Shared.Genes)
local DataService = require(script.Parent.DataService)

export type Dragon = {
	Genes: Genes.DragonGenes,
	Born: number,
	Source: string,
}

local DragonService = {}

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

-- Adds a dragon to the player's collection. Returns its new id, or nil if it couldn't.
function DragonService.Add(player: Player, genes: Genes.DragonGenes, source: string): string?
	local data = DataService.GetData(player)
	if not data or not Genes.IsValid(genes) or not DragonService.HasRoom(player) then
		return nil
	end
	local id = HttpService:GenerateGUID(false)
	local dragon: Dragon = { Genes = genes, Born = os.time(), Source = source }
	data.Dragons[id] = dragon
	return id
end

return DragonService
