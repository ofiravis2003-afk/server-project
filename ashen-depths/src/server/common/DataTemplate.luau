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
	FirstJoinTime = 0,
	LastJoinTime = 0,
}
