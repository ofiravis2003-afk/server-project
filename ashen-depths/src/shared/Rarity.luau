--!strict
-- Item rarities, weakest to strongest. `Power` multiplies an item's base stats.

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

local Rarity = {
	Order = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Info = {
		Common = { Color = Color3.fromRGB(170, 170, 170), Power = 1 },
		Rare = { Color = Color3.fromRGB(70, 140, 255), Power = 1.25 },
		Epic = { Color = Color3.fromRGB(170, 80, 255), Power = 1.6 },
		Legendary = { Color = Color3.fromRGB(255, 190, 60), Power = 2.1 },
		Mythic = { Color = Color3.fromRGB(235, 50, 50), Power = 2.8 },
	},
}

return Rarity
