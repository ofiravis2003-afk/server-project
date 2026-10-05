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
	-- Skin textures: MaterialVariants in MaterialService with these names (made in Studio's
	-- Material Manager). If one exists, the Tripo dragon's body (or wings) wears it, tinted by
	-- the gene colour. Genes with their own special material (glass, neon...) keep that.
	SkinVariant = "DragonScale",
	WingVariant = "DragonWing",
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

Config.Island = {
	Radius = 160, -- Ember Isle, in studs around the spawn point (trees and rocks grow with it)
	RemoveBaseplate = true, -- the grey Baseplate is removed while playing so the island floats in the sky
	FallRescueDepth = 60, -- players who fall this far below the island are put back on the spawn
	ElderOffset = Vector3.new(-42, 0, 6), -- where Elder Ember stands, from the spawn point
	-- Trees and bushes made from code look like toys, so they are off: put real tree models from
	-- the Toolbox in ServerStorage/IslandAssets instead (see README). true = use the code ones.
	CodeTrees = false,
}

Config.Tutorial = {
	StarterEgg = "Rare", -- the free egg every new player gets in their first nest
	StarterHatchTime = 15, -- seconds: the first dragon should come within the first minute
}

Config.Dev = {
	-- Studio only: a test gallery of 20 random dragons north of the spawn (never in the live game).
	-- Turn it on (true) only to check how varied the dragons look.
	DragonGallery = false,
}

return Config
