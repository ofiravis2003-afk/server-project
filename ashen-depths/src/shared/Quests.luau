--!strict
-- The Guild's quest board (Aldric). Each quest: what to do (Kind), how much, the reward, and the rank points
-- it earns toward the next Guild rank.
--   Kill: slay Count of Target (an enemy name; a boss counts too)
--   Collect: bring Count of Target (an item) to Aldric; they're taken when the quest is turned in
--   Reach: get down to floor Count
-- A player can carry MaxActive quests at once. Ranks go up with rank points (Ranks below).

export type Quest = {
	Id: string,
	Title: string,
	Text: string,
	Kind: "Kill" | "Collect" | "Reach",
	Target: string?,
	Count: number,
	Gold: number,
	XP: number,
	Points: number,
	Needs: string?, -- another quest that must be done first
}

local Quests = {}

Quests.MaxActive = 3

Quests.List = {
	{ Id = "RatProblem", Title = "Rat Problem", Text = "Giant rats are chewing through the Guild's supplies. Thin them out.", Kind = "Kill", Target = "Rat", Count = 12, Gold = 100, XP = 60, Points = 1 },
	{ Id = "BonesForTheForge", Title = "Bones for the Forge", Text = "Brakka grinds old bone into her quench. Bring her some.", Kind = "Collect", Target = "Bone", Count = 15, Gold = 120, XP = 80, Points = 1 },
	{ Id = "RestlessDead", Title = "The Restless Dead", Text = "Put the skeletons of the upper catacombs back to rest.", Kind = "Kill", Target = "Skeleton", Count = 20, Gold = 150, XP = 120, Points = 1 },
	{ Id = "ArrowsInTheDark", Title = "Arrows in the Dark", Text = "Skeleton archers keep picking off our scouts. Silence them.", Kind = "Kill", Target = "SkeletonArcher", Count = 10, Gold = 160, XP = 130, Points = 1, Needs = "RestlessDead" },
	{ Id = "IntoTheDepths", Title = "Into the Depths", Text = "Prove yourself: reach the fifth floor.", Kind = "Reach", Count = 5, Gold = 200, XP = 150, Points = 2 },
	{ Id = "Gravekeeper", Title = "The Gravekeeper", Text = "Something digs graves on the fifth floor. End it.", Kind = "Kill", Target = "Gravekeeper", Count = 1, Gold = 500, XP = 400, Points = 3, Needs = "IntoTheDepths" },
	{ Id = "SlimeSamples", Title = "Slime Samples", Text = "Seraphine wants slime for her experiments. Don't ask.", Kind = "Collect", Target = "SlimeGel", Count = 10, Gold = 180, XP = 140, Points = 1, Needs = "Gravekeeper" },
	{ Id = "PastTheGuardians", Title = "Past the Guardians", Text = "Break through the Guardians' hall and reach the eleventh floor.", Kind = "Reach", Count = 11, Gold = 600, XP = 500, Points = 3, Needs = "Gravekeeper" },
} :: { Quest }

Quests.ById = {} :: { [string]: Quest }
for _, q in Quests.List do
	Quests.ById[q.Id] = q
end

-- Guild ranks, lowest first, and the rank points each needs.
Quests.Ranks = {
	{ Name = "Copper", Points = 0, Color = Color3.fromRGB(196, 128, 72) },
	{ Name = "Iron", Points = 3, Color = Color3.fromRGB(160, 160, 165) },
	{ Name = "Silver", Points = 7, Color = Color3.fromRGB(215, 220, 230) },
	{ Name = "Gold", Points = 11, Color = Color3.fromRGB(240, 195, 80) },
	{ Name = "Mythril", Points = 16, Color = Color3.fromRGB(120, 220, 230) },
}

function Quests.RankFor(points: number): string
	local name = Quests.Ranks[1].Name
	for _, rank in Quests.Ranks do
		if points >= rank.Points then
			name = rank.Name
		end
	end
	return name
end

return Quests
