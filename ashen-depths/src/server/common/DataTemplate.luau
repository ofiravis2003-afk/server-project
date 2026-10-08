--!strict
-- What a brand-new player's save looks like. One save, shared by Emberhold and Depths.
-- Adding a new field here is safe: existing saves get it filled in on their next join.

return {
	Level = 1,
	XP = 0,
	Gold = 0,
	Inventory = {}, -- [itemId] = { Item = "IronSword", Rarity = "Common", Upgrade = 0 }
	Equipped = {}, -- [slot] = itemId, slots: Head, Chest, Hands, Legs, Weapon, Ring
	GuildRank = "Copper",
	DeepestFloor = 0,
	Checkpoint = 0, -- last boss floor beaten; a new run can start right after it
	Quests = {},
	Receipts = {}, -- ids of the last Robux purchases already given, so none is ever given twice
	JoinCount = 0,
	FirstJoinTime = 0,
	LastJoinTime = 0,
}
