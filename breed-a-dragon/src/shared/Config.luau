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

return Config
