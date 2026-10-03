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

-- The average sell price of a baby of these two, mutations included (worked out exactly).
function DragonStats.ExpectedBabyPrice(a: Genes.DragonGenes, b: Genes.DragonGenes): number
	local odds = Genes.GetBabyRarityOdds(a, b, Config.Breeding.MutationChance, Config.Breeding.MutationWeights)
	local total = 0
	for rarity, chance in odds do
		total += (Config.Sell.Price[rarity] or 0) * chance
	end
	return total
end

-- Embers it costs to breed these two dragons.
function DragonStats.BreedFee(a: Genes.DragonGenes, b: Genes.DragonGenes): number
	local fee = DragonStats.ExpectedBabyPrice(a, b) * Config.Breeding.FeeMultiplier
	return math.max(Config.Breeding.MinFee, math.floor(fee))
end

-- Seconds until their egg hatches (set by the rarer parent).
function DragonStats.BreedTime(a: Genes.DragonGenes, b: Genes.DragonGenes): number
	local rarityA, rarityB = Genes.GetRarity(a), Genes.GetRarity(b)
	local rarer = if rarityA.Order >= rarityB.Order then rarityA else rarityB
	return Config.Breeding.HatchTime[rarer.Name] or 60
end

return DragonStats
