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
	-- Where the eyes go on the Tripo model, found automatically from the tip of the snout.
	-- All three are fractions of the HeadNeck mesh's height; tweak them if the eyes sit wrong.
	MeshEyes = {
		Back = 0.24, -- how far behind the snout tip
		Up = 0.1, -- how far above the snout tip
		Size = 0.07, -- eye diameter
		TopBack = 0.38, -- crowns and halos sit on the skull this far behind the snout tip...
		TopUp = 0.03, -- ...and this far above its surface
	},
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

Config.Breeding = {
	-- Fee = the baby's expected sell price times this (at least MinFee), so breeding
	-- and then selling the baby never makes a profit on its own. A bit over 1 covers mutations.
	FeeMultiplier = 1.1,
	MinFee = 25,
	ParentRest = 120, -- seconds a dragon must rest after breeding
	MutationChance = 0.06, -- chance per trait that the baby gets a new gene neither parent has
	MutationWeights = { Common = 40, Rare = 35, Epic = 17, Legendary = 6, Mythic = 2 }, -- mutations lean rare
	-- Seconds until the bred egg hatches, by the rarer parent's rarity.
	HatchTime = { Common = 60, Rare = 120, Epic = 300, Legendary = 600, Mythic = 900 },
}

Config.WorldFirst = {
	MinRarity = "Epic", -- dragons this rare or better can be a World First
	AnnounceEverywhereFrom = "Legendary", -- these are announced on every server; rarer-than-MinRarity ones only to the finder
}

Config.Dev = {
	-- Studio only: show a gallery of random dragons in front of the spawn (never in the live game).
	DragonGallery = true,
}

return Config
