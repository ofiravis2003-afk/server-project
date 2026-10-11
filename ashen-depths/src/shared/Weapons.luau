--!strict
-- How each weapon type fights. The item (Items.luau) sets the damage; the type sets the style.
--
--   Cooldown:   seconds between attacks
--   Range:      reach in studs (melee) or max distance (ranged)
--   Arc:        melee only, the width of the swing in degrees in front of the player
--   Width:      tome only, how wide the line of the bolt is
--   Radius:     staff only, the size of the blast where the fireball lands
--   HealRange:  tome only, how far away a hurt player can be and still get healed
--   SelfHeal:   tome only, healing yourself works at this fraction (so a healer alone isn't unbeatable)
--   Combo:      every Nth hit in a row does `ComboBonus` times the damage
--   Anim:       the swing the character plays ("Slash", "Lunge" or none)

export type WeaponType = {
	Cooldown: number,
	Range: number,
	Kind: "Melee" | "Blast" | "Mend",
	Arc: number?,
	Width: number?,
	Radius: number?,
	HealRange: number?,
	SelfHeal: number?,
	ProjectileSpeed: number?,
	CritChance: number,
	CritMultiplier: number,
	Combo: number?,
	ComboBonus: number?,
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
	-- The healer: every cast throws a bolt of light at an enemy and heals the most hurt player nearby.
	Tome = {
		Kind = "Mend",
		Cooldown = 0.9,
		Range = 40,
		Width = 3,
		ProjectileSpeed = 90,
		HealRange = 35,
		SelfHeal = 0.5,
		CritChance = 0.05,
		CritMultiplier = 1.5,
	},
}

return Weapons
