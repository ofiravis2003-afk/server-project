--!strict
-- Rarity tiers, from most common to rarest.
--   Weight: how often a gene of this tier is rolled (relative to the other tiers).
--   Points: how much a gene of this tier adds to the dragon's overall rarity score.
--   MinScore: the overall score a dragon needs to count as this tier.

export type Tier = {
	Name: string,
	Order: number,
	Color: Color3,
	Weight: number,
	Points: number,
	MinScore: number,
}

local TIERS: { Tier } = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(200, 200, 200), Weight = 60, Points = 0, MinScore = 0 },
	{ Name = "Rare", Order = 2, Color = Color3.fromRGB(70, 160, 255), Weight = 25, Points = 1, MinScore = 8 },
	{ Name = "Epic", Order = 3, Color = Color3.fromRGB(175, 90, 255), Weight = 10, Points = 3, MinScore = 13 },
	{ Name = "Legendary", Order = 4, Color = Color3.fromRGB(255, 185, 40), Weight = 4, Points = 6, MinScore = 20 },
	{ Name = "Mythic", Order = 5, Color = Color3.fromRGB(255, 60, 130), Weight = 1, Points = 12, MinScore = 28 },
}

local byName: { [string]: Tier } = {}
for _, tier in TIERS do
	byName[tier.Name] = tier
end

local Rarity = {}

Rarity.Tiers = TIERS

function Rarity.Get(name: string): Tier
	return byName[name] or TIERS[1]
end

-- The highest tier whose MinScore the score reaches.
function Rarity.FromScore(score: number): Tier
	local result = TIERS[1]
	for _, tier in TIERS do
		if score >= tier.MinScore then
			result = tier
		end
	end
	return result
end

return Rarity
