--!strict
-- The dungeon's floors: which chapter each floor belongs to, and how hard it is.

local Config = require(script.Parent.Config)

local Floors = {}

-- Chapter II (the Rotwood Caverns, floors 16-30) is being built behind Config.ChapterII; while it's off,
-- The Hollow starts right after chapter I.
local CHAPTER_II = Config.ChapterII == true

Floors.MaxFloor = if CHAPTER_II then 30 else 15 -- the last floor of the last chapter
-- Below it, The Hollow: floors without end (2026-10-25), each harder than the last, a boss every fifth floor
-- (the old ones, stronger each time), and the best loot. How deep a player gets goes on the leaderboard.
Floors.HollowFirst = Floors.MaxFloor + 1
Floors.Deepest = 500 -- (a floor no one should ever reach; the stairs there are sealed)

Floors.Chapters = {
	{ First = 1, Last = 15, Name = "The Drowned Catacombs" },
}
if CHAPTER_II then
	table.insert(Floors.Chapters, { First = 16, Last = 30, Name = "The Rotwood Caverns" })
end
table.insert(Floors.Chapters, { First = Floors.HollowFirst, Last = math.huge, Name = "The Hollow" })

function Floors.IsRotwood(floor: number): boolean
	return CHAPTER_II and floor >= 16 and floor <= 30
end

function Floors.IsHollow(floor: number): boolean
	return floor >= Floors.HollowFirst
end

-- A floor where a run may start: any reached floor of a chapter, or a Hollow checkpoint (its first floor, then every fifth: the
-- floor after a boss) the player has earned.
function Floors.IsHollowCheckpoint(floor: number): boolean
	return Floors.IsHollow(floor) and (floor - Floors.HollowFirst) % 5 == 0
end

function Floors.ChapterName(floor: number): string
	for _, chapter in Floors.Chapters do
		if floor >= chapter.First and floor <= chapter.Last then
			return chapter.Name
		end
	end
	return "The Depths"
end

-- Enemies get tougher every floor.
-- (eased 2026-10-23: floor 12 was too much even in Legendary armor)
function Floors.EnemyHealthMultiplier(floor: number): number
	return 1 + 0.2 * (floor - 1)
end

function Floors.EnemyDamageMultiplier(floor: number): number
	return 1 + 0.08 * (floor - 1)
end

-- Which monsters a floor's combat rooms are filled with, and how often (weights).
-- Floor 1: skeletons. From 2: packs of giant rats. From 4: archers. From 6: slimes (they split in two).
function Floors.EnemyMix(floor: number): { { Name: string, Weight: number } }
	if Config.TestEnemyMix then
		return Config.TestEnemyMix
	end
	if Floors.IsRotwood(floor) then
		-- the ember has taken them: mostly the infected, a few of the old dead still among them
		return {
			{ Name = "FungalHusk", Weight = 5 },
			{ Name = "HuskArcher", Weight = 3 },
			{ Name = "SporeRat", Weight = 2 },
			{ Name = "Bloater", Weight = 2 },
			{ Name = "SporeWisp", Weight = 2 },
			{ Name = "Mycelid", Weight = if floor >= 17 then 2 else 0 },
			{ Name = "CapSpitter", Weight = if floor >= 18 then 2 else 0 },
			{ Name = "RotCrawler", Weight = if floor >= 20 then 2 else 0 },
			{ Name = "Skeleton", Weight = 1 },
		}
	end
	if floor >= 6 then
		return {
			{ Name = "Skeleton", Weight = 4 },
			{ Name = "SkeletonArcher", Weight = 3 },
			{ Name = "Rat", Weight = 2 },
			{ Name = "Slime", Weight = 2 },
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

-- Boss floors: the last room before the stairs is this boss's lair. In The Hollow, every fifth floor brings an
-- old boss back (the Bone Warden on 20, 30, ...; the Gravekeeper on 25, 35, ...), stronger each time.
-- (Looping over the table gives chapter I's two; looking up a Hollow floor works too.)
local BOSS_HOME = { Gravekeeper = 5, BoneWarden = 15 }
local THEMES = { Gravekeeper = "Graveyard", BoneWarden = "ThroneRoom" }
local function hollowBoss(floor: number): string?
	if type(floor) ~= "number" or not Floors.IsHollow(floor) or floor % 5 ~= 0 then
		return nil
	end
	return if floor % 10 == 0 then "BoneWarden" else "Gravekeeper"
end
Floors.Bosses = setmetatable({ [5] = "Gravekeeper", [15] = "BoneWarden" }, {
	__index = function(_, floor)
		return hollowBoss(floor)
	end,
}) :: any

-- How each boss's lair is dressed (RoomDecor themes).
Floors.BossThemes = setmetatable({ [5] = "Graveyard", [15] = "ThroneRoom" }, {
	__index = function(_, floor)
		local boss = hollowBoss(floor)
		return boss and THEMES[boss]
	end,
}) :: any

-- How much stronger a boss is on this floor than on its own (1 in chapter I): it keeps up with the floor.
function Floors.BossScale(floor: number, boss: string): (number, number)
	local home = BOSS_HOME[boss] or floor
	if floor <= home then
		return 1, 1
	end
	return Floors.EnemyHealthMultiplier(floor) / Floors.EnemyHealthMultiplier(home),
		Floors.EnemyDamageMultiplier(floor) / Floors.EnemyDamageMultiplier(home)
end

-- Guardians' floors: the last room before the stairs is a locked hall where three waves of the floor's
-- monsters come, the last led by a giant Skeleton Captain. Its reward is a boss's (no new model needed).
Floors.Guardians = { [10] = true } :: { [number]: boolean }
if CHAPTER_II then
	Floors.Guardians[25] = true -- the infected hall, led by Captain Mira Fell of the Ninth Patrol
end

-- How many combat rooms stand between the entrance and the stairs.
function Floors.CombatRooms(floor: number): number
	return math.min(4 + math.floor((floor - 1) / 2), 8)
end

return Floors
