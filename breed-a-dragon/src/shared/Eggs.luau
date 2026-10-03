--!strict
-- Every egg that can be bought. Prices are in Embers, hatch times in seconds.
-- Weights are the chances of each gene tier (see Rarity) when a dragon hatches from this egg:
-- better eggs roll rarer genes more often. Players see the resulting odds before buying.
-- Weights were tuned so the overall odds come out at roughly:
--   Common Egg  80% Common | 16% Rare | 3.6% Epic | 0.34% Legendary | 0.02% Mythic
--   Rare Egg    48% Common | 35% Rare | 14% Epic  | 2.7% Legendary  | 0.3% Mythic
--   Ember Egg   26% Common | 36% Rare | 29% Epic  | 7.8% Legendary  | 1% Mythic

local Genes = require(script.Parent.Genes)

export type Egg = {
	Id: string,
	Name: string,
	Price: number,
	HatchTime: number,
	Weights: Genes.RarityWeights,
	Color: Color3,
	SpotColor: Color3,
	Glow: boolean?,
	Hidden: boolean?, -- not sold in the shop (e.g. eggs that come from breeding)
}

local LIST: { Egg } = {
	{
		Id = "Common",
		Name = "Common Egg",
		Price = 25,
		HatchTime = 30,
		Weights = { Common = 100, Rare = 25, Epic = 16, Legendary = 1.25, Mythic = 0.5 },
		Color = Color3.fromRGB(235, 225, 200),
		SpotColor = Color3.fromRGB(170, 150, 120),
	},
	{
		Id = "Rare",
		Name = "Rare Egg",
		Price = 150,
		HatchTime = 120,
		Weights = { Common = 100, Rare = 40, Epic = 32, Legendary = 6.3, Mythic = 1.6 },
		Color = Color3.fromRGB(90, 160, 235),
		SpotColor = Color3.fromRGB(220, 240, 255),
	},
	{
		Id = "Ember",
		Name = "Ember Egg",
		Price = 600,
		HatchTime = 300,
		Weights = { Common = 100, Rare = 50, Epic = 32, Legendary = 25, Mythic = 1 },
		Color = Color3.fromRGB(230, 90, 40),
		SpotColor = Color3.fromRGB(255, 200, 70),
		Glow = true,
	},
	{
		-- Made by breeding two dragons. Its genes are decided when it is laid, not when it hatches.
		Id = "Bred",
		Name = "Bred Egg",
		Price = 0,
		HatchTime = 60,
		Weights = { Common = 1 },
		Color = Color3.fromRGB(255, 150, 195),
		SpotColor = Color3.fromRGB(255, 235, 140),
		Glow = true,
		Hidden = true,
	},
}

local byId: { [string]: Egg } = {}
for _, egg in LIST do
	byId[egg.Id] = egg
end

local oddsCache: { [string]: { [string]: number } } = {}

local Eggs = {}

Eggs.List = LIST

function Eggs.Get(id: string): Egg?
	return byId[id]
end

-- Chance of each overall dragon rarity from this egg, e.g. { Common = 0.71, ... }.
function Eggs.GetOdds(id: string): { [string]: number }
	if not oddsCache[id] then
		local egg = byId[id]
		assert(egg, `Unknown egg {id}`)
		oddsCache[id] = Genes.GetRarityOdds(egg.Weights)
	end
	return oddsCache[id]
end

-- "12%", "0.8%", "0.05%": readable without hiding how small a chance is.
function Eggs.FormatChance(chance: number): string
	local percent = chance * 100
	if percent >= 10 then
		return string.format("%d%%", math.floor(percent + 0.5))
	elseif percent >= 1 then
		return string.format("%.1f%%", percent)
	elseif percent >= 0.1 then
		return string.format("%.2f%%", percent)
	end
	return string.format("%.3f%%", percent)
end

return Eggs
