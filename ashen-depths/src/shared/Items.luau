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
}

local Items = {}

Items.Defs = {
	RustySword = { DisplayName = "Rusty Sword", Slot = "Weapon", WeaponType = "Sword", Damage = 12, Look = "Sword" },
	WoodcutterAxe = { DisplayName = "Woodcutter's Axe", Slot = "Weapon", WeaponType = "Axe", Damage = 26, Look = "Axe" },
	HuntingBow = { DisplayName = "Hunting Bow", Slot = "Weapon", WeaponType = "Bow", Damage = 11, Look = "Bow" },
	ApprenticeStaff = { DisplayName = "Apprentice Staff", Slot = "Weapon", WeaponType = "Staff", Damage = 15, Look = "Staff" },
	TwinDaggers = { DisplayName = "Twin Daggers", Slot = "Weapon", WeaponType = "Daggers", Damage = 6, Look = "Daggers" },
	AcolyteTome = { DisplayName = "Acolyte's Tome", Slot = "Weapon", WeaponType = "Tome", Damage = 7, Heal = 13, Look = "Tome" },
} :: { [string]: ItemDef }

-- One starter weapon of each type, in hotbar order.
Items.StarterWeapons = { "RustySword", "WoodcutterAxe", "HuntingBow", "ApprenticeStaff", "TwinDaggers", "AcolyteTome" }

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
