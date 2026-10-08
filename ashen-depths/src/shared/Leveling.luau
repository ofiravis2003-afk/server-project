--!strict
-- Character level math, shared so the HUD shows the same numbers the server uses.

local Leveling = {}

Leveling.MaxLevel = 100

-- XP needed to go from `level` to `level + 1`.
function Leveling.XPToNext(level: number): number
	return math.floor(40 * level ^ 1.6)
end

function Leveling.MaxHealth(level: number): number
	return 100 + (level - 1) * 12
end

-- Every level makes the player's hits 5% stronger.
function Leveling.DamageMultiplier(level: number): number
	return 1 + (level - 1) * 0.05
end

return Leveling
