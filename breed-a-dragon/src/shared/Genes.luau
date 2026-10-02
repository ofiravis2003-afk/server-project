--!strict
-- The dragon gene catalogue.
--
-- A dragon is just a table of gene ids, one per trait:
--   { Body = "Ember", Accent = "Gold", Wings = "Bat", Horns = "Curved", Tail = "Spiked", Size = "Normal", Aura = "None" }
-- Everything else (its name, its rarity, how it looks) is worked out from those ids.
-- To add a new gene, add a line to the right list below. Ids must never change once players own them.

local Rarity = require(script.Parent.Rarity)

export type GeneOption = {
	Id: string,
	Rarity: string,
	-- Optional fields, used depending on the trait:
	Name: string?, -- word used in the dragon's name
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Reflectance: number?,
	Scale: number?, -- Size trait only
}

export type DragonGenes = {
	Body: string,
	Accent: string,
	Wings: string,
	Horns: string,
	Tail: string,
	Size: string,
	Aura: string,
}

-- Body and Accent share one colour palette.
local COLORS: { GeneOption } = {
	{ Id = "Ember", Name = "Ember", Rarity = "Common", Color = Color3.fromRGB(205, 70, 50) },
	{ Id = "Moss", Name = "Moss", Rarity = "Common", Color = Color3.fromRGB(95, 150, 70) },
	{ Id = "Sky", Name = "Sky", Rarity = "Common", Color = Color3.fromRGB(90, 160, 220) },
	{ Id = "Sandstone", Name = "Sandstone", Rarity = "Common", Color = Color3.fromRGB(215, 180, 120) },
	{ Id = "Slate", Name = "Slate", Rarity = "Common", Color = Color3.fromRGB(110, 115, 130) },
	{ Id = "Violet", Name = "Violet", Rarity = "Rare", Color = Color3.fromRGB(140, 80, 200) },
	{ Id = "Frost", Name = "Frost", Rarity = "Rare", Color = Color3.fromRGB(225, 240, 255) },
	{ Id = "Coral", Name = "Coral", Rarity = "Rare", Color = Color3.fromRGB(255, 120, 130) },
	{ Id = "Obsidian", Name = "Obsidian", Rarity = "Epic", Color = Color3.fromRGB(30, 28, 38), Reflectance = 0.15 },
	{ Id = "Emerald", Name = "Emerald", Rarity = "Epic", Color = Color3.fromRGB(20, 200, 120), Reflectance = 0.1 },
	{ Id = "Midnight", Name = "Midnight", Rarity = "Epic", Color = Color3.fromRGB(25, 40, 110) },
	{ Id = "Gold", Name = "Golden", Rarity = "Legendary", Color = Color3.fromRGB(255, 200, 60), Reflectance = 0.3 },
	{
		Id = "RoseGold",
		Name = "Rose Gold",
		Rarity = "Legendary",
		Color = Color3.fromRGB(240, 160, 150),
		Reflectance = 0.3,
	},
	{
		Id = "Aurora",
		Name = "Aurora",
		Rarity = "Mythic",
		Color = Color3.fromRGB(80, 230, 210),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	},
	{
		Id = "Void",
		Name = "Void",
		Rarity = "Mythic",
		Color = Color3.fromRGB(45, 0, 70),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	},
}

local OPTIONS: { [string]: { GeneOption } } = {
	Body = COLORS,
	Accent = COLORS,

	-- Name = the dragon's "species" word.
	Wings = {
		{ Id = "Bat", Name = "Drake", Rarity = "Common" },
		{ Id = "Feathered", Name = "Wyvern", Rarity = "Rare" },
		{ Id = "Crystal", Name = "Wyrm", Rarity = "Epic" },
		{ Id = "Flame", Name = "Phoenix", Rarity = "Legendary" },
		{ Id = "Starlight", Name = "Celestial", Rarity = "Mythic" },
	},

	Horns = {
		{ Id = "Nubs", Rarity = "Common" },
		{ Id = "Short", Rarity = "Common" },
		{ Id = "Curved", Rarity = "Rare" },
		{ Id = "Crown", Rarity = "Epic" },
		{ Id = "Crystal", Rarity = "Legendary" },
		{ Id = "Halo", Rarity = "Mythic" },
	},

	Tail = {
		{ Id = "Spiked", Rarity = "Common" },
		{ Id = "Club", Rarity = "Rare" },
		{ Id = "Flame", Rarity = "Epic" },
		{ Id = "Twin", Rarity = "Legendary" },
		{ Id = "Comet", Rarity = "Mythic" },
	},

	-- Name = optional word in front of the dragon's name.
	Size = {
		{ Id = "Small", Rarity = "Common", Scale = 0.85 },
		{ Id = "Normal", Rarity = "Common", Scale = 1 },
		{ Id = "Large", Name = "Large", Rarity = "Rare", Scale = 1.2 },
		{ Id = "Tiny", Name = "Tiny", Rarity = "Epic", Scale = 0.6 },
		{ Id = "Huge", Name = "Huge", Rarity = "Epic", Scale = 1.45 },
		{ Id = "Titan", Name = "Titan", Rarity = "Legendary", Scale = 1.75 },
		{ Id = "Colossal", Name = "Colossal", Rarity = "Mythic", Scale = 2.1 },
	},

	-- Name = optional word in front of the dragon's name.
	Aura = {
		{ Id = "None", Rarity = "Common" },
		{ Id = "Ember", Name = "Blazing", Rarity = "Rare" },
		{ Id = "Frost", Name = "Frozen", Rarity = "Rare" },
		{ Id = "Storm", Name = "Storm", Rarity = "Epic" },
		{ Id = "Starfall", Name = "Starfall", Rarity = "Legendary" },
		{ Id = "Cosmic", Name = "Cosmic", Rarity = "Mythic" },
	},
}

-- The order traits are rolled, shown and stored in.
local TRAITS = { "Body", "Accent", "Wings", "Horns", "Tail", "Size", "Aura" }

local lookup: { [string]: { [string]: GeneOption } } = {}
for trait, options in OPTIONS do
	lookup[trait] = {}
	for _, option in options do
		lookup[trait][option.Id] = option
	end
end

local Genes = {}

Genes.Traits = TRAITS
Genes.Options = OPTIONS

-- Weights per rarity tier; pass your own (e.g. from an egg) to change the odds.
export type RarityWeights = { [string]: number }

local function defaultWeights(): RarityWeights
	local weights = {}
	for _, tier in Rarity.Tiers do
		weights[tier.Name] = tier.Weight
	end
	return weights
end

function Genes.Get(trait: string, id: string): GeneOption
	local option = lookup[trait] and lookup[trait][id]
	assert(option, `Unknown gene {trait}.{id}`)
	return option
end

function Genes.IsValid(genes: any): boolean
	if type(genes) ~= "table" then
		return false
	end
	for _, trait in TRAITS do
		local id = genes[trait]
		if type(id) ~= "string" or lookup[trait][id] == nil then
			return false
		end
	end
	return true
end

local function rollTier(rng: Random, weights: RarityWeights): string
	local total = 0
	for _, tier in Rarity.Tiers do
		total += weights[tier.Name] or 0
	end
	local pick = rng:NextNumber() * total
	for _, tier in Rarity.Tiers do
		pick -= weights[tier.Name] or 0
		if pick < 0 then
			return tier.Name
		end
	end
	return Rarity.Tiers[1].Name
end

-- Picks a random gene for one trait. If the trait has nothing in the rolled tier,
-- it falls back to the next lower tier that does.
function Genes.RollTrait(trait: string, rng: Random, weights: RarityWeights?): string
	local options = OPTIONS[trait]
	local tierOrder = Rarity.Get(rollTier(rng, weights or defaultWeights())).Order

	for order = tierOrder, 1, -1 do
		local candidates = {}
		for _, option in options do
			if Rarity.Get(option.Rarity).Order == order then
				table.insert(candidates, option)
			end
		end
		if #candidates > 0 then
			return candidates[rng:NextInteger(1, #candidates)].Id
		end
	end
	return options[1].Id
end

-- A completely random dragon.
function Genes.Roll(rng: Random, weights: RarityWeights?): DragonGenes
	local genes = {}
	for _, trait in TRAITS do
		genes[trait] = Genes.RollTrait(trait, rng, weights)
	end
	return genes :: any
end

function Genes.GetScore(genes: DragonGenes): number
	local score = 0
	for _, trait in TRAITS do
		score += Rarity.Get(Genes.Get(trait, (genes :: any)[trait]).Rarity).Points
	end
	return score
end

function Genes.GetRarity(genes: DragonGenes): Rarity.Tier
	return Rarity.FromScore(Genes.GetScore(genes))
end

-- e.g. "Huge Frozen Violet Wyvern"
function Genes.GetName(genes: DragonGenes): string
	local words = {}
	for _, trait in { "Size", "Aura", "Body", "Wings" } do
		local word = Genes.Get(trait, (genes :: any)[trait]).Name
		if word then
			table.insert(words, word)
		end
	end
	return table.concat(words, " ")
end

-- A stable string that identifies this exact combination (used by the Dragon Index later).
function Genes.GetKey(genes: DragonGenes): string
	local parts = {}
	for _, trait in TRAITS do
		table.insert(parts, (genes :: any)[trait])
	end
	return table.concat(parts, "-")
end

return Genes
