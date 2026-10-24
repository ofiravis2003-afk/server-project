--!strict
-- Armor: four sets (Heavy, Medium, Light, Robes) of four pieces worn on the body (Head, Chest, Hands, Legs),
-- and rings (not seen on the body). Each set's totals are split over its pieces (the chest carries the most);
-- a piece's numbers grow with rarity (Rarity Power) and upgrades (+10% each), like weapons.
--   Defense: incoming damage is multiplied by 100 / (100 + Defense)
--   Health: added to max health
--   Speed: added to walk speed, as a fraction (0.1 = 10% faster; Heavy is a little slower)
--   SpellPower: staff and tome damage and healing, as a fraction
--   Set bonuses: wearing 2, then all 4 pieces of one set adds that set's Bonus (both steps add up).
-- Items.luau turns every piece here into an item. The 3D look of a piece is ReplicatedStorage.ArmorModels
-- [Look] (Tripo models); without one, ArmorService builds a plain stand-in.

local Rarity = require(script.Parent.Rarity)

export type Stats = { Defense: number, Health: number, Speed: number, SpellPower: number }
export type Piece = { Name: string, DisplayName: string, Set: string, Slot: string, Look: string?, Stats: Stats }
export type Bonus = { Defense: number?, Health: number?, Speed: number?, SpellPower: number? }
export type SetInfo = {
	Name: string,
	Title: string,
	Kind: string,
	Color: Color3,
	Totals: Stats,
	Pieces: { [string]: string },
	Bonus: { [number]: Bonus }, -- [pieces worn] = what that adds
}

local Armor = {}

-- Slots worn on the body, and each one's share of its set's totals.
Armor.BodySlots = { "Head", "Chest", "Hands", "Legs" }
local SHARE = { Head = 0.2, Chest = 0.4, Hands = 0.15, Legs = 0.25 }

Armor.Sets = {
	{
		Name = "Heavy",
		Title = "Valdren Knight",
		Kind = "Heavy plate",
		Color = Color3.fromRGB(120, 122, 128),
		Totals = { Defense = 40, Health = 40, Speed = -0.04, SpellPower = 0 },
		Pieces = { Head = "Valdren Knight Helm", Chest = "Valdren Knight Cuirass", Hands = "Valdren Knight Gauntlets", Legs = "Valdren Knight Greaves" },
		Bonus = { [2] = { Defense = 8 }, [4] = { Defense = 20, Health = 40 } }, -- stand your ground
	},
	{
		Name = "Medium",
		Title = "Catacomb Warden",
		Kind = "Scale and mail",
		Color = Color3.fromRGB(92, 96, 90),
		Totals = { Defense = 28, Health = 25, Speed = 0, SpellPower = 0 },
		Pieces = { Head = "Warden's Coif", Chest = "Warden's Hauberk", Hands = "Warden's Gloves", Legs = "Warden's Boots" },
		Bonus = { [2] = { Defense = 5, Health = 15 }, [4] = { Defense = 12, Health = 40, Speed = 0.05 } }, -- a bit of everything
	},
	{
		Name = "Light",
		Title = "Grave-Runner",
		Kind = "Leather",
		Color = Color3.fromRGB(86, 62, 44),
		Totals = { Defense = 16, Health = 10, Speed = 0.1, SpellPower = 0 },
		Pieces = { Head = "Grave-Runner Hood", Chest = "Grave-Runner Vest", Hands = "Grave-Runner Gloves", Legs = "Grave-Runner Boots" },
		Bonus = { [2] = { Speed = 0.05 }, [4] = { Speed = 0.1, Defense = 10 } }, -- never caught
	},
	{
		Name = "Robes",
		Title = "Ashwoven",
		Kind = "Robes",
		Color = Color3.fromRGB(96, 30, 38),
		Totals = { Defense = 10, Health = 10, Speed = 0, SpellPower = 0.2 },
		Pieces = { Head = "Ashwoven Cowl", Chest = "Ashwoven Robe", Hands = "Ashwoven Wraps", Legs = "Ashwoven Shoes" },
		Bonus = { [2] = { SpellPower = 0.08 }, [4] = { SpellPower = 0.2, Health = 25 } }, -- the fire answers
	},
} :: { SetInfo }

-- Rings: no look on the body, just numbers.
local RINGS = {
	{ Name = "SignetRing", DisplayName = "Old Signet Ring", Stats = { Defense = 4, Health = 20, Speed = 0, SpellPower = 0 } },
	{ Name = "EmberBand", DisplayName = "Ember Band", Stats = { Defense = 0, Health = 0, Speed = 0, SpellPower = 0.08 } },
}

Armor.Pieces = {} :: { [string]: Piece }
Armor.List = {} :: { Piece }
Armor.SetByName = {} :: { [string]: SetInfo }

local SLOT_KEY = { Head = "head", Chest = "chest", Hands = "hand", Legs = "boot" }
for _, set in Armor.Sets do
	Armor.SetByName[set.Name] = set
	for _, slot in Armor.BodySlots do
		local share = SHARE[slot]
		local piece: Piece = {
			Name = `{set.Name}{slot}`, -- e.g. HeavyHead
			DisplayName = set.Pieces[slot],
			Set = set.Name,
			Slot = slot,
			Look = `{string.lower(set.Name)}_{SLOT_KEY[slot]}`, -- e.g. heavy_head (ReplicatedStorage.ArmorModels)
			Stats = {
				Defense = set.Totals.Defense * share,
				Health = set.Totals.Health * share,
				Speed = set.Totals.Speed * share,
				SpellPower = set.Totals.SpellPower * share,
			},
		}
		Armor.Pieces[piece.Name] = piece
		table.insert(Armor.List, piece)
	end
end
for _, ring in RINGS do
	local piece: Piece = { Name = ring.Name, DisplayName = ring.DisplayName, Set = "Ring", Slot = "Ring", Look = nil, Stats = ring.Stats }
	Armor.Pieces[piece.Name] = piece
	table.insert(Armor.List, piece)
end

-- A piece's numbers at this rarity and upgrade.
function Armor.StatsOf(itemName: string, rarity: string, upgrade: number?): Stats
	local piece = Armor.Pieces[itemName]
	local zero = { Defense = 0, Health = 0, Speed = 0, SpellPower = 0 }
	if not piece then
		return zero
	end
	local power = (Rarity.Info[rarity] or Rarity.Info.Common).Power * (1 + 0.1 * (upgrade or 0))
	return {
		Defense = piece.Stats.Defense * power,
		Health = piece.Stats.Health * power,
		-- a slow set stays slow (the penalty doesn't grow), the bonuses do
		Speed = if piece.Stats.Speed < 0 then piece.Stats.Speed else piece.Stats.Speed * power,
		SpellPower = piece.Stats.SpellPower * power,
	}
end

-- How many pieces of each set are worn. `worn` is a list of { Item, ... }.
function Armor.SetCounts(worn: { { Item: string } }): { [string]: number }
	local counts = {}
	for _, item in worn do
		local piece = Armor.Pieces[item.Item]
		if piece and Armor.SetByName[piece.Set] then
			counts[piece.Set] = (counts[piece.Set] or 0) + 1
		end
	end
	return counts
end

-- Everything worn, added up (set bonuses too). `worn` is a list of { Item, Rarity, Upgrade }.
function Armor.Total(worn: { { Item: string, Rarity: string, Upgrade: number? } }): Stats
	local total = { Defense = 0, Health = 0, Speed = 0, SpellPower = 0 }
	for _, item in worn do
		local stats = Armor.StatsOf(item.Item, item.Rarity, item.Upgrade)
		total.Defense += stats.Defense
		total.Health += stats.Health
		total.Speed += stats.Speed
		total.SpellPower += stats.SpellPower
	end
	for setName, count in Armor.SetCounts(worn) do
		for need, bonus in Armor.SetByName[setName].Bonus do
			if count >= need then
				total.Defense += bonus.Defense or 0
				total.Health += bonus.Health or 0
				total.Speed += bonus.Speed or 0
				total.SpellPower += bonus.SpellPower or 0
			end
		end
	end
	total.Speed = math.clamp(total.Speed, -0.1, 0.3)
	return total
end

-- What `damage` becomes against this much Defense.
function Armor.Reduce(damage: number, defense: number): number
	return damage * 100 / (100 + math.max(defense, 0))
end

-- Short text of a piece's numbers, for the bag ("Defense 8 · Health +8 · Speed +2%").
function Armor.Describe(stats: Stats): string
	local parts = { `Defense {math.floor(stats.Defense + 0.5)}` }
	if stats.Health ~= 0 then
		table.insert(parts, `Health +{math.floor(stats.Health + 0.5)}`)
	end
	if stats.Speed ~= 0 then
		table.insert(parts, `Speed {if stats.Speed > 0 then "+" else ""}{math.floor(stats.Speed * 100 + 0.5)}%`)
	end
	if stats.SpellPower ~= 0 then
		table.insert(parts, `Spell power +{math.floor(stats.SpellPower * 100 + 0.5)}%`)
	end
	return table.concat(parts, "  ·  ")
end

-- A set bonus in words ("Defense +20 · Health +40").
function Armor.DescribeBonus(bonus: Bonus): string
	local parts = {}
	if bonus.Defense then
		table.insert(parts, `Defense +{bonus.Defense}`)
	end
	if bonus.Health then
		table.insert(parts, `Health +{bonus.Health}`)
	end
	if bonus.Speed then
		table.insert(parts, `Speed +{math.floor(bonus.Speed * 100 + 0.5)}%`)
	end
	if bonus.SpellPower then
		table.insert(parts, `Spell power +{math.floor(bonus.SpellPower * 100 + 0.5)}%`)
	end
	return table.concat(parts, " · ")
end

return Armor
