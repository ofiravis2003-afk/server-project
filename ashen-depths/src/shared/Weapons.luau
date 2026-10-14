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
--   Anim:       Roblox's default swing ("Slash", "Lunge"), used only when the weapon has no Swings
--   Swings:     the character's attack clips (Mixamo moves on the R15 body, upper body only); a weapon with
--               several plays them in turn (the sword's three-blow combo)
--   Hold:       a looping stance for the upper body while the weapon is out (the legs keep walking)
--   SwingSpeed: how fast the clips play
--   SwingLength: seconds of each clip to play before easing back (cuts a follow-through that wraps into the body)
--   Release:    seconds from the click to the moment the blow lands / the spell leaves the hand: the hit
--               (or the projectile) waits for it, so it matches the swing

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
	Swings: { string }?,
	Hold: string?,
	SwingSpeed: number?,
	SwingLength: number?,
	Release: number?,
}

-- Upper-body stances while a weapon is out (Mixamo idles on the R15 body).
local MELEE_HOLD = "rbxassetid://115142381895123"
local MAGIC_HOLD = "rbxassetid://137628600957789"

local Weapons: { [string]: WeaponType } = {
	Sword = {
		Kind = "Melee",
		Cooldown = 0.6,
		Range = 7,
		Arc = 110,
		CritChance = 0.1,
		CritMultiplier = 1.75,
		Combo = 3,
		ComboBonus = 1.6,
		Anim = "Slash",
		Hold = MELEE_HOLD,
		Swings = {
			"rbxassetid://100735522519568", -- across
			"rbxassetid://116737029091929", -- backhand
			"rbxassetid://119892078524903", -- down: the combo's strong third blow
		},
		SwingSpeed = 1.0,
		SwingLength = 0.38, -- the first blow's follow-through would wrap the blade into the body
		Release = 0.3,
	},
	Axe = {
		Kind = "Melee",
		Cooldown = 0.9,
		Range = 7.5,
		Arc = 150,
		CritChance = 0.08,
		CritMultiplier = 2,
		Anim = "Slash",
		-- The overhead chop (the sword's third blow, slower here); the combo chop it had cut through the body.
		Hold = MELEE_HOLD,
		Swings = { "rbxassetid://119892078524903" },
		SwingSpeed = 0.95,
		Release = 0.4,
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
		Hold = MAGIC_HOLD,
		Swings = { "rbxassetid://80084184740105" }, -- the two-handed cast with only the staff hand moving
		SwingSpeed = 1.2,
		Release = 0.44,
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
		Hold = MAGIC_HOLD,
		Swings = { "rbxassetid://113730551682697" },
		SwingSpeed = 1.05,
		Release = 0.38,
	},
}

return Weapons
