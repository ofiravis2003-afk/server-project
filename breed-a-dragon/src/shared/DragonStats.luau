--!strict
-- How much a dragon earns and sells for. Shared so the UI shows exactly what the server pays.

local Config = require(script.Parent.Config)
local Genes = require(script.Parent.Genes)

local DragonStats = {}

-- Embers per second this dragon makes while active.
function DragonStats.Income(genes: Genes.DragonGenes): number
	local rarity = Genes.GetRarity(genes)
	local base = Config.Income.PerSecond[rarity.Name] or 0
	local bonus = 1 + Genes.GetScore(genes) * Config.Income.BonusPerPoint
	-- One decimal place, so the numbers stay readable.
	return math.floor(base * bonus * 10 + 0.5) / 10
end

function DragonStats.SellPrice(genes: Genes.DragonGenes): number
	return Config.Sell.Price[Genes.GetRarity(genes).Name] or 0
end

return DragonStats
