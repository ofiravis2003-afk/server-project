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
	return 1 + 0.2 * (floor - 1)
end

function Floors.EnemyDamageMultiplier(floor: number): number
	return 1 + 0.1 * (floor - 1)
end

-- Which monsters a floor's combat rooms are filled with, and how often (weights).
-- Floor 1: skeletons. From 2: packs of giant rats. From 4: archers. From 6: slimes too.
function Floors.EnemyMix(floor: number): { { Name: string, Weight: number } }
	if floor >= 6 then
		return {
			{ Name = "Skeleton", Weight = 4 },
			{ Name = "SkeletonArcher", Weight = 2 },
			{ Name = "Slime", Weight = 2 },
			{ Name = "Rat", Weight = 2 },
		}
	elseif floor >= 4 then
		return { { Name = "Skeleton", Weight = 5 }, { Name = "SkeletonArcher", Weight = 3 }, { Name = "Rat", Weight = 2 } }
	elseif floor >= 2 then
		return { { Name = "Skeleton", Weight = 7 }, { Name = "Rat", Weight = 3 } }
	end
	return { { Name = "Skeleton", Weight = 1 } }
end

function Floors.PickEnemy(floor: number, rng: Random): string
	local mix = Floors.EnemyMix(floor)
	local total = 0
	for _, entry in mix do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in mix do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Name
		end
	end
	return mix[1].Name
end

-- How many combat rooms stand between the entrance and the stairs.
function Floors.CombatRooms(floor: number): number
	return math.min(3 + math.floor((floor - 1) / 2), 7)
end

return Floors
