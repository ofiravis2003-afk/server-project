--!strict
-- Titles: names earned by what a player has done, worn over their head instead of "Adventurer". The server
-- checks them against the save (TitleService); the Titles window shows them all, earned or not, with how to
-- earn each.
--
--   Earned(data) says whether a save has it. Kills come from data.Kills ([enemy name] = count).

local Floors = require(script.Parent.Floors)

export type Title = { Id: string, Name: string, Hint: string, Color: Color3, Earned: (data: any) -> boolean }

local function kills(data: any, names: { string }): number
	local total = 0
	for _, name in names do
		total += (data.Kills or {})[name] or 0
	end
	return total
end

local COMMON = Color3.fromRGB(226, 214, 196)
local GOOD = Color3.fromRGB(140, 210, 255)
local GREAT = Color3.fromRGB(200, 150, 255)
local LEGEND = Color3.fromRGB(255, 196, 90)

local Titles: { Title } = {
	{ Id = "Adventurer", Name = "Adventurer", Hint = "Every adventurer starts here.", Color = COMMON, Earned = function()
		return true
	end },
	{ Id = "Delver", Name = "Delver", Hint = "Reach floor 5 of the Depths.", Color = COMMON, Earned = function(d)
		return (d.DeepestFloor or 0) >= 5
	end },
	{ Id = "Ratcatcher", Name = "Ratcatcher", Hint = "Slay 100 rats.", Color = COMMON, Earned = function(d)
		return kills(d, { "Rat", "SporeRat" }) >= 100
	end },
	{ Id = "Unbroken", Name = "Unbroken", Hint = "Claim the daily gift 7 days in a row.", Color = GOOD, Earned = function(d)
		return (d.DailyStreak or 0) >= 7
	end },
	{ Id = "GravekeepersBane", Name = "Gravekeeper's Bane", Hint = "Defeat the Gravekeeper (floor 5).", Color = GOOD, Earned = function(d)
		return (d.Checkpoint or 0) >= 6
	end },
	{ Id = "DeepDiver", Name = "Deep Diver", Hint = "Reach floor 10 of the Depths.", Color = GOOD, Earned = function(d)
		return (d.DeepestFloor or 0) >= 10
	end },
	{ Id = "DummyDestroyer", Name = "Dummy Destroyer", Hint = "Deal 250 damage per second in the Training Yard.", Color = GOOD, Earned = function(d)
		return (d.BestDps or 0) >= 250
	end },
	{ Id = "Fellowship", Name = "Fellowship", Hint = "Go down the Well with a full party of four.", Color = GOOD, Earned = function(d)
		return d.FullParty == true
	end },
	{ Id = "Bonebreaker", Name = "Bonebreaker", Hint = "Put 300 skeletons to rest.", Color = GREAT, Earned = function(d)
		return kills(d, { "Skeleton", "SkeletonArcher" }) >= 300
	end },
	{ Id = "Veteran", Name = "Veteran", Hint = "Reach level 20.", Color = GREAT, Earned = function(d)
		return (d.Level or 1) >= 20
	end },
	{ Id = "KnightsEnd", Name = "The Knight's End", Hint = "Defeat the Bone Warden (floor 15).", Color = GREAT, Earned = function(d)
		return (d.Checkpoint or 0) >= 16
	end },
	{ Id = "Slayer", Name = "Slayer", Hint = "Slay 1,000 monsters.", Color = GREAT, Earned = function(d)
		local total = 0
		for _, n in d.Kills or {} do
			total += n
		end
		return total >= 1000
	end },
	{ Id = "HollowWalker", Name = "Hollow Walker", Hint = "Go deeper than the last chapter, into The Hollow.", Color = LEGEND, Earned = function(d)
		return (d.DeepestFloor or 0) >= Floors.HollowFirst
	end },
	{ Id = "Founder", Name = "Founder", Hint = "One of the first 250 adventurers of Emberwell.", Color = LEGEND, Earned = function(d)
		return d.FounderNumber ~= nil
	end },
}

local byId: { [string]: Title } = {}
for _, t in Titles do
	byId[t.Id] = t
end

local Module = {}
Module.List = Titles

function Module.Get(id: string?): Title?
	return if id then byId[id] else nil
end

return Module
