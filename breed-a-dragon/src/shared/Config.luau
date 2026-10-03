--!strict
-- Every balance number in the game lives here.
-- Tune the game by changing values in this file, not inside the systems.

local Config = {}

Config.Currency = {
	Name = "Embers",
	Icon = "🔥",
}

Config.Crystal = {
	Count = 6,
	Radius = 24, -- studs from the spawn point
	Reward = 1, -- Embers per click
	Cooldown = 0.2, -- seconds a player must wait between clicks
	MaxClickDistance = 32,
}

Config.Nests = {
	Base = 3, -- nests every player has (Game Passes can add more later)
}

Config.Dragons = {
	MaxOwned = 60, -- dragons a player can keep at once
	ActiveSlots = 4, -- dragons that can be active (earning + following you) at once
	AnnounceFrom = "Legendary", -- hatching this rarity or better is announced to the whole server
	PetScale = 0.35, -- size of active dragons following the player, compared to full size
}

Config.Income = {
	-- Embers per second an active dragon makes, by its overall rarity...
	PerSecond = { Common = 1, Rare = 3, Epic = 8, Legendary = 25, Mythic = 80 },
	-- ...plus this much extra per rarity point of its genes (0.05 = +5% per point).
	BonusPerPoint = 0.05,
	OfflineRate = 0.5, -- share of normal income earned while offline
	OfflineMaxHours = 8,
}

Config.Sell = {
	-- Embers you get for selling a dragon, by its overall rarity.
	Price = { Common = 10, Rare = 40, Epic = 150, Legendary = 600, Mythic = 2500 },
}

Config.Dev = {
	-- Studio only: show a gallery of random dragons in front of the spawn (never in the live game).
	DragonGallery = true,
}

return Config
