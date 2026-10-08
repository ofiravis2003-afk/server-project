--!strict
-- The dungeon's floors: which chapter each floor belongs to, and how hard it is.

local Floors = {}

Floors.MaxFloor = 10 -- chapter I only, for the first release

Floors.Chapters = {
	{ First = 1, Last = 10, Name = "The Drowned Catacombs" },
}

function Floors.ChapterName(floor: number): string
	for _, chapter in Floors.Chapters do
		if floor >= chapter.First and floor <= chapter.Last then
			return chapter.Name
		end
	end
	return "The Depths"
end

-- Enemies get tougher every floor.
function Floors.EnemyHealthMultiplier(floor: number): number
	return 1 + 0.15 * (floor - 1)
end

function Floors.EnemyDamageMultiplier(floor: number): number
	return 1 + 0.1 * (floor - 1)
end

-- How many combat rooms stand between the entrance and the stairs.
function Floors.CombatRooms(floor: number): number
	return math.min(3 + math.floor((floor - 1) / 2), 7)
end

return Floors
