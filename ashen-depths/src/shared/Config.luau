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

	-- The bag holds this many items; the hotbar has this many slots (1 = the weapon, 2-4 = potions later).
	BagSize = 30,
	HotbarSize = 4,

	-- While building: every player gets one weapon of each type, and enemies come back after dying.
	-- Turn off before launch.
	TestMode = true,

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
	TestNoDamage = true,

	-- While testing: the run starts on this floor instead of floor 1 (5 = the Gravekeeper's floor).
	TestStartFloor = nil :: number?, -- start every run on this floor (testing); nil = normal

	-- While testing: when set, every floor's monsters are picked from this list instead of the normal mix.
	-- Set to nil to go back to the real per-floor mix.
	TestEnemyMix = {
		{ Name = "Rat", Weight = 4 },
		{ Name = "SkeletonArcher", Weight = 4 },
		{ Name = "Skeleton", Weight = 2 },
	},
}
