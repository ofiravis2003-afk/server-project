--!strict
-- Every item in the game. A player's saved item only stores its name, rarity and upgrade level;
-- everything else comes from here.

local Rarity = require(script.Parent.Rarity)

export type ItemDef = {
	DisplayName: string,
	Slot: "Weapon" | "Head" | "Chest" | "Hands" | "Legs" | "Ring",
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
		Damage = 12,
		Look = "Sword",
		Names = { Rare = "Steel Longsword", Epic = "Duskblade", Legendary = "Sunforged Blade", Mythic = "Emberfall" },
	},
	WoodcutterAxe = {
		DisplayName = "Woodcutter's Axe",
		Slot = "Weapon",
		WeaponType = "Axe",
		Damage = 26,
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

function Items.WeaponHeal(itemName: string, rarity: string, upgrade: number): number
	local def = Items.Defs[itemName]
	return scaled(def and def.Heal or 0, rarity, upgrade)
end

return Items
