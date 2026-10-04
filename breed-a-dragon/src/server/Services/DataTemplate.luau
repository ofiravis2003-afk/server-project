--!strict
-- What a brand-new player's save looks like.
-- Adding a new field here is safe: existing saves get it filled in on their next join.

return {
	Embers = 0,
	TotalEmbersEarned = 0,
	-- [dragonId] = { Genes = {...}, Born = time, Source = "Egg:Common", Generation = 1,
	--               Locked = true?, RestUntil = time?, WorldFirst = true? }
	Dragons = {},
	Active = {}, -- ids of the dragons that earn Embers and follow the player
	Nests = {}, -- eggs incubating: { { Nest = 1, Egg = "Common", HatchAt = time, Genes = bred genes? }, ... }
	UnlockedIslands = { "EmberIsle" },
	Rebirths = 0,
	Quests = {}, -- tutorial progress: { Step = 1, Progress = 0, SawIntro = true? } (see QuestService)
	StarterEgg = false, -- got the free first egg
	JoinCount = 0,
	FirstJoinTime = 0,
	LastJoinTime = 0,
	LastSeen = 0, -- last time income was paid; used for offline earnings
	Index = {}, -- genes discovered, as ["Wings.Bat"] = true (the Dragon Index)
	WorldFirsts = {}, -- names of dragons this player discovered first in the whole world
}
