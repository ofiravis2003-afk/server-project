--!strict
-- Game-wide settings shared by both places (Emberhold and Depths).

return {
	-- Bump this on any change: both places print it on start, so you can see they run the same code.
	Version = "0.2.0",

	-- Place ids, filled in after the places are created on the Roblox website (step 0.1).
	PlaceIds = {
		Emberhold = 127167308890339,
		Depths = 94536878288268,
	},

	MaxPartySize = 4,

	-- Chapter II (the Rotwood Caverns, floors 16-30), being built: off, so the live game stays as it is
	-- (The Hollow from floor 16). On, chapter II takes floors 16-30 and The Hollow starts at 31.
	ChapterII = false,

	-- Robux purchases (created in the Creator Hub, 2026-10-24). Passes are bought once; products again and again.
	Passes = {
		BiggerBag = 2053631231, -- the bag holds twice as much
		VIP = 2053205147, -- +20% gold and XP from kills, a VIP tag
		PotionBelt = 2053163152, -- carry 5 of each potion instead of 3
	},
	-- Roblox badges (0 = not created yet, not given).
	Badges = {
		Founder = 4321961558595406, -- one of the first 250 (FounderService)
		Gravekeeper = 946718100821034, -- the Gravekeeper defeated (floor 5)
		BoneWarden = 929651792145795, -- the Bone Warden defeated (floor 15)
		Hollow = 1481544442634936, -- reached The Hollow (floor 16)
		Party = 3082723086033753, -- went down with a full party of four
	},
	Products = {
		GoldSmall = { Id = 3721731265, Gold = 500 }, -- Small Gold Pouch
		GoldMedium = { Id = 3721731387, Gold = 1750 }, -- Gold Sack
		GoldLarge = { Id = 3721731488, Gold = 5000 }, -- Gold Chest
		Revive = { Id = 3721731566 }, -- rise where you fell (the Depths)
	},

	-- The bag holds this many items; the hotbar has this many slots (1 = the weapon, 2-4 = potions later).
	BagSize = 30,
	HotbarSize = 4,

	-- While building: every player gets one weapon of each type, and enemies come back after dying.
	-- Turn off before launch.
	TestMode = false,

	-- Depths only: true starts players in the TestArena (a fixed room for trying weapons)
	-- instead of on floor 1 of the dungeon.
	StartInTestArena = false,

	-- While testing: a player's weapons are replaced by exactly these, once per different list (later loot stays).
	-- Now: back to the plain starter weapons after trying the special looks (2026-10-11).
	TestLoadout = {
		{ Item = "RustySword", Rarity = "Common" },
		{ Item = "WoodcutterAxe", Rarity = "Common" },
		{ Item = "ApprenticeStaff", Rarity = "Common" },
		{ Item = "AcolyteTome", Rarity = "Common" },
	} :: { { Item: string, Rarity: string } }?,

	-- While testing: players take no damage (an invisible force field), to watch a fight closely.
	TestNoDamage = false,

	-- While testing: the run starts on this floor instead of floor 1 (5 = the Gravekeeper's floor).
	TestStartFloor = nil :: number?, -- start every run on this floor (testing); nil = normal

	-- While testing: when set, every floor's monsters are picked from this list instead of the normal mix.
	-- Set to nil to go back to the real per-floor mix.
	TestEnemyMix = nil :: { { Name: string, Weight: number } }?,
}
