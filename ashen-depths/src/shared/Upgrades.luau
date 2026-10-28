--!strict
-- What Brakka asks to raise a weapon to the next level (+1 .. +10), and how likely it is to hold.
-- Each level adds 10% to the weapon's damage (Items.WeaponDamage). Up to +5 it always works; from +6 it can
-- fail, and then the gold and materials are gone but the weapon stays as it was (it never breaks).
-- The Rotwood Caverns' weapons (Items Chapter 2) want the caverns' own materials from +6: Spore Caps, and for
-- the last steps the hide of the Rotgut Toad and the Mother Spore's heartwood.

local Items = require(script.Parent.Items)

local Upgrades = {}

Upgrades.Max = 10

export type Cost = { Gold: number, Materials: { { Item: string, Count: number } }, Chance: number }

local RARITY_GOLD: { [string]: number } = { Common = 1, Rare = 1.5, Epic = 2.2, Legendary = 3, Mythic = 4 }
local CHANCE = { [6] = 0.8, [7] = 0.65, [8] = 0.5, [9] = 0.4, [10] = 0.3 }

-- The cost of taking a weapon (`itemName`) of `rarity` up to level `target`.
function Upgrades.Cost(rarity: string, target: number, itemName: string?): Cost
	local gold = math.floor(30 * target * target * (RARITY_GOLD[rarity] or 1))
	local materials: { { Item: string, Count: number } }
	local def = itemName and Items.Defs[itemName]
	if def and def.Chapter == 2 and target >= 6 then
		if target <= 7 then
			materials = { { Item = "Bone", Count = 2 * target }, { Item = "SporeCap", Count = target } }
		elseif target <= 9 then
			materials = { { Item = "SporeCap", Count = 2 * target }, { Item = "SlimeGel", Count = target }, { Item = "ToadHide", Count = 1 } }
		else
			materials = { { Item = "SporeCap", Count = 25 }, { Item = "ToadHide", Count = 2 }, { Item = "Heartwood", Count = 1 } }
		end
		return { Gold = gold, Materials = materials, Chance = CHANCE[target] or 1 }
	end
	if target <= 3 then
		materials = { { Item = "Bone", Count = 3 * target } }
	elseif target <= 6 then
		materials = { { Item = "Bone", Count = 3 * target }, { Item = "Fletching", Count = target } }
	elseif target <= 9 then
		materials = { { Item = "Bone", Count = 2 * target }, { Item = "Fletching", Count = target }, { Item = "SlimeGel", Count = target } }
	else
		materials = { { Item = "Bone", Count = 20 }, { Item = "SlimeGel", Count = 10 }, { Item = "GraveShroud", Count = 2 } }
	end
	return { Gold = gold, Materials = materials, Chance = CHANCE[target] or 1 }
end

return Upgrades
