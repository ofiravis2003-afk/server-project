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
	Description: string?,
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

	-- Materials: every monster leaves something of itself behind.
	Bone = { DisplayName = "Bone", Slot = "Material", Stack = 99, Price = 2, Description = "Dropped by skeletons." },
	Fletching = { DisplayName = "Black Fletching", Slot = "Material", Stack = 99, Price = 3, Description = "Arrow feathers from skeleton archers." },
	RatTail = { DisplayName = "Rat Tail", Slot = "Material", Stack = 99, Price = 1, Description = "Dropped by giant rats." },
	SlimeGel = { DisplayName = "Slime Gel", Slot = "Material", Stack = 99, Price = 2, Description = "What's left of a slime." },
	GraveShroud = { DisplayName = "Grave Shroud", Slot = "Material", Stack = 99, Price = 60, Description = "Torn from the Gravekeeper's coat. Rare." },

	-- Potions: drunk from the hotbar (slot 2).
	HealthPotion = { DisplayName = "Health Potion", Slot = "Potion", Stack = 5, Limit = 5, Price = 8, HealFraction = 0.4, Description = "Gives back 40% of your health." },
} :: { [string]: ItemDef }

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
