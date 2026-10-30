--!strict
-- The Guild's quest board (Aldric). Each quest: what to do (Kind), how much, the reward, and the rank points
-- it earns toward the next Guild rank.
--   Kill: slay Count of Target (an enemy name; a boss counts too)
--   Collect: bring Count of Target (an item) to Aldric; they're taken when the quest is turned in
--   Reach: get down to floor Count
--   Lore: find Count of the pages of PageSet (shared/Lore; chapter I's if not set); reading one keeps it, nothing is taken
-- A player can carry MaxActive quests at once. Bounties (Repeatable) can be taken again and again.
-- Ranks go up with rank points: five ranks of ten tiers each (Copper I .. Mythril X), each tier costing more
-- than the last, so the top takes a long time (about 13,000 points in all).

local Config = require(script.Parent.Config)

export type Quest = {
	Id: string,
	Title: string,
	Text: string,
	Kind: "Kill" | "Collect" | "Reach" | "Lore",
	Target: string?,
	Count: number,
	Gold: number,
	XP: number,
	Points: number,
	Needs: string?, -- another quest that must be done first
	PageSet: string?, -- a Lore quest: which pages count
	Repeatable: boolean?, -- a bounty: can be taken again once turned in
	Giver: string?, -- who hands it out and takes it back (Aldric and the Guild board if not set)
	Thanks: string?, -- what the giver says when it's turned in
}

local Quests = {}

Quests.MaxActive = 5

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
	{ Id = "ATornPage", Title = "A Torn Page", Text = "Seraphine believes Ilvane's journal was scattered through the Depths. Find one page and bring her word of it.", Kind = "Lore", Count = 1, Gold = 120, XP = 150, Points = 20, Giver = "Seraphine", Thanks = "Seraphine reads it three times, lips moving. \"Her own hand. Oh, this is real. Find the rest. Please.\"" },
	{ Id = "IlvanesJournal", Title = "Ilvane's Journal", Text = "Recover all eight pages of Ilvane's journal from the Drowned Catacombs.", Kind = "Lore", Count = 8, Gold = 800, XP = 1000, Points = 120, Giver = "Seraphine", Needs = "ATornPage", Thanks = "Seraphine goes very quiet at the last page. \"Something green, beneath the gate... I need to read more. Much more.\"" },
	{ Id = "FoxHelmet", Title = "The Fox Helmet", Text = "Old Pip's son went down to the twelfth floor last spring and never came back. Find his helmet, the one with the fox.", Kind = "Collect", Target = "FoxHelmet", Count = 1, Gold = 350, XP = 600, Points = 60, Giver = "OldPip", Thanks = "Pip turns the helmet over in his hands for a long while. \"...Thank you. Your stew is on the house. For good.\"" },
} :: { Quest }

if Config.ChapterII then
	for _, quest in {
		{ Id = "PastTheSealedGate", Title = "Past the Sealed Gate", Text = "The gate has cracked. Go through and reach the twentieth floor. Tell me everything you see.", Kind = "Reach", Count = 20, Gold = 1800, XP = 1600, Points = 450, Needs = "BoneWarden", Thanks = "Aldric leans in. \"Twenty floors. Any camps down there? Any... names?\" He catches himself. \"Well done.\"" },
		{ Id = "RotgutToad", Title = "The Rotgut Toad", Text = "Something huge has been swallowing my scouts on the twentieth floor. Kill it.", Kind = "Kill", Target = "RotgutToad", Count = 1, Gold = 2500, XP = 2200, Points = 600, Needs = "PastTheSealedGate", Thanks = "\"Good. That's one less mouth down there.\" For a moment he doesn't look pleased at all." },
		{ Id = "MotherSpore", Title = "Mother Spore", Text = "The rot has a heart, on the thirtieth floor. Cut it out.", Kind = "Kill", Target = "MotherSpore", Count = 1, Gold = 5000, XP = 4500, Points = 1000, Needs = "RotgutToad", Thanks = "\"Dead? Truly?\" He looks at your hand, not your face. \"The Guild is in your debt.\"" },
		{ Id = "IlvanesPagesII", Title = "Ilvane's Pages II", Text = "There are more of Ilvane's pages below the gate. She wrote about the green fire. I need them.", Kind = "Lore", PageSet = "Ilvane2", Count = 4, Gold = 2000, XP = 2500, Points = 300, Giver = "Seraphine", Needs = "IlvanesJournal", Thanks = "Seraphine reads the last page twice. \"It isn't burning. It's growing. And it's heading for the Flame.\"" },
		{ Id = "NinthPatrol", Title = "The Ninth Patrol", Text = "My Wil's helmet was on twelve, but he wasn't. He went looking for the Ninth Patrol. Find their camp. Find his pack.", Kind = "Collect", Target = "WilsPack", Count = 1, Gold = 1500, XP = 2000, Points = 250, Giver = "OldPip", Needs = "FoxHelmet", Thanks = "Pip unfolds the letter. \"'Gone deeper, Da. Don't wait up.'\" He sits down very slowly. \"That's his hand. That's my boy's hand.\"" },
		{ Id = "OldDebts", Title = "Old Debts", Text = "The Ninth made camp somewhere past twenty. Find it, then tell me what the walls look like. Humour an old man.", Kind = "Reach", Count = 24, Gold = 1800, XP = 2000, Points = 250, Giver = "Thorne", Thanks = "Thorne is quiet for a long time. \"Same walls. I sat in that cave forty years ago. Don't ask me who with.\"" },
		{ Id = "CleanAir", Title = "Clean Air", Text = "I can make a cure from the thing that's killing us. Bring me Spore Caps. Burn your gloves after.", Kind = "Collect", Target = "SporeCap", Count = 20, Gold = 900, XP = 1200, Points = 120, Repeatable = true, Giver = "MiraFell", Thanks = "\"That's enough for a few days of breathing. Thank you. Don't tell Aldric where I keep it.\"" },
	} :: { Quest } do
		table.insert(Quests.List, quest)
	end
end

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
