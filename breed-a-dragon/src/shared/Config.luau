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
	AnnounceFrom = "Legendary", -- hatching this rarity or better is announced to the whole server
}

Config.Dev = {
	-- Studio only: show a gallery of random dragons in front of the spawn (never in the live game).
	DragonGallery = true,
}

return Config
