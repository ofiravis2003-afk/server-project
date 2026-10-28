--!strict
-- What a brand-new player's save looks like. One save, shared by Emberhold and Depths.
-- Adding a new field here is safe: existing saves get it filled in on their next join.

return {
	Level = 1,
	XP = 0,
	Gold = 0,
	NextItemId = 1, -- every item gets its own id, so two Rusty Swords are still two items
	Inventory = {}, -- [itemId] = { Item = "IronSword", Rarity = "Common", Upgrade = 0 }
	Equipped = {}, -- [slot] = itemId, slots: Head, Chest, Hands, Legs, Weapon, Ring
	GuildRank = "Copper",
	RankPoints = 0, -- from finished Guild quests; decides GuildRank (shared/Quests Ranks)
	DeepestFloor = 0,
	Checkpoint = 0, -- last boss floor beaten; a new run can start right after it
	Quests = {},
	Pages = {}, -- [pageId] = true: the pages of Ilvane's journal this player has found (shared/Lore)
	WardLit = 0, -- the deepest floor whose Wardstone this player has relit
	Receipts = {}, -- ids of the last Robux purchases already given, so none is ever given twice
	JoinCount = 0,
	FounderNumber = nil :: number?, -- one of the first 250 adventurers (FounderService)
	FounderGiven = nil :: boolean?, -- their Founder's Emberblade is in the bag
	DailyDay = 0, -- the last day (shared/Daily Today) the daily gift was given
	DailyStreak = 0, -- days in a row
	DailyTasks = {}, -- today's three tasks: { Id, Progress, Done }
	Tips = {}, -- [tipId] = true: the new-adventurer tips this player has seen (TipService)
	Referrals = {}, -- [userId] = true: friends this player brought in with a game invite (ReferralService)
	IntroDone = nil :: boolean?, -- the first-visit fly-over and Aldric's Brand (IntroService); nil = decide on load
	Title = "Adventurer", -- the title worn over the head (shared/Titles)
	Kills = {}, -- [enemy name] = how many this player has slain (for titles)
	BestDps = 0, -- the best damage per second dealt in the Training Yard
	FullParty = nil :: boolean?, -- went down the Well with a full party of four
	ChapterIIMoved = nil :: boolean?, -- this save was moved to chapter II's floors (Migrations)
	HollowReached = nil :: boolean?, -- had been in The Hollow before chapter II moved it down (Migrations)
	FirstJoinTime = 0,
	LastJoinTime = 0,
}
