--!strict
-- The Guild's quest board (Aldric). Each quest: what to do (Kind), how much, the reward, and the rank points
-- it earns toward the next Guild rank.
--   Kill: slay Count of Target (an enemy name; a boss counts too)
--   Collect: bring Count of Target (an item) to Aldric; they're taken when the quest is turned in
--   Reach: get down to floor Count
-- A player can carry MaxActive quests at once. Bounties (Repeatable) can be taken again and again.
-- Ranks go up with rank points: five ranks of ten tiers each (Copper I .. Mythril X), each tier costing more
-- than the last, so the top takes a long time (about 13,000 points in all).

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
	Repeatable: boolean?, -- a bounty: can be taken again once turned in
	Giver: string?, -- who hands it out and takes it back (Aldric and the Guild board if not set)
	Thanks: string?, -- what the giver says when it's turned in
}

local Quests = {}

Quests.MaxActive = 3

Quests.List = {
	{ Id = "RatProblem", Title = "Rat Problem", Text = "Giant rats are chewing through the Guild's supplies. Thin them out.", Kind = "Kill", Target = "Rat", Count = 12, Gold = 100, XP = 60, Points = 20, Repeatable = true },
	{ Id = "BonesForTheForge", Title = "Bones for the Forge", Text = "Brakka grinds old bone into her quench. Bring her some.", Kind = "Collect", Target = "Bone", Count = 15, Gold = 120, XP = 80, Points = 25, Repeatable = true },
	{ Id = "RestlessDead", Title = "The Restless Dead", Text = "Put the skeletons of the upper catacombs back to rest.", Kind = "Kill", Target = "Skeleton", Count = 20, Gold = 150, XP = 120, Points = 30, Repeatable = true },
	{ Id = "ArrowsInTheDark", Title = "Arrows in the Dark", Text = "Skeleton archers keep picking off our scouts. Silence them.", Kind = "Kill", Target = "SkeletonArcher", Count = 10, Gold = 160, XP = 130, Points = 35, Repeatable = true, Needs = "RestlessDead" },
	{ Id = "IntoTheDepths", Title = "Into the Depths", Text = "Prove yourself: reach the fifth floor.", Kind = "Reach", Count = 5, Gold = 200, XP = 150, Points = 80 },
	{ Id = "Gravekeeper", Title = "The Gravekeeper", Text = "Something digs graves on the fifth floor. End it.", Kind = "Kill", Target = "Gravekeeper", Count = 1, Gold = 500, XP = 400, Points = 150, Needs = "IntoTheDepths" },
	{ Id = "SlimeSamples", Title = "Slime Samples", Text = "Seraphine wants slime for her experiments. Don't ask.", Kind = "Collect", Target = "SlimeGel", Count = 10, Gold = 180, XP = 140, Points = 40, Repeatable = true, Needs = "Gravekeeper" },
	{ Id = "PastTheGuardians", Title = "Past the Guardians", Text = "Break through the Guardians' hall and reach the eleventh floor.", Kind = "Reach", Count = 11, Gold = 600, XP = 500, Points = 200, Needs = "Gravekeeper" },
	{ Id = "BoneWarden", Title = "The Last Knight", Text = "The Bone Warden guards the sealed gate on the fifteenth floor. End his watch.", Kind = "Kill", Target = "BoneWarden", Count = 1, Gold = 1500, XP = 1200, Points = 400, Needs = "PastTheGuardians" },
	-- Side quests, from the townsfolk.
	{ Id = "FoxHelmet", Title = "The Fox Helmet", Text = "Old Pip's son went down to the twelfth floor last spring and never came back. Find his helmet, the one with the fox.", Kind = "Collect", Target = "FoxHelmet", Count = 1, Gold = 350, XP = 600, Points = 60, Giver = "OldPip", Thanks = "Pip turns the helmet over in his hands for a long while. \"...Thank you. Your drinks are on the house. For good.\"" },
} :: { Quest }

Quests.ById = {} :: { [string]: Quest }
for _, q in Quests.List do
	Quests.ById[q.Id] = q
end

-- Guild ranks, lowest first, each split into Tiers tiers.
Quests.Ranks = {
	{ Name = "Copper", Color = Color3.fromRGB(196, 128, 72) },
	{ Name = "Iron", Color = Color3.fromRGB(160, 160, 165) },
	{ Name = "Silver", Color = Color3.fromRGB(215, 220, 230) },
	{ Name = "Gold", Color = Color3.fromRGB(240, 195, 80) },
	{ Name = "Mythril", Color = Color3.fromRGB(120, 220, 230) },
}
Quests.Tiers = 10

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

-- Points needed to go from overall step `step` (0 = Copper I) to the next one.
function Quests.StepCost(step: number): number
	return 20 + 10 * step
end

export type Standing = { Rank: string, Tier: number, Label: string, Color: Color3, Into: number, Need: number, Top: boolean }

-- Where `points` puts a player: rank, tier (1-10), "Iron III", and how far into the next tier.
function Quests.Standing(points: number): Standing
	local step, left = 0, points
	local last = #Quests.Ranks * Quests.Tiers - 1
	while step < last and left >= Quests.StepCost(step) do
		left -= Quests.StepCost(step)
		step += 1
	end
	local rank = Quests.Ranks[step // Quests.Tiers + 1]
	local tier = step % Quests.Tiers + 1
	return {
		Rank = rank.Name,
		Tier = tier,
		Label = `{rank.Name} {ROMAN[tier]}`,
		Color = rank.Color,
		Into = left,
		Need = Quests.StepCost(step),
		Top = step >= last,
	}
end

-- Who hands out a quest.
function Quests.GiverOf(quest: Quest): string
	return quest.Giver or "Aldric"
end

function Quests.ColorOf(rankName: string): Color3
	for _, r in Quests.Ranks do
		if r.Name == rankName then
			return r.Color
		end
	end
	return Quests.Ranks[1].Color
end

return Quests
