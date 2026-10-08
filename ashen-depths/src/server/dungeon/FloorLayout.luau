--!strict
-- Decides the shape of a floor: which grid cells hold which rooms, and which rooms connect.
--
-- The main path winds randomly from the Entrance through the combat rooms to the Stairs.
-- Side branches hang off combat rooms: always a Treasure room, and often a Secret room
-- hidden behind a wall that a lever opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Floors = require(ReplicatedStorage.Shared.Floors)

export type RoomType = "Entrance" | "Combat" | "Treasure" | "Secret" | "Stairs"

export type RoomPlan = {
	Key: string,
	X: number,
	Z: number,
	Type: RoomType,
	Size: number,
	HasBranch: boolean,
}

export type Link = { A: string, B: string, Secret: boolean }

export type Layout = {
	Rooms: { [string]: RoomPlan },
	Links: { Link },
	Path: { string },
}

local DIRECTIONS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }
local COMBAT_SIZES = { 32, 40, 48 }
local SECRET_CHANCE = 0.6

local FloorLayout = {}

local function key(x: number, z: number): string
	return `{x},{z}`
end

local function freeNeighbors(rooms: { [string]: RoomPlan }, x: number, z: number): { Vector2 }
	local free = {}
	for _, d in DIRECTIONS do
		if not rooms[key(x + d.X, z + d.Y)] then
			table.insert(free, d)
		end
	end
	return free
end

local function tryGenerate(floor: number, rng: Random): Layout?
	local rooms: { [string]: RoomPlan } = {}
	local links: { Link } = {}
	local path: { string } = {}

	local function addRoom(x: number, z: number, roomType: RoomType, size: number): RoomPlan
		local room = { Key = key(x, z), X = x, Z = z, Type = roomType, Size = size, HasBranch = false }
		rooms[room.Key] = room
		return room
	end

	local current = addRoom(0, 0, "Entrance", 32)
	table.insert(path, current.Key)
	local combatCount = Floors.CombatRooms(floor)
	for i = 1, combatCount + 1 do
		local options = freeNeighbors(rooms, current.X, current.Z)
		if #options == 0 then
			return nil
		end
		local d = options[rng:NextInteger(1, #options)]
		local isStairs = i == combatCount + 1
		local nextRoom = addRoom(
			current.X + d.X,
			current.Z + d.Y,
			if isStairs then "Stairs" else "Combat",
			if isStairs then 32 else COMBAT_SIZES[rng:NextInteger(1, #COMBAT_SIZES)]
		)
		table.insert(links, { A = current.Key, B = nextRoom.Key, Secret = false })
		table.insert(path, nextRoom.Key)
		current = nextRoom
	end

	-- A branch room hangs off a combat room on the main path (never the entrance or the stairs).
	local function attach(roomType: RoomType, size: number, secret: boolean): boolean
		local candidates = {}
		for i = 2, #path - 1 do
			local room = rooms[path[i]]
			if not room.HasBranch then
				for _, d in freeNeighbors(rooms, room.X, room.Z) do
					table.insert(candidates, { Room = room, Dir = d })
				end
			end
		end
		if #candidates == 0 then
			return false
		end
		local pick = candidates[rng:NextInteger(1, #candidates)]
		pick.Room.HasBranch = true
		local branch = addRoom(pick.Room.X + pick.Dir.X, pick.Room.Z + pick.Dir.Y, roomType, size)
		table.insert(links, { A = pick.Room.Key, B = branch.Key, Secret = secret })
		return true
	end

	if not attach("Treasure", 28, false) then
		return nil
	end
	if rng:NextNumber() < SECRET_CHANCE then
		attach("Secret", 24, true)
	end

	return { Rooms = rooms, Links = links, Path = path }
end

function FloorLayout.Generate(floor: number, rng: Random): Layout
	for _ = 1, 100 do
		local layout = tryGenerate(floor, rng)
		if layout then
			return layout
		end
	end
	error("[FloorLayout] Could not fit a floor after 100 tries")
end

FloorLayout.Key = key

return FloorLayout
