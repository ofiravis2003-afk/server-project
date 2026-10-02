--!strict
-- What a brand-new player's save looks like.
-- Adding a new field here is safe: existing saves get it filled in on their next join.

return {
	Embers = 0,
	TotalEmbersEarned = 0,
	Dragons = {}, -- [dragonId] = { Genes = {...}, Born = time, Source = "Egg:Common" }
	Nests = {}, -- eggs incubating: { { Nest = 1, Egg = "Common", HatchAt = time }, ... }
	UnlockedIslands = { "EmberIsle" },
	Rebirths = 0,
	Quests = {},
	JoinCount = 0,
	FirstJoinTime = 0,
	LastJoinTime = 0,
}
