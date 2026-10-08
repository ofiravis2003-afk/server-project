--!strict
-- How each weapon type fights. The item (Items.luau) sets the damage; the type sets the style.
--
--   Cooldown:   seconds between attacks
--   Range:      reach in studs (melee) or max distance (ranged)
--   Arc:        melee only, the width of the swing in degrees in front of the player
--   Width:      spear and bow, how wide the line of the thrust / arrow is
--   Pierce:     hits every enemy on the line instead of only the first
--   Radius:     staff only, the size of the blast where the fireball lands
--   Combo:      every Nth hit in a row does `ComboBonus` times the damage
--   Poison:     daggers only, extra damage over time after a hit
--   Anim:       the swing the character plays ("Slash", "Lunge" or none)

export type WeaponType = {
	Cooldown: number,
	Range: number,
	Kind: "Melee" | "Line" | "Arrow" | "Blast",
	Arc: number?,
	Width: number?,
	Pierce: boolean?,
	Radius: number?,
	ProjectileSpeed: number?,
	CritChance: number,
	CritMultiplier: number,
	Combo: number?,
	ComboBonus: number?,
	Poison: { Ticks: number, Interval: number, Fraction: number }?,
	Anim: string?,
}

local Weapons: { [string]: WeaponType } = {
	Sword = {
		Kind = "Melee",
		Cooldown = 0.45,
		Range = 7,
		Arc = 110,
		CritChance = 0.1,
		CritMultiplier = 1.75,
		Combo = 3,
		ComboBonus = 1.6,
		Anim = "Slash",
	},
	Axe = {
		Kind = "Melee",
		Cooldown = 1.05,
		Range = 7.5,
		Arc = 150,
		CritChance = 0.08,
		CritMultiplier = 2,
		Anim = "Slash",
	},
	Bow = {
		Kind = "Arrow",
		Cooldown = 0.7,
		Range = 70,
		Width = 2.5,
		ProjectileSpeed = 140,
		CritChance = 0.25,
		CritMultiplier = 2.2,
	},
	Staff = {
		Kind = "Blast",
		Cooldown = 1.1,
		Range = 45,
		Radius = 8,
		ProjectileSpeed = 70,
		CritChance = 0.05,
		CritMultiplier = 1.75,
		Anim = "Lunge",
	},
	Daggers = {
		Kind = "Melee",
		Cooldown = 0.28,
		Range = 5.5,
		Arc = 100,
		CritChance = 0.15,
		CritMultiplier = 1.75,
		Poison = { Ticks = 3, Interval = 1, Fraction = 0.3 },
		Anim = "Slash",
	},
	Spear = {
		Kind = "Line",
		Cooldown = 0.75,
		Range = 12,
		Width = 3,
		Pierce = true,
		CritChance = 0.1,
		CritMultiplier = 1.75,
		Anim = "Lunge",
	},
}

return Weapons
