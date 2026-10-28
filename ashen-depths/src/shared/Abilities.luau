--!strict
-- Each weapon type's special move, on its own key (Q, or the round button on a phone) with its own cooldown.
-- It's learned at level 3 and grows stronger at levels 10 and 20 (ranks II and III): more damage, a shorter wait.
--
--   Kind:    "Spin"   every enemy within Radius of the player (the sword's Whirlwind)
--            "Cleave" every enemy within Radius in a wide arc in front (the axe's Earthshatter)
--            "Meteor" a falling blast of Radius where the player aims, Range away at most (the staff)
--            "Mend"   heals every player within HealRange by a share of their health, and strikes the enemies
--                     within Radius of the caster (the tome's Sanctuary)
--   Ranks:   by level: Damage = times the weapon's blow, Heal = share of max health (Mend), Cooldown in seconds

export type Rank = { Level: number, Damage: number, Heal: number?, Cooldown: number }
export type Ability = {
	Name: string,
	Description: string,
	Kind: "Spin" | "Cleave" | "Meteor" | "Mend",
	Radius: number,
	Range: number?,
	Arc: number?,
	HealRange: number?,
	Delay: number?, -- seconds before it lands (the meteor's fall)
	Ranks: { Rank },
}

local Abilities: { [string]: Ability } = {
	Sword = {
		Name = "Whirlwind",
		Description = "Spin with your blade, striking every enemy around you.",
		Kind = "Spin",
		Radius = 10,
		Ranks = {
			{ Level = 3, Damage = 2.5, Cooldown = 10 },
			{ Level = 10, Damage = 3, Cooldown = 8 },
			{ Level = 20, Damage = 3.5, Cooldown = 7 },
		},
	},
	Axe = {
		Name = "Earthshatter",
		Description = "Bring the axe down so hard the floor cracks in front of you.",
		Kind = "Cleave",
		Radius = 14,
		Arc = 140,
		Ranks = {
			{ Level = 3, Damage = 3, Cooldown = 12 },
			{ Level = 10, Damage = 3.6, Cooldown = 10 },
			{ Level = 20, Damage = 4.2, Cooldown = 8 },
		},
	},
	Staff = {
		Name = "Meteor",
		Description = "Call a burning rock down where you aim.",
		Kind = "Meteor",
		Radius = 14,
		Range = 45,
		Delay = 0.8,
		Ranks = {
			{ Level = 3, Damage = 3, Cooldown = 12 },
			{ Level = 10, Damage = 3.6, Cooldown = 10 },
			{ Level = 20, Damage = 4.2, Cooldown = 8 },
		},
	},
	Tome = {
		Name = "Sanctuary",
		Description = "Heal every ally near you, and burn the enemies at your side.",
		Kind = "Mend",
		Radius = 12,
		HealRange = 30,
		Ranks = {
			{ Level = 3, Damage = 1.5, Heal = 0.25, Cooldown = 18 },
			{ Level = 10, Damage = 2, Heal = 0.35, Cooldown = 15 },
			{ Level = 20, Damage = 2.5, Heal = 0.45, Cooldown = 12 },
		},
	},
}

local Module = {}
Module.Defs = Abilities
Module.UnlockLevel = 3
Module.RankLevels = { 3, 10, 20 } -- (the same for every weapon)

-- The weapon type's ability at this level: its definition, the rank it's at (1-3) and that rank, or nil when
-- the weapon has none or it isn't learned yet.
function Module.At(weaponType: string, level: number): (Ability?, number, Rank?)
	local def = Abilities[weaponType]
	if not def then
		return nil, 0, nil
	end
	local rank, at = 0, nil
	for i, r in def.Ranks do
		if level >= r.Level then
			rank, at = i, r
		end
	end
	return def, rank, at
end

return Module
