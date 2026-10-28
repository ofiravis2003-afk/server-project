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
	Cure: boolean?, -- potions: clears Blight (chapter II's spores)
	Set: string?, -- armor: Heavy, Medium, Light, Robes or Ring (shared/Armor has its numbers)
	WeaponType: string?,
	Damage: number?,
	Heal: number?, -- tome only: health given back per cast
	Look: string?, -- which shape WeaponBuilder makes
	Aura: Color3?, -- weapons: the glow it gives off at Epic and up, instead of its rarity's color
	Chapter: number?, -- gear found only in that chapter (2: the Rotwood Caverns), upgraded with its materials
	Names: { [string]: string }?, -- the item's name at each rarity (its look changes with rarity too)
}

local Items = {}

local ROT_GLOW = Color3.fromRGB(90, 235, 150) -- the green ember

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

	-- The Rotwood Caverns' weapons (chapter II): found only there, Epic and up, glowing the green ember's color.
	MycelEdge = {
		DisplayName = "Mycel Edge",
		Slot = "Weapon",
		WeaponType = "Sword",
		Damage = 17,
		Look = "Sword",
		Aura = ROT_GLOW,
		Chapter = 2,
		Names = { Epic = "Mycel Edge", Legendary = "Rotbloom Blade", Mythic = "Thorn of the Green Ember" },
	},
	RotwoodCleaver = {
		DisplayName = "Rotwood Cleaver",
		Slot = "Weapon",
		WeaponType = "Axe",
		Damage = 25,
		Look = "Axe",
		Aura = ROT_GLOW,
		Chapter = 2,
		Names = { Epic = "Rotwood Cleaver", Legendary = "Sporefall Axe", Mythic = "The Mother's Bite" },
	},
	SporecallerStaff = {
		DisplayName = "Sporecaller Staff",
		Slot = "Weapon",
		WeaponType = "Staff",
		Damage = 17,
		Look = "Staff",
		Aura = ROT_GLOW,
		Chapter = 2,
		Names = { Epic = "Sporecaller Staff", Legendary = "Glowcap Scepter", Mythic = "Staff of the Green Ember" },
	},
	CodexOfTheDeep = {
		DisplayName = "Codex of the Deep",
		Slot = "Weapon",
		WeaponType = "Tome",
		Damage = 8,
		Heal = 15,
		Look = "Tome",
		Aura = ROT_GLOW,
		Chapter = 2,
		Names = { Epic = "Codex of the Deep", Legendary = "Mycelial Codex", Mythic = "Book of the Green Ember" },
	},

	-- Materials: every monster leaves something of itself behind.
	Bone = { DisplayName = "Bone", Slot = "Material", Stack = 99, Price = 2, Description = "Dropped by skeletons." },
	Fletching = { DisplayName = "Black Fletching", Slot = "Material", Stack = 99, Price = 3, Description = "Arrow feathers from skeleton archers." },
	RatTail = { DisplayName = "Rat Tail", Slot = "Material", Stack = 99, Price = 1, Description = "Dropped by giant rats." },
	SlimeGel = { DisplayName = "Slime Gel", Slot = "Material", Stack = 99, Price = 2, Description = "What's left of a slime." },
	SporeCap = { DisplayName = "Spore Cap", Slot = "Material", Stack = 99, Price = 4, Description = "A glowing cap off one of the infected. Handle with gloves." },
	GraveShroud = { DisplayName = "Grave Shroud", Slot = "Material", Stack = 99, Price = 60, Description = "Torn from the Gravekeeper's coat. Rare." },
	ToadHide = { DisplayName = "Toad Hide", Slot = "Material", Stack = 99, Price = 80, Description = "A slick strip of the Rotgut Toad's hide. Rare." },
	Heartwood = { DisplayName = "Heartwood", Slot = "Material", Stack = 99, Price = 150, Description = "The living core of the Mother Spore. It still beats. Very rare." },

	-- Keepsakes: quest items, carried until they're handed over.
	FoxHelmet = { DisplayName = "Dented Fox Helmet", Slot = "Material", Stack = 1, Limit = 1, Keepsake = true, Description = "A dented helmet with a fox painted on it. Old Pip's boy wore it." },

	-- Potions: drunk from the hotbar (slot 2).
	HealthPotion = { DisplayName = "Health Potion", Slot = "Potion", Stack = 5, Limit = 5, Price = 8, HealFraction = 0.4, Description = "Gives back 40% of your health." },
	-- Seraphine's brews (the Gilded Tome)
	GreaterHealthPotion = { DisplayName = "Greater Health Potion", Slot = "Potion", Stack = 3, Limit = 3, Price = 25, HealFraction = 0.75, Color = Color3.fromRGB(230, 40, 120), Description = "Gives back 75% of your health." },
	IronskinTonic = { DisplayName = "Ironskin Tonic", Slot = "Potion", Stack = 3, Limit = 3, Price = 20, Buff = { Stat = "Defense", Amount = 40, Duration = 60 }, Color = Color3.fromRGB(150, 160, 175), Description = "Defense +40 for a minute." },
	SwiftnessDraught = { DisplayName = "Swiftness Draught", Slot = "Potion", Stack = 3, Limit = 3, Price = 20, Buff = { Stat = "Speed", Amount = 0.25, Duration = 45 }, Color = Color3.fromRGB(70, 200, 220), Description = "25% faster for 45 seconds." },
	Antidote = { DisplayName = "Antidote", Slot = "Potion", Stack = 3, Limit = 3, Price = 15, Cure = true, Color = Color3.fromRGB(110, 220, 90), Description = "Burns the spores out of your blood: clears all Blight." },
	EmberElixir = { DisplayName = "Ember Elixir", Slot = "Potion", Stack = 3, Limit = 3, Price = 25, Buff = { Stat = "SpellPower", Amount = 0.3, Duration = 60 }, Color = Color3.fromRGB(255, 130, 40), Description = "Staff and tome spells 30% stronger for a minute." },
} :: { [string]: ItemDef }

-- Armor pieces and rings (shared/Armor): worn in their slot, one per bag place.
local Armor = require(script.Parent.Armor)
for _, piece in Armor.List do
	Items.Defs[piece.Name] = { DisplayName = piece.DisplayName, Slot = piece.Slot :: any, Set = piece.Set, Chapter = piece.Chapter }
end
-- What chests hand out: the gear of chapter I everywhere, and in the caverns their own as well.
Items.ArmorPieces = {} :: { string }
Items.ChapterIIRings = {} :: { string }
for _, piece in Armor.List do
	if piece.Chapter == 2 then
		table.insert(Items.ChapterIIRings, piece.Name)
	else
		table.insert(Items.ArmorPieces, piece.Name)
	end
end
Items.ChapterIIWeapons = { "MycelEdge", "RotwoodCleaver", "SporecallerStaff", "CodexOfTheDeep" }

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
