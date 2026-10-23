--!strict
-- Every item in the game. A player's saved item only stores its name, rarity and upgrade level;
-- everything else comes from here.

local Rarity = require(script.Parent.Rarity)

export type ItemDef = {
	DisplayName: string,
	-- Weapons and armor are worn in a slot; materials (dropped by monsters, for selling, quests and upgrades)
	-- and potions (drunk from the hotbar) just sit in the bag, stacked.
	Slot: "Weapon" | "Head" | "Chest" | "Hands" | "Legs" | "Ring" | "Material" | "Potion",
	Stack: number?, -- stackable: up to this many in one bag place
	Limit: number?, -- the most a player can carry in all (potions)
	Price: number?, -- what a merchant pays for one (materials and potions; gear goes by rarity)
	HealFraction: number?, -- potions: part of max health given back
	Buff: { Stat: string, Amount: number, Duration: number }?, -- potions: a while stronger (Defense, Speed, SpellPower)
	Color: Color3?, -- potions: the liquid's colour in pictures
	Description: string?,
	Keepsake: boolean?, -- a quest item: can't be sold or dropped
	Set: string?, -- armor: Heavy, Medium, Light, Robes or Ring (shared/Armor has its numbers)
	WeaponType: string?,
	Damage: number?,
	Heal: number?, -- tome only: health given back per cast
	Look: string?, -- which shape WeaponBuilder makes
	Names: { [string]: string }?, -- the item's name at each rarity (its look changes with rarity too)
}

local Items = {}

Items.Defs = {
	RustySword = {
		DisplayName = "Rusty Sword",
		Slot = "Weapon",
		WeaponType = "Sword",
		Damage = 15, -- slower swings since 2026-10-13 (0.6s): same damage per second
		Look = "Sword",
		Names = { Rare = "Steel Longsword", Epic = "Duskblade", Legendary = "Sunforged Blade", Mythic = "Emberfall" },
	},
	WoodcutterAxe = {
		DisplayName = "Woodcutter's Axe",
		Slot = "Weapon",
		WeaponType = "Axe",
		Damage = 22, -- faster chops since 2026-10-13 (0.9s): same damage per second
		Look = "Axe",
		Names = { Rare = "Iron Waraxe", Epic = "Gravecleaver", Legendary = "Twinfang Axe", Mythic = "Ashen Executioner" },
	},
	ApprenticeStaff = {
		DisplayName = "Apprentice Staff",
		Slot = "Weapon",
		WeaponType = "Staff",
		Damage = 15,
		Look = "Staff",
		Names = { Rare = "Ember Staff", Epic = "Witchfire Staff", Legendary = "Archmage's Staff", Mythic = "Staff of the Last Flame" },
	},
	AcolyteTome = {
		DisplayName = "Acolyte's Tome",
		Slot = "Weapon",
		WeaponType = "Tome",
		Damage = 7,
		Heal = 13,
		Look = "Tome",
		Names = { Rare = "Book of Mending", Epic = "Lantern Codex", Legendary = "Radiant Codex", Mythic = "Tome of the Dawn" },
	},

	-- The first FOUNDERS adventurers of Emberwell (FounderService): a burning blade of their own, kept forever.
	FoundersBlade = {
		DisplayName = "Founder's Emberblade",
		Slot = "Weapon",
		WeaponType = "Sword",
		Damage = 15, -- (given Epic: a strong start, and it can be upgraded like any sword)
		Look = "FoundersBlade",
		Keepsake = true,
		Description = "Forged for the first 250 adventurers to go down the Great Well. It never stops burning.",
	},

	-- Materials: every monster leaves something of itself behind.
	Bone = { DisplayName = "Bone", Slot = "Material", Stack = 99, Price = 2, Description = "Dropped by skeletons." },
	Fletching = { DisplayName = "Black Fletching", Slot = "Material", Stack = 99, Price = 3, Description = "Arrow feathers from skeleton archers." },
	RatTail = { DisplayName = "Rat Tail", Slot = "Material", Stack = 99, Price = 1, Description = "Dropped by giant rats." },
	SlimeGel = { DisplayName = "Slime Gel", Slot = "Material", Stack = 99, Price = 2, Description = "What's left of a slime." },
	GraveShroud = { DisplayName = "Grave Shroud", Slot = "Material", Stack = 99, Price = 60, Description = "Torn from the Gravekeeper's coat. Rare." },

	-- Keepsakes: quest items, carried until they're handed over.
	FoxHelmet = { DisplayName = "Dented Fox Helmet", Slot = "Material", Stack = 1, Limit = 1, Keepsake = true, Description = "A dented helmet with a fox painted on it. Old Pip's boy wore it." },

	-- Potions: drunk from the hotbar (slot 2).
	HealthPotion = { DisplayName = "Health Potion", Slot = "Potion", Stack = 5, Limit = 5, Price = 8, HealFraction = 0.4, Description = "Gives back 40% of your health." },
	-- Seraphine's brews (the Gilded Tome)
	GreaterHealthPotion = { DisplayName = "Greater Health Potion", Slot = "Potion", Stack = 3, Limit = 3, Price = 25, HealFraction = 0.75, Color = Color3.fromRGB(230, 40, 120), Description = "Gives back 75% of your health." },
	IronskinTonic = { DisplayName = "Ironskin Tonic", Slot = "Potion", Stack = 3, Limit = 3, Price = 20, Buff = { Stat = "Defense", Amount = 40, Duration = 60 }, Color = Color3.fromRGB(150, 160, 175), Description = "Defense +40 for a minute." },
	SwiftnessDraught = { DisplayName = "Swiftness Draught", Slot = "Potion", Stack = 3, Limit = 3, Price = 20, Buff = { Stat = "Speed", Amount = 0.25, Duration = 45 }, Color = Color3.fromRGB(70, 200, 220), Description = "25% faster for 45 seconds." },
	EmberElixir = { DisplayName = "Ember Elixir", Slot = "Potion", Stack = 3, Limit = 3, Price = 25, Buff = { Stat = "SpellPower", Amount = 0.3, Duration = 60 }, Color = Color3.fromRGB(255, 130, 40), Description = "Staff and tome spells 30% stronger for a minute." },
} :: { [string]: ItemDef }

-- Armor pieces and rings (shared/Armor): worn in their slot, one per bag place.
local Armor = require(script.Parent.Armor)
for _, piece in Armor.List do
	Items.Defs[piece.Name] = { DisplayName = piece.DisplayName, Slot = piece.Slot :: any, Set = piece.Set }
end
Items.ArmorPieces = {} :: { string }
for _, piece in Armor.List do
	table.insert(Items.ArmorPieces, piece.Name)
end

-- One starter weapon of each type, in hotbar order.
Items.StarterWeapons = { "RustySword", "WoodcutterAxe", "ApprenticeStaff", "AcolyteTome" }

-- The item's name at this rarity ("Rusty Sword" at Common, "Sunforged Blade" at Legendary).
function Items.NameFor(itemName: string, rarity: string): string
	local def = Items.Defs[itemName]
	if not def then
		return itemName
	end
	return def.Names and def.Names[rarity] or def.DisplayName
end

-- Each upgrade level (+1 .. +10) adds 10% to the base stats.
local function scaled(base: number, rarity: string, upgrade: number): number
	local info = Rarity.Info[rarity] or Rarity.Info.Common
	return base * info.Power * (1 + 0.1 * upgrade)
end

function Items.WeaponDamage(itemName: string, rarity: string, upgrade: number): number
	local def = Items.Defs[itemName]
	return scaled(def and def.Damage or 0, rarity, upgrade)
end

-- What a merchant pays for an item (a whole stack of `count`).
local SELL_PRICE = { Common = 10, Rare = 30, Epic = 90, Legendary = 250, Mythic = 600 }
function Items.SellPrice(itemName: string, rarity: string, upgrade: number, count: number?): number
	local def = Items.Defs[itemName]
	if def and def.Price then
		return def.Price * (count or 1)
	end
	return math.floor((SELL_PRICE[rarity] or 10) * (1 + 0.1 * upgrade))
end

-- Gear is worn (one per bag place); materials and potions stack.
function Items.IsGear(itemName: string): boolean
	local def = Items.Defs[itemName]
	return def ~= nil and def.Slot ~= "Material" and def.Slot ~= "Potion"
end

function Items.WeaponHeal(itemName: string, rarity: string, upgrade: number): number
	local def = Items.Defs[itemName]
	return scaled(def and def.Heal or 0, rarity, upgrade)
end

return Items
