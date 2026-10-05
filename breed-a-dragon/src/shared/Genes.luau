--!strict
-- The dragon gene catalogue.
--
-- A dragon is just a table of gene ids, one per trait:
--   { Body = "Ember", Accent = "Gold", Wings = "Bat", Horns = "Curved", Tail = "Spiked", Size = "Normal",
--     Aura = "None", Pattern = "Stripes" }
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
	Pattern: string,
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

	-- Markings on the skin, drawn in the Accent colour (see DragonBuilder).
	Pattern = {
		{ Id = "Plain", Rarity = "Common" },
		{ Id = "Spots", Name = "Spotted", Rarity = "Common" },
		{ Id = "Stripes", Name = "Striped", Rarity = "Rare" },
		{ Id = "Scales", Name = "Scaled", Rarity = "Rare" },
		{ Id = "Veins", Name = "Molten", Rarity = "Epic" },
		{ Id = "Runes", Name = "Runic", Rarity = "Legendary" },
		{ Id = "Starmap", Name = "Starmarked", Rarity = "Mythic" },
	},
}

-- The order traits are rolled, shown and stored in.
local TRAITS = { "Body", "Accent", "Wings", "Horns", "Tail", "Size", "Aura", "Pattern" }
-- Traits added after launch, and the gene that older dragons get for them.
local NEW_TRAIT_DEFAULTS = { Pattern = "Plain" }

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

-- Fills in traits that were added after this dragon was saved (e.g. Pattern = "Plain"),
-- so old dragons stay valid and look the same. Changes `genes` in place; returns it.
function Genes.Upgrade(genes: any): any
	if type(genes) == "table" then
		for trait, default in NEW_TRAIT_DEFAULTS do
			if genes[trait] == nil then
				genes[trait] = default
			end
		end
	end
	return genes
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

-- e.g. "Huge Striped Frozen Violet Wyvern"
function Genes.GetName(genes: DragonGenes): string
	local words = {}
	for _, trait in { "Size", "Pattern", "Aura", "Body", "Wings" } do
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

-- A baby of two dragons: every trait comes from one parent or the other (50/50),
-- except that each trait has `mutationChance` to become a gene neither parent has
-- (rolled with `mutationWeights`). Returns the baby and the list of traits that mutated.
function Genes.Breed(
	a: DragonGenes,
	b: DragonGenes,
	rng: Random,
	mutationChance: number,
	mutationWeights: RarityWeights?
): (DragonGenes, { string })
	local baby = {}
	local mutated = {}
	for _, trait in TRAITS do
		local fromA, fromB = (a :: any)[trait], (b :: any)[trait]
		if rng:NextNumber() < mutationChance then
			-- Try a few times to land on something new; a mutation should feel new.
			local gene = Genes.RollTrait(trait, rng, mutationWeights)
			for _ = 1, 8 do
				if gene ~= fromA and gene ~= fromB then
					break
				end
				gene = Genes.RollTrait(trait, rng, mutationWeights)
			end
			baby[trait] = gene
			if gene ~= fromA and gene ~= fromB then
				table.insert(mutated, trait)
			end
		else
			baby[trait] = if rng:NextNumber() < 0.5 then fromA else fromB
		end
	end
	return baby :: any, mutated
end

-- Every gene id a dragon has, as "Trait.Id" (e.g. "Wings.Bat"). Used by the Dragon Index.
function Genes.GetIndexKeys(genes: DragonGenes): { string }
	local keys = {}
	for _, trait in TRAITS do
		table.insert(keys, trait .. "." .. (genes :: any)[trait])
	end
	return keys
end

type PointChances = { [number]: number }

-- For one trait rolled with `weights`: the chance of each number of rarity points
-- (including the fall-back to a lower tier when the trait has no gene in the rolled tier).
local function rolledPointChances(trait: string, weights: RarityWeights): PointChances
	local total = 0
	for _, tier in Rarity.Tiers do
		total += weights[tier.Name] or 0
	end
	local hasTier: { [number]: boolean } = {}
	for _, option in OPTIONS[trait] do
		hasTier[Rarity.Get(option.Rarity).Order] = true
	end

	local chances: PointChances = {}
	for _, tier in Rarity.Tiers do
		local chance = (weights[tier.Name] or 0) / total
		local landed = Rarity.Tiers[1]
		for order = tier.Order, 1, -1 do
			if hasTier[order] then
				landed = Rarity.Tiers[order]
				break
			end
		end
		chances[landed.Points] = (chances[landed.Points] or 0) + chance
	end
	return chances
end

-- Adds one trait's points to a running score distribution.
local function addPoints(scoreChances: PointChances, pointChances: PointChances): PointChances
	local combined: PointChances = {}
	for score, chance in scoreChances do
		for points, pointChance in pointChances do
			combined[score + points] = (combined[score + points] or 0) + chance * pointChance
		end
	end
	return combined
end

local function scoreToRarityOdds(scoreChances: PointChances): { [string]: number }
	local odds: { [string]: number } = {}
	for _, tier in Rarity.Tiers do
		odds[tier.Name] = 0
	end
	for score, chance in scoreChances do
		local tier = Rarity.FromScore(score)
		odds[tier.Name] += chance
	end
	return odds
end

-- The exact chance of each overall rarity for a dragon rolled with these weights,
-- e.g. { Common = 0.62, Rare = 0.27, ... }. Shown to players before they buy an egg.
function Genes.GetRarityOdds(weights: RarityWeights?): { [string]: number }
	local tierWeights = weights or defaultWeights()
	local scoreChances: PointChances = { [0] = 1 }
	for _, trait in TRAITS do
		scoreChances = addPoints(scoreChances, rolledPointChances(trait, tierWeights))
	end
	return scoreToRarityOdds(scoreChances)
end

-- The chance of rolling each gene of one trait with `weights` (see Genes.RollTrait).
local function geneChances(trait: string, weights: RarityWeights): { [string]: number }
	local byOrder: { [number]: { GeneOption } } = {}
	for _, option in OPTIONS[trait] do
		local order = Rarity.Get(option.Rarity).Order
		byOrder[order] = byOrder[order] or {}
		table.insert(byOrder[order], option)
	end
	local total = 0
	for _, tier in Rarity.Tiers do
		total += weights[tier.Name] or 0
	end

	local chances: { [string]: number } = {}
	for _, tier in Rarity.Tiers do
		local chance = (weights[tier.Name] or 0) / total
		for order = tier.Order, 1, -1 do
			local candidates = byOrder[order]
			if candidates then
				for _, option in candidates do
					chances[option.Id] = (chances[option.Id] or 0) + chance / #candidates
				end
				break
			end
		end
	end
	return chances
end

-- The exact chance of each overall rarity for a baby of `a` and `b` (see Genes.Breed),
-- mutations included. A mutation always lands on a gene neither parent has.
function Genes.GetBabyRarityOdds(
	a: DragonGenes,
	b: DragonGenes,
	mutationChance: number,
	mutationWeights: RarityWeights?
): { [string]: number }
	local scoreChances: PointChances = { [0] = 1 }
	for _, trait in TRAITS do
		local geneA, geneB = (a :: any)[trait], (b :: any)[trait]
		local function points(id: string): number
			return Rarity.Get(Genes.Get(trait, id).Rarity).Points
		end

		local chances: PointChances = {}
		local inherit = (1 - mutationChance) / 2
		chances[points(geneA)] = (chances[points(geneA)] or 0) + inherit
		chances[points(geneB)] = (chances[points(geneB)] or 0) + inherit

		-- Mutation: a roll, re-rolled while it matches a parent.
		local rolled = geneChances(trait, mutationWeights or defaultWeights())
		local allowed = 1 - (rolled[geneA] or 0) - (if geneB ~= geneA then rolled[geneB] or 0 else 0)
		for id, chance in rolled do
			if id ~= geneA and id ~= geneB and allowed > 0 then
				chances[points(id)] = (chances[points(id)] or 0) + mutationChance * chance / allowed
			end
		end
		scoreChances = addPoints(scoreChances, chances)
	end
	return scoreToRarityOdds(scoreChances)
end

return Genes
